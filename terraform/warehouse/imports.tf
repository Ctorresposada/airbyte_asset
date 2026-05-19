# Temporary — remove after the first successful apply on this branch.
# Adopts the two CloudWatch log groups AWS auto-created when Redshift Serverless
# first emitted logs (before logs.tf existed). The third log group (userlog) is
# created fresh by Terraform because no user-level events have been emitted yet.

import {
  to = aws_cloudwatch_log_group.redshift["connectionlog"]
  id = "/aws/redshift/${local.name}-warehouse/connectionlog"
}

import {
  to = aws_cloudwatch_log_group.redshift["useractivitylog"]
  id = "/aws/redshift/${local.name}-warehouse/useractivitylog"
}
