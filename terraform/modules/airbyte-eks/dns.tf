# Module: airbyte-eks — ACM certificate and DNS validation
#
# ACM certificate and Route53 validation record are Terraform-managed.
# The Airbyte A record is NOT managed here — ExternalDNS (see eks.tf)
# creates and manages it automatically from the Ingress annotation.

resource "aws_acm_certificate" "this" {
  count = local.create_dns && var.alb_certificate_arn == "" ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  count = local.create_dns && var.alb_certificate_arn == "" ? 1 : 0

  allow_overwrite = true
  name            = tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_value]
  ttl             = 60
  type            = tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "this" {
  count = local.create_dns && var.alb_certificate_arn == "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation[0].fqdn]
}
