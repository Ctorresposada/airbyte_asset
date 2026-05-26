# Bastion Host Runbook

**dbt docs:** https://docs.getdbt.com/docs/platform/connect-data-platform/connect-redshift#connecting-using-an-ssh-tunnel

## Architecture

```
dbt Cloud (SaaS) ──SSH tunnel──> Bastion EC2 (public subnet) ──TCP 5439──> Redshift Serverless (private subnet)
```

- Bastion lives in a **public subnet** with an Elastic IP.
- Inbound TCP 22 is restricted to dbt Cloud's six published egress IPs only.
- The instance has **no EC2 key pair** — admin access is via SSM Session Manager exclusively.
- dbt Cloud manages its own SSH key pair and provides the public key during connection setup.


## Initial Setup: Register the dbt Cloud Public Key

After the stack is applied for the first time, complete the dbt Cloud connection setup:

### 1. In dbt Cloud

1. Go to **Account Settings > Projects > [your project] > Connection**.
2. Select **Redshift** and choose **SSH Tunnel**.
3. Fill in the bastion host details:
   - **Hostname:** the EIP from `terraform output bastion_eip`
   - **Port:** `22`
   - **Username:** `ec2-user`
4. dbt Cloud will display a **public key** — copy it (format: `ssh-rsa AAAA...`).

### 2. Connect to the bastion via SSM

```bash
aws ssm start-session \
  --target <instance-id> \
  --region us-east-1 \
  --profile <dev-profile>
```

Get the instance ID with:

```bash
terraform output bastion_instance_id
# or
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=region-20-dev-bastion" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --region us-east-1 \
  --profile <dev-profile>
```

### 3. Add the dbt Cloud public key

Once inside the SSM session:

```bash
# Switch to ec2-user home
sudo -u ec2-user bash

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Append the dbt Cloud public key
echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 4. Test the connection

Back in dbt Cloud, click **Test Connection**. It should succeed if:
- The public key was added correctly.
- The dbt Cloud IP is in the bastion security group (managed by Terraform).
- The Redshift workgroup is running and the bastion SG is allowed on port 5439.

## Rotating the dbt Cloud SSH Key

If dbt Cloud regenerates its key pair (e.g., after a credential rotation):

1. In dbt Cloud, regenerate the SSH key and copy the new public key.
2. Connect to the bastion via SSM (see above).
3. Replace the old key in `~/.ssh/authorized_keys`:

```bash
sudo -u ec2-user bash
# Overwrite with the new key only (removes the old one)
echo "ssh-rsa AAAA...<new-key>" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

4. Re-run **Test Connection** in dbt Cloud.

## Replacing a Compromised Bastion

If the instance is compromised, terminate it and let Terraform recreate it:

```bash
# Taint the instance so the next apply replaces it
terraform taint 'aws_instance.bastion[0]'
terraform taint 'aws_eip_association.bastion[0]'
# The EIP is preserved — Terraform will re-associate it to the new instance
terraform apply -var-file=variables/dev.tfvars
```

After the new instance is up, re-run the **Initial Setup** steps above to re-add the dbt Cloud public key.

## Verifying SSH Access is Locked Down

Confirm the bastion SG only allows the six dbt Cloud IPs:

```bash
aws ec2 describe-security-groups \
  --group-ids "$(terraform output -raw bastion_security_group_id)" \
  --query "SecurityGroups[0].IpPermissions" \
  --region us-east-1 \
  --profile <dev-profile>
```

Each entry should show `/32` CIDR rules for exactly these IPs:

```
52.45.144.63, 54.81.134.249, 52.22.161.231, 52.3.77.232, 3.214.191.130, 34.233.79.135
```

If dbt Labs publishes updated egress IPs, update `local.dbt_cloud_ips` in `terraform/warehouse/security.tf` and apply.

## Verifying CloudWatch Log Delivery

SSH login events are streamed from `/var/log/secure` to the log group `/aws/ec2/region-20-<env>-bastion/auth`.

```bash
aws logs filter-log-events \
  --log-group-name "/aws/ec2/region-20-dev-bastion/auth" \
  --filter-pattern "sshd" \
  --region us-east-1 \
  --profile <dev-profile>
```

A successful dbt Cloud connection attempt will appear as an `Accepted publickey` entry within ~60 seconds.
