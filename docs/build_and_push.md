# GitHub Actions ECR Workflow Setup Guide

This guide explains how to configure the `build_and_push.yml` reusable workflow for building and pushing Docker images to AWS ECR.

## Overview

The `build_and_push.yml` workflow is a **reusable workflow** called by orchestrator workflows during pull request events. It builds Docker images, runs security scans, and pushes to ECR to dynamically provide image tags to downstream Terraform deployments.

**Important:** This workflow only runs during pull request events to ensure the correct image tag is available for Terraform planning and deployment.

## Features

- ✅ **OIDC Authentication** - Secure, credential-less AWS authentication
- ✅ **Docker Buildx** - Multi-platform image builds (amd64, arm64)
- ✅ **Trivy Scanning** - Automated CVE vulnerability detection
- ✅ **Automated Testing** - Linting, unit tests, and security checks
- ✅ **Smart Tagging** - SHA-based tags for PR tracking
- ✅ **PR Push to ECR** - Builds and pushes on PR events for Terraform integration

## Prerequisites

### 1. AWS OIDC Setup

Configure AWS to trust GitHub Actions OIDC provider and IAM role with ECR permissions and trust relationship for GitHub using this [terraform module](../../terraform/modules/terraform-aws-oidc-provider/)

### 2. Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name my-app-repository \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true
```

## GitHub Configuration

### Required Repository Variables

Configure these in your GitHub repository: **Settings → Secrets and variables → Actions → Variables**

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_REGION` | AWS region for ECR | `us-east-1` |
| `AWS_ROLE_ARN` | IAM role ARN for OIDC | `arn:aws:iam::123456789012:role/github-actions-ecr-role` |
| `ECR_REPOSITORY` | ECR repository name | `my-app-repository` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOCKERFILE_PATH` | Path to Dockerfile | `./Dockerfile` |
| `DOCKER_CONTEXT` | Docker build context | `.` |
| `DOCKER_PLATFORMS` | Target platforms | `linux/amd64,linux/arm64` |
| `TRIVY_SEVERITY` | Trivy severity levels | `CRITICAL,HIGH` |
| `TRIVY_EXIT_CODE` | Exit code on vulnerabilities | `1` |
| `PYTHON_VERSION` | Python version for tests | `3.11` |

### Required Permissions

Ensure the following workflow permissions are enabled in **Settings → Actions → General → Workflow permissions**:
- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

## Workflow Behavior

This workflow is designed as a **reusable workflow** (`workflow_call`) and is invoked by orchestrator workflows during pull request events.

### On Pull Request (Non-Draft)
1. **Runs all tests** (linting, unit tests, security)
   - Python dependency installation with `uv`
   - Linting with `ruff check`
   - Unit tests (when configured)
   - Security scanning with `trufflehog`

2. **Builds Docker image** (multi-platform)
   - Builds for linux/amd64 locally for scanning
   - Generates SHA-based tags for tracking

3. **Scans image with Trivy**
   - Fails on CRITICAL vulnerabilities by default
   - Results posted to PR

4. **Pushes to ECR** (multi-platform)
   - Builds for linux/amd64,linux/arm64
   - Pushes all generated tags to ECR
   - Returns image version to calling workflow

5. **Generates build summary**
   - Posts comment on PR with build results
   - Includes image tags and digest

### Important Notes

- **PR-Only Execution:** The `build-and-push` job only runs when `github.event_name == 'pull_request'` and the PR is not a draft
- **Downstream Integration:** Image tags are passed to Terraform workflows via outputs for dynamic variable injection
- **No Manual Trigger:** This is a reusable workflow and cannot be triggered manually

## Image Tagging Strategy

The workflow automatically generates SHA-based tags during pull request builds:

- **Short SHA format:** `sha-abc1234` (7 characters)
- **Long SHA format:** Full commit SHA without prefix
- **Semantic versioning:** `v1.2.3` (if tags exist)
- **Major.minor:** `1.2` (from semantic version tags)

### Tag Generation Example

For commit `abc1234567890def...` in a pull request:
```
<ecr-registry>/<repository>:sha-abc1234
<ecr-registry>/<repository>:abc1234567890def...
```

### Usage in Terraform

The `image-version` output (typically the short SHA) is passed to Terraform workflows:
```yaml
terraform_vars: '-var ai_ordering_lambda_image_version=${{ needs.build-and-push.outputs.image-version }}'
```

## Customizing Tests

Edit the `test` job in the workflow to add your specific testing commands:

```yaml
- name: Run linting
  run: |
    pip install ruff
    ruff check .

- name: Run unit tests
  run: |
    pip install pytest pytest-cov
    pytest --cov=. --cov-report=xml

- name: Run security checks
  run: |
    pip install safety bandit
    safety check
    bandit -r . -f json
```

## Trivy Vulnerability Scanning

The workflow includes two Trivy scans:

1. **SARIF Upload** - Results uploaded to GitHub Security tab
2. **Fail on Issues** - Blocks deployment if vulnerabilities found

To adjust severity levels, set the `TRIVY_SEVERITY` variable to any combination of:
- `CRITICAL`
- `HIGH`
- `MEDIUM`
- `LOW`
- `UNKNOWN`

To allow builds with vulnerabilities (not recommended), set `TRIVY_EXIT_CODE` to `0`.

## Troubleshooting

### "Error: Unable to get OIDC token"
- Verify `id-token: write` permission is set
- Check AWS OIDC provider is configured
- Verify trust policy matches your repository

### "Error: User is not authorized to perform: ecr:GetAuthorizationToken"
- Verify IAM role has ECR permissions
- Check role ARN is correct in GitHub variables
- Ensure trust policy includes your repository

### "Error: 403 Forbidden" during push
- Verify ECR repository exists
- Check IAM role has `PutImage` permissions
- Ensure repository name matches variable

### Build fails on Trivy scan
- Review vulnerability report in GitHub Security tab
- Update base image to patched version
- Adjust `TRIVY_SEVERITY` if needed (not recommended)
