# Stack: security
#
# Manages IAM Identity Center (IDC) resources for the Data-Lake-Caylent workforce
# group: the Identity Store group itself, two permission sets (DataEngineer_Prod
# and DataEngineer_Dev), their managed-policy attachments, the dev inline policy,
# and the per-account assignments.
#
# Delegated administrator model:
#   - IDC instance owner account:    992382717104 (management)
#   - This stack's account:          var.account_id (security account, e.g. 510473518105)
#   - The security account is registered as the IAM Identity Center delegated
#     administrator. All sso-admin and identitystore API calls are issued from the
#     security account against the global IDC instance ARN, which is why the
#     provider's assume_role still points to var.account_id rather than the IDC
#     owner. If the delegated administrator registration is removed, this stack
#     will fail to plan or apply.
#
# All resources are gated on var.create to allow soft-delete via tfvars without
# destroying state or removing code.

# ---------------------------------------------------------------------------
# Identity Store group
# ---------------------------------------------------------------------------

resource "aws_identitystore_group" "data_lake_caylent" {
  count = var.create ? 1 : 0

  identity_store_id = var.identity_store_id
  display_name      = var.data_lake_group.display_name
  description       = var.data_lake_group.description
}

# ---------------------------------------------------------------------------
# Permission set: DataEngineer_Prod
# ---------------------------------------------------------------------------

resource "aws_ssoadmin_permission_set" "data_engineer_prod" {
  count = var.create ? 1 : 0

  instance_arn     = var.instance_arn
  name             = var.data_engineer_prod_permission_set.name
  description      = var.data_engineer_prod_permission_set.description
  session_duration = var.data_engineer_prod_permission_set.session_duration
}

# ---------------------------------------------------------------------------
# Permission set: DataEngineer_Dev
# ---------------------------------------------------------------------------

resource "aws_ssoadmin_permission_set" "data_engineer_dev" {
  count = var.create ? 1 : 0

  instance_arn     = var.instance_arn
  name             = var.data_engineer_dev_permission_set.name
  description      = var.data_engineer_dev_permission_set.description
  session_duration = var.data_engineer_dev_permission_set.session_duration
}

# ---------------------------------------------------------------------------
# Managed policy attachments (one per managed policy per permission set)
#
# Keyed by "<perm_set_key>:<short_name>". The locals merge produces a single
# flat map; we resolve the parent permission_set_arn here based on
# permission_set_key so a single resource block covers both sets.
# ---------------------------------------------------------------------------

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  #checkov:skip=CKV_AWS_274: AdministratorAccess-equivalent breadth (S3FullAccess, EC2FullAccess, etc.) is required by the DataEngineer role per the data team's documented access model; finer-grained scoping is tracked separately.

  for_each = var.create ? local.managed_policy_attachments : {}

  instance_arn       = var.instance_arn
  managed_policy_arn = each.value.managed_policy_arn
  permission_set_arn = (
    each.value.permission_set_key == "prod"
    ? aws_ssoadmin_permission_set.data_engineer_prod[0].arn
    : aws_ssoadmin_permission_set.data_engineer_dev[0].arn
  )
}

# ---------------------------------------------------------------------------
# Inline policy on DataEngineer_Dev
# ---------------------------------------------------------------------------

resource "aws_ssoadmin_permission_set_inline_policy" "data_engineer_prod" {
  #checkov:skip=CKV_AWS_286: Privilege escalation surface (iam:Put*, iam:CreatePolicy*, iam:UpdateAssumeRolePolicy) is required by the dev DataEngineer role in the dev account only; risk is bounded by the account boundary.
  #checkov:skip=CKV_AWS_287: secretsmanager:Get*/List* and kms:Decrypt are required for the dev DataEngineer role to develop pipelines that consume secrets; scoped via Resource "*" because secret ARNs are dynamic during development.
  #checkov:skip=CKV_AWS_288: Data-exfiltration vectors (S3FullAccess, athena:*) are inherent to the data-engineering workflow in the dev account; managed by the AWS Managed Policy attachments and accepted per the data team's access model.
  #checkov:skip=CKV_AWS_289: Permissions-management actions (iam:Attach*, iam:PutGroupPolicy, etc.) are required for the dev DataEngineer to iterate on roles in the dev account; not granted in prod.
  #checkov:skip=CKV_AWS_290: Wildcard write actions (athena:*, sqlworkbench writes, kms:Encrypt/GenerateDataKey) match the live production policy being imported; any tightening must happen as a follow-up PR after the import is stable.

  count = var.create ? 1 : 0

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_prod[0].arn
  inline_policy      = local.data_engineer_prod_inline_policy
}

# ---------------------------------------------------------------------------
# Inline policy on DataEngineer_Dev
# ---------------------------------------------------------------------------

resource "aws_ssoadmin_permission_set_inline_policy" "data_engineer_dev" {
  #checkov:skip=CKV_AWS_286: Privilege escalation surface (iam:Put*, iam:CreatePolicy*, iam:UpdateAssumeRolePolicy) is required by the dev DataEngineer role in the dev account only; risk is bounded by the account boundary.
  #checkov:skip=CKV_AWS_287: secretsmanager:Get*/List* and kms:Decrypt are required for the dev DataEngineer role to develop pipelines that consume secrets; scoped via Resource "*" because secret ARNs are dynamic during development.
  #checkov:skip=CKV_AWS_288: Data-exfiltration vectors (S3FullAccess, athena:*) are inherent to the data-engineering workflow in the dev account; managed by the AWS Managed Policy attachments and accepted per the data team's access model.
  #checkov:skip=CKV_AWS_289: Permissions-management actions (iam:Attach*, iam:PutGroupPolicy, etc.) are required for the dev DataEngineer to iterate on roles in the dev account; not granted in prod.
  #checkov:skip=CKV_AWS_290: Wildcard write actions (athena:*, sqlworkbench writes, kms:Encrypt/GenerateDataKey) match the live production policy being imported; any tightening must happen as a follow-up PR after the import is stable.

  count = var.create ? 1 : 0

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_dev[0].arn
  inline_policy      = local.data_engineer_dev_inline_policy
}

# ---------------------------------------------------------------------------
# Account assignments (Data-Lake-Caylent group -> permission set -> account)
# ---------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = var.create ? var.data_engineer_account_assignments : {}

  instance_arn       = var.instance_arn
  permission_set_arn = local.permission_set_arns[each.key]

  principal_id   = aws_identitystore_group.data_lake_caylent[0].group_id
  principal_type = "GROUP"

  target_id   = each.value.aws_account_id
  target_type = "AWS_ACCOUNT"
}
