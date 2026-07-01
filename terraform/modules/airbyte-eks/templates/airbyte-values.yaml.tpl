# airbyte-values.yaml.tpl (EKS variant)
# Helm values for the Airbyte chart installed directly on EKS via helm_release.
# All $${...} tokens are Terraform templatefile() variables injected at plan time.
#
# Key differences from the EC2 (abctl) variant:
#   - authenticationType: irsa  — pods use IRSA service account instead of instance profile
#   - Ingress block with ALB annotations — ALB controller provisions the load balancer
#   - No ARM64 image digest pins — node group uses x86_64 (m6a family)
#   - No SSM delivery — values are passed directly by the helm_release resource
#   - No abctl-specific cookieSameSiteSetting workaround needed

global:
  airbyteUrl: "${airbyte_url}"

  auth:
    enabled: true

  database:
    # External RDS PostgreSQL for Airbyte configuration storage.
    type: "external"
    host: "${db_host}"
    port: ${db_port}
    database: "${db_name}"
    user: "${db_user}"
    password: "${db_password}"

  storage:
    type: S3
    storageSecretName: ""
    bucket:
      log: "${s3_bucket_name}"
      state: "${s3_bucket_name}"
      workloadOutput: "${s3_bucket_name}"
    s3:
      region: "${s3_region}"
      # IRSA: pods authenticate to S3 via the annotated service account,
      # not an instance profile. The serviceAccount annotation below wires
      # the IRSA role to the airbyte-sa service account.
      authenticationType: irsa

# Service account annotated with the IRSA role ARN.
# Airbyte pods inherit AWS credentials from this service account.
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${irsa_role_arn}"

# Ingress: ALB controller reads these annotations and provisions an
# internet-facing ALB with HTTPS termination and HTTP -> HTTPS redirect.
ingress:
  enabled: true
  className: alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: "${certificate_arn}"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    alb.ingress.kubernetes.io/group.name: "${name}"
    alb.ingress.kubernetes.io/inbound-cidrs: "${allowed_cidr_blocks}"
    # ExternalDNS reads this annotation to create the Route53 A record.
    external-dns.alpha.kubernetes.io/hostname: "${domain_name}"
  rules:
    - host: "${domain_name}"
      paths:
        - path: /
          pathType: Prefix
          service:
            name: "airbyte-airbyte-webapp-svc"
            port: 80

temporal:
  database:
    host: "${temporal_db_host}"
    port: ${temporal_db_port}
    database: "${temporal_db_name}"
    user: "${temporal_db_user}"
    password: "${temporal_db_password}"

# Disable internal MinIO; all blob storage goes through S3.
minio:
  enabled: false

# Disable internal PostgreSQL; using external RDS.
postgresql:
  enabled: false

server:
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

worker:
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

workloadLauncher:
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

workloadApiServer:
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

manifestServer:
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

cron:
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"
