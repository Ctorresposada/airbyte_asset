# Stack: service-account
# Shared-services account stack. Centralizes the dbt Core ECR repository so a
# single image build is pulled cross-account by the dev and prod workload
# accounts. Resources live in dedicated files (ecr.tf, kms.tf).
