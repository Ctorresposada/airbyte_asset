# dbt-core and Airbyte OSS Self-Hosted Compute Options

> Back to [docs landing page](README.md) · See also the [Concepts Glossary](concepts-glossary.md)

> **In plain terms**
>
> The data platform uses two tools: **Airbyte** (which copies data out of source systems into our storage) and **dbt** (which cleans and reshapes that data into report-ready tables). For each tool we can either pay a vendor to run it for us (the "Cloud" / SaaS option, covered elsewhere) or run it ourselves on AWS servers (the "self-hosted" option). This document is only about the *self-hosted* path: if Region 20 chooses to run these tools itself, **what kind of AWS computer should each tool run on, and what will it cost?** It compares the realistic options side by side and ends with a clear recommendation for each tool.

## What decision does this document help make?

If Region 20 decides to self-host Airbyte and dbt (rather than buying the managed Cloud versions), it must pick the *compute platform* — the type of AWS infrastructure that actually runs the software. There is no single "best" answer; the right choice depends on how each tool behaves at runtime. This document walks through that reasoning and lands on a specific recommendation:

- **dbt-core** → run it as a short-lived container job on **ECS Fargate** (explained below).
- **Airbyte OSS** → run it on a single **EC2** virtual server using Airbyte's own installer.

You do not need to read all of it to act on it. The [Recommendation](#5-recommendation) section is the bottom line; the rest explains why.

> **A quick glossary of the compute terms used throughout**
>
> - **vCPU** — a "virtual CPU," i.e. one slice of a processor's computing power. More vCPUs means more work can run in parallel.
> - **Memory (RAM)**, measured in GB — short-term working space the software uses while running. Running out of it causes crashes.
> - **EC2 (Elastic Compute Cloud)** — a plain virtual server (a "computer in the cloud") that you rent by the hour and are responsible for patching and managing. See the [Concepts Glossary](concepts-glossary.md).
> - **Container** — a lightweight, self-contained package of an application plus everything it needs to run, so it behaves the same anywhere.
> - **ECS Fargate (Elastic Container Service with Fargate)** — AWS's "serverless" way to run containers. You hand AWS a container and how much vCPU/memory it needs; AWS finds a machine, runs it, and bills you only for the seconds it runs. There is no server for you to manage.
> - **Kubernetes** — an industry-standard system for running and coordinating many containers across many machines. It is powerful but operationally heavy; Airbyte requires it internally.
> - **Spot capacity** — spare AWS compute offered at a steep discount (often 60-70% off) with the catch that AWS can reclaim it on short notice. Safe for jobs that can simply be retried.

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Workload Profiles](#2-workload-profiles)
3. [Compute Option Comparison](#3-compute-option-comparison)
4. [Well-Architected Scoring](#4-well-architected-scoring)
5. [Recommendation](#5-recommendation)
6. [Proposed Module Shape](#6-proposed-module-shape)
7. [Open Questions](#7-open-questions)
8. [Next Steps](#8-next-steps)

## 1. Executive Summary

This document evaluates compute platform options, TCO and pros and cons for running dbt-core (the open-source CLI) and Airbyte OSS on AWS, 
if Region 20 ESC prefers running the self hosted versions of both tools.

**Recommendation summary:**

- **dbt-core:** ECS Fargate with scheduled tasks. Short-lived, stateless batch jobs are a natural fit for
  Fargate's serverless container model. Spot capacity reduces cost 60-70% with no operational overhead
  beyond what Fargate already abstracts.

- **Airbyte OSS:** EC2 Auto Scaling Group (an ASG is an AWS feature that keeps a target number of EC2
  servers running and automatically launches a replacement if one dies) running `abctl` on a
  Docker-enabled AMI (an AMI, Amazon Machine Image, is the pre-configured disk image a new server boots
  from), with all durable state externalized to RDS PostgreSQL (RDS, Relational Database Service, is
  AWS's managed database service — see the [Concepts Glossary](concepts-glossary.md)), S3 (object
  storage), and Secrets Manager (AWS's encrypted store for passwords and credentials). `abctl` is
  Airbyte's vendor-supported
  installer. The only AMI prerequisite is Docker. `abctl` handles kind cluster creation, Helm chart
  application, and version upgrades without any additional tooling on the host. Because every piece of
  durable state is external to the instance, the kind cluster holds no data and ASG replacement is safe:
  user-data runs `abctl local install --values <values-file>` and the cluster reconnects to the same
  RDS, S3, and Secrets Manager resources.

## 2. Workload Profiles

Understanding the runtime shape of each tool is what makes the compute choice non-obvious. They are
fundamentally different classes of workload.

> **Why "workload shape" decides the answer:** a tool that starts, does a few minutes of work, and shuts
> down (dbt) is best matched to pay-per-second serverless compute. A tool that must stay running 24/7 to
> listen for and coordinate jobs (Airbyte) is best matched to an always-on server. The tables below
> establish each tool's shape; the cost comparison in [Section 3](#3-compute-option-comparison) follows
> directly from it.
>
> Note: dbt does not crunch the data itself — it sends SQL instructions to **Redshift** (Amazon's data
> warehouse, the "Gold" layer where report-ready data lives) and lets Redshift do the heavy lifting. That
> is why dbt itself needs very little compute. See the [Concepts Glossary](concepts-glossary.md) for
> Redshift, Iceberg, and the medallion (bronze/silver/gold) layers.

### dbt-core

| Attribute | Detail |
|---|---|
| **Execution model** | Single-process CLI invocation: runs SQL transforms against Redshift, then exits |
| **Duration** | Typically 5-30 minutes per run; full-refresh runs for all sources could reach 60 minutes at Region 20's data volume (~200 GB structured) |
| **Concurrency** | One run at a time per environment; parallelism is internal to dbt (threaded SQL via `--threads N`) |
| **State** | Fully stateless. The dbt project lives in a Git repo. No persistent disk beyond the working container filesystem |
| **Resource sizing** | Lightweight: 0.5-1 vCPU, 1-2 GB RAM is sufficient; dbt hands off compute to Redshift |
| **Network** | Needs TCP 5439 outbound to Redshift Serverless (private subnet, via VPC endpoint or internal SG) and TCP 443 to Secrets Manager |
| **Secrets** | One secret at runtime: Redshift service-user credentials |
| **Invocation** | Scheduled (EventBridge cron) or event-driven (Airbyte webhook -> Step Functions -> ECS RunTask) |
| **Key contrast with Airbyte** | Starts, does work, terminates. No daemon process. No persistent config store. |

### Airbyte OSS

| Attribute | Detail |
|---|---|
| **Execution model** | Kubernetes-only distributed system since version 1.x. Multiple pods run simultaneously: server (API), webapp (UI), worker, workload-launcher, workload-api-server, temporal (workflow engine), cron, manifest-server, and an ephemeral bootloader init job. |
| **Deployment path** | The official Helm chart (`airbyte/airbyte`) is the only supported install path. The `abctl` CLI (marketed as "EC2 install") works by running `kind` (Kubernetes-in-Docker) on the host and applying the same Helm chart. |
| **References** | https://docs.airbyte.com/platform/deploying-airbyte/#understanding-the-airbyte-deployment and https://docs.airbyte.com/platform/deploying-airbyte/abctl/#overview-of-abctl |
| **Duration** | Control plane runs 24/7. Individual sync workers (pods) are ephemeral; launched per sync job, terminated after completion. |
| **Concurrency** | Temporal dispatches sync workers on demand; at Region 20's scale (~6 connectors, daily/hourly syncs) peak concurrent workers = 3-5 |
| **State** | Stateful. PostgreSQL stores all connection definitions, sync history, and job metadata. Loss of this DB means loss of all connection configurations. |
| **Resource sizing** | The Helm chart ships all resource requests and limits as empty (`{}`); the operator must set them. Based on Airbyte's own sizing guidance and community reports: server ~1 vCPU/2 GB, worker ~1 vCPU/2 GB, temporal ~1 vCPU/2 GB, workload-launcher ~0.5 vCPU/1 GB, workload-api-server ~0.5 vCPU/1 GB, cron ~0.25 vCPU/0.5 GB, webapp ~0.25 vCPU/0.5 GB, manifest-server ~0.25 vCPU/0.5 GB. Total steady-state control plane: ~5.5 vCPU, ~10 GB RAM. Plus headroom for sync job pods (~0.5-1 vCPU, 1-2 GB each). Minimum instance: **m5.2xlarge (8 vCPU, 32 GB)** for comfortable headroom; m5.xlarge (4 vCPU, 16 GB) is the floor with tight resource limits. |
| **Network** | Workers need outbound access to source systems (NAT Gateway for SSH tunnels to bastions). TCP 5439 to Redshift. TCP 443 to Secrets Manager and S3. |
| **Persistence** | Chart default uses in-cluster PostgreSQL (PVC) and MinIO (500Mi PVC). Both must be externalized for a recoverable production deployment. |

**The fundamental difference that drives separate compute strategies:** dbt is a transient job. Airbyte is a
persistent Kubernetes-native service.

## 3. Compute Option Comparison

### 3.1 dbt-core Compute Options

Cost assumptions:
- Region: us-east-1
- Scale: 6 active Airbyte connectors, daily to hourly syncs, dbt runs 4-8 times/day, one dev and one prod environment
- Pricing: AWS public on-demand rates as of Q2 2026, Spot savings quoted as typical 60-70% discount vs. On-Demand

#### Option A -- ECS on Fargate (Recommended)

**Fit:** Optimal. Fargate's task model maps perfectly to dbt's execution model: provision task resources,
run the job, terminate, pay only for active compute. No idle cost between runs.

**Cost (monthly, prod environment):**

| Line item | Assumption | Monthly estimate |
|---|---|---|
| Fargate On-Demand task | 0.5 vCPU / 1 GB RAM, 60 min/day, 30 days | ~$4.80 |
| Fargate Spot task | Same specs, 70% discount | ~$1.44 |
| ECR image storage | ~1 GB dbt image | ~$0.10 |
| CloudWatch Logs | Task logs, ~500 MB/month | ~$0.25 |
| Secrets Manager | 1 secret, 4-8 reads/day | ~$0.40 |
| **Total (On-Demand)** | | **~$5.55/month** |
| **Total (Spot)** | | **~$2.19/month** |

Note: Redshift and NAT Gateway costs are already accounted for in the existing platform TCO.

**Operational burden:** Very low. No patching, no AMI management. Task definition updates are a 1-line
change to the image tag. Logs ship automatically to CloudWatch Logs. ECS RunTask API call from Step
Functions triggers a run.

**Security posture:** Strong. Task execution role uses least-privilege IAM (Secrets Manager read, Redshift
connect). Task IAM role is separate from execution role. No SSH access surface. Network: task runs in
private subnet, outbound to Redshift via VPC endpoint, Secrets Manager via VPC endpoint, no public IP.

**Pros:**
- Zero idle cost, pay only for task execution time
- No infrastructure to patch or size
- Native ECS RunTask API integration with Step Functions
- Spot pricing available for additional cost reduction
- Container isolation, clean environment per run

**Cons:**
- Cold start adds ~20-30 seconds per run (image pull from ECR)
- Fargate max task duration is 14 days (not a constraint for dbt)
- Slightly higher per-second cost than EC2 for long-running workloads (not applicable here)

#### Option B -- ECS on EC2 (Capacity Providers)

**Fit:** Adequate but over-engineered for this workload. EC2 capacity providers shine when tasks run for
hours continuously or require GPU/specialized hardware. A dbt task running 30-60 minutes/day does not
justify managing EC2 instances.

**Cost (monthly, prod environment):**

| Line item | Assumption | Monthly estimate |
|---|---|---|
| t3.small On-Demand (always-on base) | 2 vCPU, 2 GB, 1 instance | ~$15.18 |
| EBS gp3 root volume | 20 GB | ~$1.60 |
| ECS overhead | CloudWatch agent, etc. | ~$1.00 |
| **Total** | | **~$17.78/month** |

The EC2 instance runs idle for ~23.5 hours/day. This is 3-8x more expensive than Fargate for this usage
pattern.

**Pros:**
- Instance warm -- no cold start delay
- Can co-locate multiple ECS services on the same cluster

**Cons:**
- Pays for idle EC2 time (23.5 hours/day for this workload)
- More operational overhead than Fargate for no meaningful benefit at this scale

#### Option C -- EC2 ASG (No Container Orchestrator)

**Fit:** Poor. Running dbt-core via cron/systemd on a bare EC2 instance introduces operational debt
(manual patching, AMI lifecycle, coarser IAM via instance profile, no container isolation) for a workload
that is perfectly served by Fargate.

**Cost (monthly, prod environment):**

| Line item | Assumption | Monthly estimate |
|---|---|---|
| t3.small On-Demand | 1 instance, always-on | ~$15.18 |
| EBS gp3 root volume | 20 GB | ~$1.60 |
| **Total** | | **~$16.78/month** |

**Pros:**
- Simplest mental model (just a Linux box running a script)

**Cons:**
- All operational overhead with none of the orchestration benefits
- Instance profile IAM is coarser-grained than ECS task role
- No container image provenance or image scanning integration

### 3.2 Airbyte OSS Compute Options

Airbyte requires Kubernetes since the 1.x release. Since deploying a full EKS cluster is overkill for this project, EC2 with the tool installed using the official CLI is the right approach here. Externalizing all supporting services such as DB, Secrets management and file storage to AWS native services.

#### EC2 ASG running abctl/kind

**What it is:** A single EC2 instance in an Auto Scaling Group. User-data installs Docker (via `dnf` or
a pre-baked AMI), then downloads the `abctl` CLI from the official Airbyte release URL. `abctl local
install --values <values-file>` creates a `kind` cluster inside Docker, applies the Airbyte Helm chart,
and configures all external dependencies. This is Airbyte's vendor-supported install path. Airbyte tests
it, documents it, and builds the upgrade procedure around it.

**The only AMI prerequisite is Docker.** No separate Kubernetes distribution to install. No Helm CLI to
manage. No chart values rendering to author from scratch. `abctl` encapsulates all of that.

**Fit for this use case:** Strong. Although `kind` originated as a local development tool, the
architecture is what determines recoverability, not the Kubernetes runtime. All durable state is
external to the instance:

- RDS PostgreSQL: Airbyte config DB and Temporal workflow DB (two schemas on the same instance)
- S3: Connector logs, audit logs, state payloads, workload output (`global.storage.type: s3`)
- Secrets Manager: Connector credentials (`global.secretsManager.type: AWS_SECRET_MANAGER`)

With all state external, the kind cluster holds no durable data. It is cattle. If the instance is
terminated by the ASG or dies unexpectedly, the ASG launches a replacement, user-data runs `abctl local
install --values <values-file>`, and the new cluster reconnects to the same RDS, S3, and Secrets Manager
resources. No sync history is lost. Connectors that were mid-run are retried by Temporal on the next
scheduler tick. The kind cluster itself is simply rebuilt.

**Cost (monthly, prod environment):**

| Line item | Assumption | Monthly estimate |
|---|---|---|
| m5.xlarge On-Demand (control plane) | 4 vCPU, 16 GB RAM, 1 instance, 24/7 | ~$139 |
| EBS gp3 root volume | 30 GB | ~$2.40 |
| RDS PostgreSQL db.t3.small Multi-AZ | Airbyte config + Temporal state | ~$58 |
| S3 (logs + artifacts) | ~5 GB/month, standard tier | ~$0.12 |
| ALB (Airbyte Webapp) | Internal ALB, low traffic | ~$18 |
| Secrets Manager | 8-10 secrets, ~30 reads/day | ~$5 |
| NAT Gateway (SSH tunnels to bastions) | ~2 GB/month connector traffic | ~$33 |
| CloudWatch Logs | System logs + Airbyte pod logs | ~$3 |
| **Total** | | **~$258/month** |

Note: m5.xlarge is the floor. Recommend starting with m5.xlarge and sizing up to m5.2xlarge (~$278 delta)
if memory pressure is observed during sync peaks.

**Operational burden:** Low to medium. Day-to-day operations follow Airbyte's documented procedures:
`abctl local install` for upgrades, `abctl local status` for health checks. Instance OS patching is
handled by SSM Patch Manager. Break-glass debugging uses `kubectl` against the kind cluster (abctl
exposes the kubeconfig). The operator does not need to own a Helm upgrade workflow or maintain a
separately managed values rendering pipeline, `abctl` handles that.

**Failure recovery:** ASG launches a replacement instance, user-data runs `abctl local install --values
<s3-path-or-ssm-path>`, kind cluster is rebuilt, Airbyte reconnects to external state, operations
resume. The kind cluster is rebuilt from scratch on every instance replacement. That is the design intent
when state is fully externalized.

**Security posture:** Good. The kind cluster API is not exposed outside the instance. The EC2 instance
profile grants IAM permissions (S3, Secrets Manager, CloudWatch). Connector credentials are pulled from
Secrets Manager by Airbyte's built-in secrets manager integration at runtime, not stored in values files.
ALB terminates TLS and restricts webapp access to the VPC CIDR. SSM Session Manager provides shell
access without open SSH ports.

**Pros:**
- Airbyte's vendor-supported install path, Airbyte tests and documents this procedure
- No separate Kubernetes runtime to install, no Helm CLI to manage, no chart values rendering to author
- All durable state externalized: kind cluster holds no data, ASG replacement is safe and routine
- Upgrade procedure is `abctl local install` against a new chart version, follows Airbyte docs
- Failure recovery is a single user-data invocation, not a custom restore procedure

**Cons:**
- Single-node cluster: if the node is down, Airbyte is down (no HA within the cluster)
- ASG replacement gap: 5-10 minutes of downtime during instance replacement (scheduled syncs are retried,
  but in-progress syncs are lost and must be restarted)
- kind is a development-oriented runtime; some advanced Kubernetes tooling expects a more conventional
  distribution (rarely relevant at this scale)

## 5. Recommendation

### dbt-core: Use ECS Fargate

- **Zero idle cost.** dbt runs 30-60 minutes/day. Fargate charges only for active task time. The entire
  monthly dbt compute bill is under $6 On-Demand and under $2.50 with Spot.
- **Native integration with existing architecture.** The Step Functions pattern calls ECS RunTask
  natively. The VPC already has private subnets and the necessary VPC endpoints in place.
- **No operational overhead beyond image management.** dbt version updates are a single ECR image tag
  change and a task definition update.
- **Spot is safe for this workload.** A Spot interruption during a dbt run results in a failed pipeline
  execution and a Step Functions retry. No state is lost.

**Condition for changing this recommendation:** If dbt runs exceed 8+ hours/day, a t3.small EC2 instance
on ECS starts to be cost-comparable. At Region 20's expected run frequency (4-8 runs/day, incremental
models), Fargate remains optimal.

### Airbyte OSS: Use abctl on a Docker-enabled EC2 AMI in an Auto Scaling Group

Use `abctl` on a Docker-enabled EC2 AMI in an Auto Scaling Group with all durable state externalized to
RDS PostgreSQL, S3, and Secrets Manager.

- **abctl is Airbyte's vendor-supported installer.** Choosing it minimizes the operational surface owned
  by the platform team. Airbyte tests this path, documents it, and builds the upgrade procedure around
  it. Deviating from it (e.g., raw Helm + k3s) means the operator owns the install, upgrade, ingress,
  and debugging procedures without vendor-tested guidance.
- **The only AMI prerequisite is Docker.** No separate Kubernetes distribution to install, no Helm CLI
  to manage, no chart values rendering to author from scratch. User-data installs Docker (if not
  pre-baked into the AMI), downloads abctl from the official release URL, and runs
  `abctl local install --values <values-file>`.
- **All durable state is externalized.** The kind cluster on the instance holds no data. ASG replacement
  is safe: user-data rebuilds the kind cluster from scratch and reconnects to the same RDS, S3, and
  Secrets Manager resources. No sync history is lost.
- **Failure recovery is a single invocation.** `abctl local install --values <values-file>` on a fresh
  instance restores the full Airbyte deployment. No custom restore procedure to author or test.
- **Upgrades follow Airbyte's documented procedure.** Running `abctl local install` against a new chart
  version is the upgrade path Airbyte publishes. The operator does not invent this.
