"""
Google Drive → S3 Landing Zone Sync
Exports Google Sheets as CSV and copies PDFs to S3.
Incremental: uses SSM Parameter Store to track last sync time.

Works as both a local script and AWS Lambda handler.

Local usage:
    python gdrive_to_s3.py --key tea.json --bucket escr20-landing-zone-raw-dev --prefix tea/ [--full-refresh]

Lambda env vars:
    SECRET_NAME     : Secrets Manager secret name containing tea.json contents
    S3_BUCKET       : escr20-landing-zone-raw-dev
    S3_PREFIX       : tea/
    SSM_CURSOR_PATH : /r20/gdrive-sync/last-sync-time
    DRIVE_FOLDER_ID : 0AC5xbBuRiUvXUk9PVA
"""

import argparse
import io
import json
import os
import sys
from datetime import datetime, timezone

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
                key  = s3_key(s3_prefix, drive_path, name, ".pdf")
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
        full_refresh=False):

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

    # Update cursor only on success
    if stats["failed"] == 0:
        if ssm_path:
            set_last_sync_time(ssm_path, sync_start)
            print(f"\nCursor updated → {sync_start.isoformat()}")
    else:
        print(f"\nWARNING: {stats['failed']} file(s) failed — cursor NOT updated.")

    print(f"\n{'='*60}")
    print(f"Done. exported={stats['exported']}  skipped={stats['skipped']}  "
          f"failed={stats['failed']}  total_bytes={stats['bytes']:,}")
    print(f"{'='*60}")


def lambda_handler(event, context):
    """AWS Lambda entry point."""
    run(
        secret_name    = os.environ["SECRET_NAME"],
        bucket         = os.environ["S3_BUCKET"],
        s3_prefix      = os.environ.get("S3_PREFIX", "tea/"),
        ssm_path       = os.environ.get("SSM_CURSOR_PATH", "/r20/gdrive-sync/last-sync-time"),
        drive_folder_id= os.environ.get("DRIVE_FOLDER_ID", "0AC5xbBuRiUvXUk9PVA"),
        full_refresh   = event.get("full_refresh", False),
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
