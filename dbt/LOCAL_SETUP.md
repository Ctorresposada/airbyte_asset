# dbt local setup — Region 20

Guide for running the `r20_esc` project (dbt-athena) locally against the **dev** environment in account `784590287037`.

---

## 1. Prerequisites

| Tool | Version | How to install (macOS) |
|------|---------|------------------------|
| Python | 3.12+ | `brew install python@3.12` |
| uv (recommended) or pip | latest | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| AWS CLI v2 | 2.x | `brew install awscli` |
| git | any | ships with Xcode CLT |

**Required AWS access:**
- Permission set `DataEngineer_Dev` in SSO (account `784590287037`)
- Permissions already granted by Terraform (Lake Formation + S3): read on bronze/silver, write on silver

---

## 2. Clone the repository

```bash
git clone https://github.com/esc-region-20/r20-data-lake-infrastructure.git
cd r20-data-lake-infrastructure/dbt
```

Relevant structure:

```
dbt/
├── profiles.yml          # dbt profile (athena → silver / gold)
├── Dockerfile            # image for CI/ECS (not used locally)
└── r20_esc/              # dbt project
    ├── dbt_project.yml
    ├── models/
    │   ├── silver/       # incremental + iceberg
    │   └── gold/         # table + iceberg
    ├── macros/
    ├── seeds/
    ├── snapshots/
    └── tests/
```

---

## 3. Install dbt + adapters

Pinned versions are in `pyproject.toml` (repo root): `dbt-athena==1.10.1` and `dbt-redshift==1.10.1`.

### Option A — `uv` (recommended, matches CI)

```bash
cd /path/to/r20-data-lake-infrastructure
uv sync --group dbt
source .venv/bin/activate
dbt --version
```

### Option B — `pip` in a venv

```bash
python3.12 -m venv ~/.local/dbt-r20-env
source ~/.local/dbt-r20-env/bin/activate
pip install --upgrade pip
pip install dbt-athena==1.10.1 dbt-redshift==1.10.1
dbt --version
```

Expected output (patch versions may differ):

```
Core:
  - installed: 1.10.x
Plugins:
  - athena:   1.10.1
  - redshift: 1.10.1
```

---

## 4. Configure AWS SSO

```bash
aws configure sso
```

Answer:
- **SSO start URL**: `https://caylent.awsapps.com/start` *(confirm with the team if different)*
- **SSO Region**: `us-east-1`
- **Account ID**: `784590287037`
- **Role name**: `DataEngineer_Dev`
- **Default region**: `us-east-1`
- **Default output**: `json`
- **CLI profile name**: `r20-dev` (suggested)

Log in (must be repeated when it expires — every ~8h):

```bash
aws sso login --profile r20-dev
export AWS_PROFILE=r20-dev
aws sts get-caller-identity   # verify the login worked
```

> Add `export AWS_PROFILE=r20-dev` to your `~/.zshrc` so you don't need to export it every session.

---

## 5. dbt environment variables

`profiles.yml` uses `env_var(...)` for connection details. There are two targets:

- `silver` — Athena adapter (writes Iceberg tables to S3 silver bucket)
- `redshift_gold` — Redshift adapter (writes gold marts to Redshift)

### Required for the `silver` target (Athena)

```bash
export DBT_PROFILES_DIR="$(pwd)"                                 # from inside r20-data-lake-infrastructure/dbt/
export ATHENA_RESULTS_BUCKET="s3://escr20-athena-results-dev/"
export SILVER_BUCKET="s3://escr20-silver-dev/"
```

### Required for the `redshift_gold` target (Redshift)

Only needed when running `dbt run --target redshift_gold`:

```bash
export REDSHIFT_HOST="<workgroup>.<account-id>.us-east-1.redshift-serverless.amazonaws.com"
export REDSHIFT_PORT="5439"
export REDSHIFT_DB="dev"
export REDSHIFT_SCHEMA="gold"
export REDSHIFT_USER="<your-iam-user-or-role>"
export REDSHIFT_WORKGROUP_NAME="<workgroup-name>"
export AWS_REGION="us-east-1"
```

Ask the team for the exact Redshift host / workgroup / user.

Add the variables to your `~/.zshrc` (or create a `.env` you `source`) for persistence.

---

## 6. Validate the connection

```bash
cd r20_esc
dbt debug --target silver
```

Success signals:

```
Connection test: [OK connection ok]
All checks passed!
```

If it fails, see **Troubleshooting** below.

---

## 7. Basic commands

