"""
Google Drive → S3 Landing Zone Sync
Exports Google Sheets as CSV and copies PDFs to S3.
Incremental: uses SSM Parameter Store to track last sync time.

Works as both a local script and AWS Lambda handler.

Local usage:
    python gdrive_to_s3.py --key tea.json --bucket escr20-landing-zone-raw-dev --prefix tea/ [--full-refresh]

Lambda env vars:
    SECRET_NAME          : Secrets Manager secret name containing tea.json contents
    S3_BUCKET            : escr20-landing-zone-raw-dev
    S3_PREFIX            : tea/
    SSM_CURSOR_PATH      : /r20/gdrive-sync/last-sync-time
    DRIVE_FOLDER_ID      : 0AC5xbBuRiUvXUk9PVA
    CRAWLER_SCHEDULE_NAME: EventBridge Scheduler schedule name for the delayed crawler trigger
    CRAWLER_NAME         : Glue crawler name to start after sync
    CRAWLER_SCHEDULER_ROLE_ARN : IAM role ARN for EventBridge Scheduler to assume when calling Glue
    CRAWLER_DELAY_HOURS  : Hours to delay crawler start after sync (default 1)
"""

import argparse
import io
import json
import os
import sys
from datetime import datetime, timedelta, timezone

import boto3

try:
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaIoBaseDownload
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install",
                           "google-api-python-client", "google-auth", "-q"])
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaIoBaseDownload

SCOPES          = ["https://www.googleapis.com/auth/drive.readonly"]
FOLDER_MIME     = "application/vnd.google-apps.folder"
SHEET_MIME      = "application/vnd.google-apps.spreadsheet"
SHORTCUT_MIME   = "application/vnd.google-apps.shortcut"
PDF_MIME        = "application/pdf"

# ── Stats ──────────────────────────────────────────────────────────────────────
stats = {"exported": 0, "skipped": 0, "failed": 0, "bytes": 0}


# ── Google Drive helpers ───────────────────────────────────────────────────────

def build_drive_service(key_path=None, secret_name=None):
    if secret_name:
        sm = boto3.client("secretsmanager")
        secret = json.loads(sm.get_secret_value(SecretId=secret_name)["SecretString"])
        creds = service_account.Credentials.from_service_account_info(secret, scopes=SCOPES)
    else:
        creds = service_account.Credentials.from_service_account_file(key_path, scopes=SCOPES)
    return build("drive", "v3", credentials=creds)


def list_folder(service, folder_id):
    """Yield all non-trashed items in a folder (paginated)."""
    page_token = None
    while True:
        result = service.files().list(
            q=f"'{folder_id}' in parents and trashed = false",
            pageSize=1000,
            fields="nextPageToken, files(id, name, mimeType, modifiedTime, size)",
            includeItemsFromAllDrives=True,
            supportsAllDrives=True,
            corpora="allDrives",
            pageToken=page_token,
        ).execute()
        yield from result.get("files", [])
        page_token = result.get("nextPageToken")
        if not page_token:
            break


def export_sheet_as_csv(service, file_id):
    """Export a Google Sheet as CSV bytes (first/active sheet only)."""
    return service.files().export(
        fileId=file_id,
        mimeType="text/csv"
    ).execute()


def download_file(service, file_id):
    """Download a binary file (e.g. PDF)."""
    request = service.files().get_media(
        fileId=file_id,
        supportsAllDrives=True
    )
    buf = io.BytesIO()
    downloader = MediaIoBaseDownload(buf, request)
    done = False
    while not done:
        _, done = downloader.next_chunk()
    return buf.getvalue()


# ── S3 helpers ─────────────────────────────────────────────────────────────────

def s3_key(prefix, drive_path, filename, extension):
    """Build S3 key from drive folder path and filename."""
    clean_path = drive_path.strip("/")
    safe_name = filename.replace("/", "_")
    return f"{prefix}{clean_path}/{safe_name}{extension}".replace("//", "/")


def upload_to_s3(s3_client, bucket, key, data, content_type):
    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=data,
        ContentType=content_type,
    )


# ── Cursor (incremental) ───────────────────────────────────────────────────────

def get_last_sync_time(ssm_path):
    """Return last sync time as aware datetime, or epoch if first run."""
    try:
        ssm = boto3.client("ssm")
        val = ssm.get_parameter(Name=ssm_path)["Parameter"]["Value"]
        return datetime.fromisoformat(val)
    except Exception:
        return datetime(1970, 1, 1, tzinfo=timezone.utc)


