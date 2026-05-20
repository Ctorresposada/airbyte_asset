#!/usr/bin/env bash
# user-data.sh.tpl
# Bootstrap script for self-hosted Airbyte on Amazon Linux 2023.
# Rendered by templatefile() in main.tf; all $${...} tokens are Terraform
# template variables -- not shell variables.
#
# Steps:
#   1. Install Docker (if not pre-baked into the AMI)
#   2. Install abctl ${abctl_version} with checksum verification
#   3. Ensure SSM Agent is running
#   4. Pull Airbyte Helm values from SSM Parameter Store
#   5. Run abctl local install
#   6. Log health status
set -euxo pipefail
# Variable convention:
#   $${var}   -- Terraform template injection (single dollar in rendered output); used at assignment lines below
#   $${VAR}   -- Renders to shell variable reference in bash; used for all downstream expansions

LOG_GROUP="${log_group_name}"
REGION="${aws_region}"
ABCTL_VERSION="${abctl_version}"
SSM_PARAM="${ssm_parameter_name}"

# ---------------------------------------------------------------------------
# 1. Docker install (AL2023 -- dnf-based)
# ---------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  dnf install -y docker
  systemctl enable --now docker
fi

# Ensure the ec2-user can run docker without sudo (takes effect on next login;
# abctl runs as root via user-data, so this is for interactive debugging only).
usermod -aG docker ec2-user || true

# ---------------------------------------------------------------------------
# 2. Install abctl with checksum verification
# ---------------------------------------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)
    echo "ERROR: unsupported architecture: $ARCH"
    exit 1
    ;;
esac

ABCTL_TARBALL="abctl-$${ABCTL_VERSION}-linux-$${ARCH}.tar.gz"
CHECKSUMS_FILE="abctl_$${ABCTL_VERSION#v}_checksums.txt"
BASE_URL="https://github.com/airbytehq/abctl/releases/download/$${ABCTL_VERSION}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Strip the leading 'v' from the version for the checksums filename.
# abctl_0.30.4_checksums.txt (not abctl_v0.30.4_checksums.txt).
CHECKSUMS_FILENAME="abctl_$${ABCTL_VERSION#v}_checksums.txt"

curl -fsSL "$${BASE_URL}/$${ABCTL_TARBALL}"          -o "$${TMPDIR}/$${ABCTL_TARBALL}"
curl -fsSL "$${BASE_URL}/$${CHECKSUMS_FILENAME}"     -o "$${TMPDIR}/$${CHECKSUMS_FILENAME}"

pushd "$TMPDIR"
sha256sum --check --ignore-missing "$${CHECKSUMS_FILENAME}"
popd

tar -xzf "$${TMPDIR}/$${ABCTL_TARBALL}" -C "$TMPDIR"
install -m 0755 "$${TMPDIR}/abctl" /usr/local/bin/abctl

# ---------------------------------------------------------------------------
# 3. Ensure SSM Agent is running (pre-installed on AL2023)
# ---------------------------------------------------------------------------
systemctl enable --now amazon-ssm-agent || true

# ---------------------------------------------------------------------------
# 4. Pull the Airbyte Helm values file from SSM Parameter Store
# ---------------------------------------------------------------------------
mkdir -p /etc/airbyte

aws ssm get-parameter \
  --name "$${SSM_PARAM}" \
  --with-decryption \
  --region "$${REGION}" \
  --query Parameter.Value \
  --output text > /etc/airbyte/values.yaml

chmod 600 /etc/airbyte/values.yaml

# ---------------------------------------------------------------------------
# 5. Run abctl local install
# ---------------------------------------------------------------------------
# --low-resource-mode=false: the instance is sized (m6a.2xlarge by default)
# to handle the full control-plane footprint plus sync worker headroom.
abctl local install \
  --chart-values /etc/airbyte/values.yaml \
  --low-resource-mode=false

# ---------------------------------------------------------------------------
# 6. Log health status (non-fatal)
# ---------------------------------------------------------------------------
abctl local status || true

echo "Airbyte bootstrap complete."
