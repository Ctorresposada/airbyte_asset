#!/usr/bin/env bash
# Bootstrap: install Docker, abctl, and Airbyte on Amazon Linux 2023.
set -euxo pipefail

ABCTL_VERSION="${abctl_version}"
AWS_REGION="${aws_region}"
SSM_PARAM="${ssm_parameter_name}"
AIRBYTE_ADMIN_SECRET_ARN="${airbyte_admin_secret_arn}"

# 1. Install Docker if not already present
if ! command -v docker &>/dev/null; then
  dnf install -y docker
  systemctl enable --now docker
fi
usermod -aG docker ec2-user || true
usermod -aG docker ssm-user || true

# 2. Download and install abctl with checksum verification
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
TARBALL_NAME="abctl-$ABCTL_VERSION-linux-$ARCH"
TARBALL="$TARBALL_NAME.tar.gz"
CHECKSUMS="abctl_$(echo "$ABCTL_VERSION" | sed 's/^v//')_checksums.txt"
RELEASE_URL="https://github.com/airbytehq/abctl/releases/download/$ABCTL_VERSION"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

curl -fsSL "$RELEASE_URL/$TARBALL"   -o "$WORKDIR/$TARBALL"
curl -fsSL "$RELEASE_URL/$CHECKSUMS" -o "$WORKDIR/$CHECKSUMS"

(cd "$WORKDIR" && sha256sum --check --ignore-missing "$CHECKSUMS")
tar -xzf "$WORKDIR/$TARBALL" -C "$WORKDIR"
install -m 0755 "$WORKDIR/$TARBALL_NAME/abctl" /usr/local/bin/abctl

# 3. Install kubectl (latest stable: 1.35 from Amazon EKS S3)
KUBECTL_ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.35.3/2026-04-08/bin/linux/$KUBECTL_ARCH/kubectl
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.35.3/2026-04-08/bin/linux/$KUBECTL_ARCH/kubectl.sha256
sha256sum -c kubectl.sha256
chmod +x ./kubectl
install -m 0755 ./kubectl /usr/local/bin/kubectl
rm -f ./kubectl ./kubectl.sha256

# 4. Install postgresql15 client (psql only, for RDS connectivity debugging)
dnf install -y postgresql15 jq

# 5. Ensure SSM Agent is running (pre-installed on AL2023)
systemctl enable --now amazon-ssm-agent || true

# 6. Pull Airbyte Helm values from SSM Parameter Store
mkdir -p /etc/airbyte
aws ssm get-parameter \
  --name "$SSM_PARAM" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query Parameter.Value \
  --output text > /etc/airbyte/values.yaml
chmod 600 /etc/airbyte/values.yaml

# 7. Create db-airbyte on RDS if it does not exist
# Airbyte bootloader requires this name; RDS was provisioned with "airbyte"
# because the AWS API rejects hyphens in the initial database name.
# Password is fetched at runtime from Secrets Manager so it is never baked
# into the launch template user-data.
set +x
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id "${rds_secret_arn}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text | jq -r '.password')
set -x

DB_EXISTS=$(PGPASSWORD="$DB_PASS" psql \
  -h "${db_host}" -p ${db_port} -U "${db_user}" -d "${db_name}" \
  -tAc "SELECT 1 FROM pg_database WHERE datname='db-airbyte';")
if [[ "$DB_EXISTS" != "1" ]]; then
  PGPASSWORD="$DB_PASS" psql \
    -h "${db_host}" -p ${db_port} -U "${db_user}" -d "${db_name}" \
    -c 'CREATE DATABASE "db-airbyte";'
fi

# 8. Install Airbyte
abctl local install --values /etc/airbyte/values.yaml

# 9. Confirm Airbyte is running
abctl local status || true

# 10. Push the generated Airbyte web UI admin credentials to Secrets Manager.
# abctl stores the generated admin username/password in the Kubernetes secret
# airbyte-auth-secrets (namespace airbyte-abctl), base64-encoded. Extract them
# using the abctl-managed kubeconfig and push them to Secrets Manager so the
# credentials are retrievable without shelling into the instance. kubectl calls
# are guarded with || true because abctl may take a moment to finish reconciling
# the secret after install returns.
export KUBECONFIG=/.airbyte/abctl/abctl.kubeconfig
set +x
ADMIN_PASSWORD=$(kubectl get secret airbyte-auth-secrets -n airbyte-abctl -o jsonpath='{.data.instance-admin-password}' | base64 -d || true)
if [[ -n "$ADMIN_PASSWORD" ]]; then
  aws secretsmanager put-secret-value \
    --secret-id "$AIRBYTE_ADMIN_SECRET_ARN" \
    --region "$AWS_REGION" \
    --secret-string "$(jq -n  --arg p "$ADMIN_PASSWORD" '{password:$p}')" || true
fi
set -x

echo "Airbyte bootstrap complete."