def set_last_sync_time(ssm_path, dt):
    ssm = boto3.client("ssm")
    ssm.put_parameter(
        Name=ssm_path,
        Value=dt.isoformat(),
        Type="String",
        Overwrite=True,
    )


# ── Delayed crawler trigger ────────────────────────────────────────────────────

def schedule_crawler(schedule_name, crawler_name, role_arn, delay_hours=1):
    """
    Create a one-time EventBridge Scheduler schedule that starts the TEA Glue
    crawler after a delay.  The schedule deletes itself after firing.
    """
    scheduler = boto3.client("scheduler")
    run_at = datetime.now(timezone.utc) + timedelta(hours=delay_hours)

    try:
        scheduler.create_schedule(
            Name=schedule_name,
            ScheduleExpression=f"at({run_at.strftime('%Y-%m-%dT%H:%M:%S')})",
            ScheduleExpressionTimezone="UTC",
            FlexibleTimeWindow={"Mode": "OFF"},
            Target={
                "Arn": "arn:aws:scheduler:::aws-sdk:glue:startCrawler",
                "RoleArn": role_arn,
                "Input": json.dumps({"Name": crawler_name}),
            },
            ActionAfterCompletion="DELETE",
        )
        print(f"\nScheduled crawler '{crawler_name}' to start at {run_at.isoformat()}")
    except scheduler.exceptions.ConflictException:
        # Schedule already exists (e.g. from a previous retry) — update it.
        scheduler.update_schedule(
            Name=schedule_name,
            ScheduleExpression=f"at({run_at.strftime('%Y-%m-%dT%H:%M:%S')})",
            ScheduleExpressionTimezone="UTC",
            FlexibleTimeWindow={"Mode": "OFF"},
            Target={
                "Arn": "arn:aws:scheduler:::aws-sdk:glue:startCrawler",
                "RoleArn": role_arn,
                "Input": json.dumps({"Name": crawler_name}),
            },
            ActionAfterCompletion="DELETE",
        )
        print(f"\nUpdated existing crawler schedule to start at {run_at.isoformat()}")


# ── Core sync logic ────────────────────────────────────────────────────────────

def sync_folder(service, s3_client, bucket, s3_prefix,
                folder_id, drive_path, since, full_refresh):
    """Recursively sync a Drive folder to S3."""
    for f in list_folder(service, folder_id):
        mime = f["mimeType"]
        name = f["name"]

        # Skip shortcuts
        if mime == SHORTCUT_MIME:
            print(f"  [SKIP shortcut] {drive_path}/{name}")
            stats["skipped"] += 1
            continue

        # Recurse into subfolders
        if mime == FOLDER_MIME:
            sync_folder(service, s3_client, bucket, s3_prefix,
                        f["id"], f"{drive_path}/{name}", since, full_refresh)
            continue

        # Incremental check
        modified = datetime.fromisoformat(f["modifiedTime"].replace("Z", "+00:00"))
        if not full_refresh and modified <= since:
            print(f"  [SKIP unchanged] {drive_path}/{name}")
            stats["skipped"] += 1
            continue

        # Export Google Sheets → CSV
        if mime == SHEET_MIME:
            try:
                data = export_sheet_as_csv(service, f["id"])
                key  = s3_key(s3_prefix, drive_path, name, ".csv")
                upload_to_s3(s3_client, bucket, key, data, "text/csv")
                print(f"  [OK sheet→csv] s3://{bucket}/{key}  ({len(data):,} B)")
                stats["exported"] += 1
                stats["bytes"]    += len(data)
            except HttpError as e:
                print(f"  [FAIL] {drive_path}/{name}: {e.status_code} {e.reason}")
                stats["failed"] += 1

        # Download PDFs as-is
        elif mime == PDF_MIME:
            try:
                data = download_file(service, f["id"])
                key  = s3_key(s3_prefix, drive_path, name, "")
                upload_to_s3(s3_client, bucket, key, data, "application/pdf")
                print(f"  [OK pdf]        s3://{bucket}/{key}  ({len(data):,} B)")
                stats["exported"] += 1
                stats["bytes"]    += len(data)
            except HttpError as e:
                print(f"  [FAIL] {drive_path}/{name}: {e.status_code} {e.reason}")
                stats["failed"] += 1

        else:
            print(f"  [SKIP unsupported mime: {mime}] {name}")
            stats["skipped"] += 1