```bash
# Always run from inside r20_esc/

dbt deps                                  # install packages from packages.yml
dbt run --target silver                   # run every silver model
dbt run --select stg_oracle__cmt_period   # run a single model
dbt run --select silver                   # run the whole silver layer
dbt run --select +stg_oracle__contact     # with upstream dependencies
dbt test --target silver                  # run tests
dbt compile                               # generate SQL without executing
dbt docs generate && dbt docs serve       # generate + serve local docs
```

Switch to the gold target (Redshift):

```bash
dbt run --target redshift_gold
```

---

## 8. Where the data lands

| Target | Engine | Location | How to query |
|--------|--------|----------|--------------|
| `silver` | Athena | Glue DB `glue_reg20_silver` (data in `s3://escr20-silver-dev/`) | Athena workgroup `primary` |
| `redshift_gold` | Redshift | Schema set by `REDSHIFT_SCHEMA` in the configured DB | Redshift query editor / dbt CLI |

> **Note:** the current bronze database (`escr20_bronze_dev`) and the dev silver (`escr20_silver_dev`) may still coexist with `glue_reg20_silver` while the name migration is in progress. Confirm with the team which one is active when you run.

Athena smoke-test query (silver):

```sql
SELECT COUNT(*) AS cnt
FROM glue_reg20_silver.stg_oracle__cmt_period;
```

Redshift smoke-test query (gold) — run after `dbt run --target redshift_gold`:

```sql
SELECT COUNT(*) AS cnt
FROM gold.dim_cmt_period;   -- adjust schema/table to what the project produces
```

---

## 9. Troubleshooting

### `ExpiredTokenException` / `Unable to locate credentials`
SSO token expired — run `aws sso login --profile r20-dev` again.

### `Access denied` on Glue database/table
The `DataEngineer_Dev` SSO permission set already has `SELECT/DESCRIBE/DROP` on silver via Lake Formation (applied by Terraform). If you see **PERMISSION_DENIED on `AWSServiceRoleForLakeFormationDataAccess`** at the S3 level, the Terraform fix (PRs #117 and #119) must be applied — check with the team.

### `dbt debug` returns `Profile loading failed`
Make sure `DBT_PROFILES_DIR` points to the directory containing `profiles.yml` (do not include the filename).

### `database not found: awsdatacatalog.glue_reg20_silver`
The database hasn't been created yet. Create it in Athena:

```sql
CREATE DATABASE IF NOT EXISTS glue_reg20_silver
LOCATION 's3://escr20-silver-dev/';
```

Then request Lake Formation grants (`DESCRIBE`, `SELECT`, `CREATE_TABLE`) — flow goes through Terraform.

### `Iceberg table type requires Athena engine version 3`
Athena console → Workgroups → `primary` → **Edit** → ensure **engine version 3**.

### Stubborn dbt cache
```bash
dbt clean        # removes target/ and dbt_packages/
dbt deps
dbt debug
```

---

## 10. Useful shortcuts

`.envrc` (if you use direnv):

```bash
export AWS_PROFILE=r20-dev
export DBT_PROFILES_DIR="$PWD"
export ATHENA_RESULTS_BUCKET="s3://escr20-athena-results-dev/"
export SILVER_BUCKET="s3://escr20-silver-dev/"

# Only needed when targeting redshift_gold:
# export REDSHIFT_HOST="..."
# export REDSHIFT_PORT="5439"
# export REDSHIFT_DB="dev"
# export REDSHIFT_SCHEMA="gold"
# export REDSHIFT_USER="..."
# export REDSHIFT_WORKGROUP_NAME="..."
# export AWS_REGION="us-east-1"
```

Helper function in `~/.zshrc` to log in + activate venv:

```bash
r20-dbt() {
  aws sso login --profile r20-dev || return 1
  source ~/.local/dbt-r20-env/bin/activate
  cd /path/to/r20-data-lake-infrastructure/dbt
  export AWS_PROFILE=r20-dev DBT_PROFILES_DIR="$PWD"
  export ATHENA_RESULTS_BUCKET="s3://escr20-athena-results-dev/"
  export SILVER_BUCKET="s3://escr20-silver-dev/"
  cd r20_esc
}
```

Then just run `r20-dbt` in the terminal.

---

## Contacts

- Project owner: Cássio (`cassio.vargas@caylent.com`)
- dbt project repo: `esc-region-20/r20-data-lake-infrastructure/dbt/`
- Infra repo (Terraform/IAM/LF): `esc-region-20/r20-data-lake-infrastructure/terraform/`