# ── Entry points ───────────────────────────────────────────────────────────────

def run(key_path=None, secret_name=None, bucket=None, s3_prefix="tea/",
        ssm_path="/r20/gdrive-sync/last-sync-time",
        drive_folder_id="0AC5xbBuRiUvXUk9PVA",
        full_refresh=False,
        crawler_schedule_name=None, crawler_name=None,
        crawler_scheduler_role_arn=None, crawler_delay_hours=1):

    print(f"{'='*60}")
    print(f"Google Drive → S3 Sync  {'(FULL REFRESH)' if full_refresh else '(INCREMENTAL)'}")
    print(f"Bucket : s3://{bucket}/{s3_prefix}")
    print(f"{'='*60}\n")

    service  = build_drive_service(key_path=key_path, secret_name=secret_name)
    s3_client = boto3.client("s3")

    since = datetime(1970, 1, 1, tzinfo=timezone.utc) if full_refresh else get_last_sync_time(ssm_path)
    print(f"Syncing files modified after: {since.isoformat()}\n")

    sync_start = datetime.now(timezone.utc)
    sync_folder(service, s3_client, bucket, s3_prefix,
                drive_folder_id, "", since, full_refresh)

    # Update cursor even on partial success so successfully synced files are
    # not re-downloaded on the next run. Failed files will have an older
    # modifiedTime and will be retried automatically.
    if ssm_path and stats["exported"] > 0:
        set_last_sync_time(ssm_path, sync_start)
        print(f"\nCursor updated → {sync_start.isoformat()}")

    if stats["failed"] > 0:
        print(f"\nWARNING: {stats['failed']} file(s) failed — will be retried on next run.")

    # Schedule the TEA Glue crawler to run after a delay so the bronze router
    # Lambda has time to convert all CSVs to Parquet before the crawler scans.
    if crawler_schedule_name and crawler_name and crawler_scheduler_role_arn:
        if stats["exported"] > 0:
            schedule_crawler(
                crawler_schedule_name, crawler_name,
                crawler_scheduler_role_arn, crawler_delay_hours,
            )
        else:
            print("\nNo files exported — skipping crawler schedule.")

    print(f"\n{'='*60}")
    print(f"Done. exported={stats['exported']}  skipped={stats['skipped']}  "
          f"failed={stats['failed']}  total_bytes={stats['bytes']:,}")
    print(f"{'='*60}")


def lambda_handler(event, context):
    """AWS Lambda entry point."""
    run(
        secret_name              = os.environ["SECRET_NAME"],
        bucket                   = os.environ["S3_BUCKET"],
        s3_prefix                = os.environ.get("S3_PREFIX", "tea/"),
        ssm_path                 = os.environ.get("SSM_CURSOR_PATH", "/r20/gdrive-sync/last-sync-time"),
        drive_folder_id          = os.environ.get("DRIVE_FOLDER_ID", "0AC5xbBuRiUvXUk9PVA"),
        full_refresh             = event.get("full_refresh", False),
        crawler_schedule_name    = os.environ.get("CRAWLER_SCHEDULE_NAME"),
        crawler_name             = os.environ.get("CRAWLER_NAME"),
        crawler_scheduler_role_arn = os.environ.get("CRAWLER_SCHEDULER_ROLE_ARN"),
        crawler_delay_hours      = int(os.environ.get("CRAWLER_DELAY_HOURS", "1")),
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--key",          required=True,  help="Path to service account JSON key")
    parser.add_argument("--bucket",       required=True,  help="S3 bucket name")
    parser.add_argument("--prefix",       default="tea/", help="S3 key prefix")
    parser.add_argument("--ssm-path",     default=None,   help="SSM path for cursor (skip if not set)")
    parser.add_argument("--folder",       default="0AC5xbBuRiUvXUk9PVA", help="Drive root folder ID")
    parser.add_argument("--full-refresh", action="store_true", help="Ignore cursor, sync everything")
    parser.add_argument("--profile",      default=None,   help="AWS CLI profile name")
    args = parser.parse_args()

    if args.profile:
        boto3.setup_default_session(profile_name=args.profile)

    run(
        key_path        = args.key,
        bucket          = args.bucket,
        s3_prefix       = args.prefix,
        ssm_path        = args.ssm_path,
        drive_folder_id = args.folder,
        full_refresh    = args.full_refresh,
    )
