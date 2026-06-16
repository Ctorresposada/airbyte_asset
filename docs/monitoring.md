# Monitoring

> Back to [docs landing page](README.md) · See also the [Concepts Glossary](concepts-glossary.md)

> **In plain terms**
>
> This document explains how the data platform keeps an eye on itself. Instead of someone manually checking every part of the system each morning, AWS continuously measures things like "how many queries failed" or "how full is the disk," and automatically emails the team the moment something looks wrong. It matters because the platform runs unattended: without this, a broken data feed or a failed nightly job could go unnoticed for days, and reports would quietly show stale numbers. Read [Section 1](#1-how-notifications-work) to understand how the alerts reach you, then use [Section 7](#7-alarm-quick-reference) as the at-a-glance list of everything being watched.

This document describes the monitoring and alerting setup for the Region 20 ESC data platform. The platform is designed to watch itself — when something goes wrong, the team receives an automatic notification rather than discovering a problem after reports have gone stale or a data refresh has silently failed.

Monitoring works through two complementary mechanisms. Dashboards are always-on visual screens showing graphs and numbers in near-real-time. Anyone with AWS console access can pull them up at any time as a quick health check. Alarms are automated sentinels that compare live measurements against defined thresholds and send an email notification the moment a threshold is crossed and another when the condition clears.

Notifications are divided into two tiers: **Warning** and **Critical**. Warning signals something that may need attention soon but is not yet affecting data freshness or report availability. Critical signals something that is likely already affecting the platform and requires prompt action. Each tier sends to its own email list, so the right people can be notified at the right urgency level.

Some monitoring components in this document are marked as optional. The platform integrates with Airbyte (a data integration tool) and dbt (a data transformation tool), and a decision has not yet been finalized on whether to use the self-hosted versions of each or their respective cloud-managed alternatives. The optional sections apply only when a self-hosted deployment is chosen, they can be activated with a single configuration flag.

## Table of Contents

1. [How Notifications Work](#1-how-notifications-work)
2. [Core Monitoring (Always Active)](#2-core-monitoring-always-active)
   - 2.1 [Redshift Serverless — Data Warehouse](#21-redshift-serverless--data-warehouse)
   - 2.2 [Athena — Query Engine for Raw and Bronze Data](#22-athena--query-engine-for-raw-and-bronze-data)
   - 2.3 [Lambda Function — Google Drive Sync (TEA Data)](#23-lambda-function--google-drive-sync-tea-data)
   - 2.4 [Glue Crawlers — Connect20 and Ascender Data Cataloging](#24-glue-crawlers--connect20-and-ascender-data-cataloging)
   - 2.5 [S3 Data Lake — Storage Buckets](#25-s3-data-lake--storage-buckets)
3. [Optional Monitoring — Airbyte (Self-Hosted)](#3-optional-monitoring--airbyte-self-hosted)
   - 3.1 [Airbyte Server — EC2 Instance Health](#31-airbyte-server--ec2-instance-health)
   - 3.2 [Airbyte Database — RDS PostgreSQL](#32-airbyte-database--rds-postgresql)
4. [Optional Monitoring — dbt on ECS (Self-Hosted Transformations)](#4-optional-monitoring--dbt-on-ecs-self-hosted-transformations)
   - 4.1 [ECS Fargate Cluster](#41-ecs-fargate-cluster)
   - 4.2 [dbt Task Failure Event](#42-dbt-task-failure-event)
5. [Composite Alarm — Pipeline Health](#5-composite-alarm--pipeline-health)
6. [Dashboards](#6-dashboards)
   - 6.1 [Data Platform Overview](#61-data-platform-overview)
   - 6.2 [Compute and Jobs](#62-compute-and-jobs)
7. [Alarm Quick Reference](#7-alarm-quick-reference)

## 1. How Notifications Work

> **The four words used throughout this document**
>
> - **Metric** — a single number AWS measures over and over, on a schedule. Examples: the count of failed queries in the last 10 minutes, or the percentage of a disk that is full. Most metrics come from a service called **CloudWatch** (AWS's built-in measurement and dashboard service — see the [Concepts Glossary](concepts-glossary.md)).
> - **Threshold** — the line a metric is not supposed to cross. For example, "5 failed queries in 10 minutes." It is the rule that defines "this is now a problem."
> - **Alarm** — a watcher tied to one metric and one threshold. It sits quietly while the metric is fine, and switches to an "in alarm" state the moment the metric crosses the threshold. When it switches state, it sends a notification. (It also notifies again, with an "OK," when things return to normal.)
> - **SNS notification** — the actual message that goes out. **SNS** (Simple Notification Service) is AWS's notification dispatcher: an alarm hands its message to SNS, and SNS emails it to everyone on the relevant list.
>
> Putting it together: AWS measures a **metric**, an **alarm** checks that metric against a **threshold**, and if the threshold is crossed the alarm uses **SNS** to email the team.
>
> **About the two severity tiers, in lay terms:** every alarm is labelled either **Warning** or **Critical**. Think of **Warning** as "the dashboard light came on — look into it soon, but nothing is broken yet" (for example, a disk filling up or queries running slow). Think of **Critical** as "something is actually broken right now and the data may already be wrong or missing — act promptly" (for example, a data sync failed or the warehouse is rejecting queries). The two tiers email two separate lists so the most urgent alerts can go to the people who need to drop what they are doing.

When an alarm crosses its threshold, AWS SNS (Simple Notification Service, think of it as a managed notification broadcast channel) delivers a message to everyone subscribed to that channel. The platform uses two SNS topics, one per severity tier.

- The **Warning topic** receives notifications for conditions that are degraded but not yet causing failures: slow queries, high resource usage, unusual data volumes.
- The **Critical topic** receives notifications for conditions that are actively causing failures or data loss: failed syncs, crashed crawlers, query engine errors.

Each topic maintains a list of email addresses. When an alarm fires, every address on the relevant list receives an email. The email includes the alarm name, the metric that triggered it, the current measured value, the threshold it crossed, and the time of the state change.

When an alarm condition clears, for example a query failures drop back below the threshold, the system sends an "OK" notification to the same topic. These recovery notifications are useful because they confirm the issue is resolved without requiring someone to manually check. In lower-priority environments, OK notifications are often turned off to reduce noise. In production they are typically kept on.

## 2. Core Monitoring (Always Active)

The following monitoring is deployed regardless of which optional components are in use. It covers the data lake storage layer, the two query engines (Redshift and Athena), the TEA data ingestion function, and the Connect20 and Ascender cataloging jobs.

> **The "Raw / Bronze / Silver / Gold" layers (the medallion model):** the platform refines data in stages, like ore being purified. **Raw** is data exactly as it arrived from a source system; **Bronze** is that data cleaned and standardized; **Silver** is structured and analysis-ready; and **Gold** is the final report-ready tables (which live in Redshift). Each stage is monitored separately so the team can tell *which* step broke. See the [Concepts Glossary](concepts-glossary.md) for more on the medallion layers and the data lake.

### 2.1 Redshift Serverless — Data Warehouse

Redshift Serverless is a fully managed database service that scales its compute capacity automatically based on demand. There are no servers to provision or manage, and you only pay for the compute time actually used. It is the Gold layer of the data platform: the place where clean, analysis-ready data lives and where BI tools and scheduled reports run their queries.

| Alarm Name | What It Measures | Why It Matters | Threshold | Severity |
|---|---|---|---|---|
| Active Queries | Number of queries running simultaneously (`QueriesRunning`) | Indicates whether the database is under normal or unusually heavy load | > 50 concurrent queries for 15 min | Warning |
| Query Failures | Number of failed queries (`QueryFailed`) | Failed queries mean reports are returning errors or incomplete data | >= 5 failures in 10 min | Critical |
| Connection Limit | Number of active database connections (`DatabaseConnections`) | Too many simultaneous connections can exhaust the connection pool and block new ones | > 200 connections for 15 min | Warning |
| Compute Usage | Compute capacity consumed per hour (`ComputeSeconds`, hourly sum) | Unexpected compute spikes can signal an inefficient query or runaway job and drive up cost | Hourly sum exceeds threshold | Warning |

The Active Queries alarm would fire during an unexpected batch job, a report tool that opened too many parallel connections, or a runaway query that spawned many child queries. The Query Failures alarm is the most actionable of the four: any time it fires, the team should check whether scheduled reports are returning errors and identify which queries are failing. The Compute Usage alarm is both an operational signal and a cost signal: Redshift Serverless bills by the second of compute capacity consumed, so a sustained spike in this metric translates directly into a larger monthly bill.

### 2.2 Athena — Query Engine for Raw and Bronze Data

Athena is a query engine that lets the team query raw data files stored in the data lake as if they were a database, no separate database server required. Think of it as being able to ask structured questions directly against the files sitting in storage. You pay only for the amount of data Athena reads when answering a query. Athena is used primarily on the Raw and Bronze layers, where data has arrived from source systems but has not yet been fully transformed.

| Alarm Name | What It Measures | Why It Matters | Threshold | Severity |
|---|---|---|---|---|
| Slow Queries | Execution time of the slowest 1% of queries (p99) | Slow queries indicate data growth, missing partitions, or inefficient query patterns | p99 > 5 minutes | Warning |
| Cost Control | Total data scanned per day (`ProcessedBytes`, daily sum) | Athena charges per byte scanned, unusually high scan volumes mean unexpectedly high bills | > 100 GB scanned in one day | Warning |
| Failed Queries | Count of failed queries, taken directly from Athena's native CloudWatch metric — the `primary` workgroup publishes its own metrics, and this alarm counts the samples where the query state is `FAILED` (CloudWatch dimensions `WorkGroup = primary` and `QueryState = FAILED`) | Query failures indicate a schema change, a missing data file, or a permissions issue | >= 5 failures in 10 min | Critical |

The Slow Queries alarm is most likely to fire when the data lake grows significantly without a corresponding update to partitioning strategy — Athena reads less data (and runs faster) when files are organized into date-partitioned folders. The Cost Control alarm is a financial guardrail: a single poorly written query against an unpartitioned table can scan hundreds of gigabytes and generate a surprising bill. The Failed Queries alarm draws on Athena's own built-in CloudWatch metrics rather than parsing logs — Athena does not write per-query logs to CloudWatch Logs, but the `primary` workgroup is configured to publish its query metrics directly, including a count of queries that ended in a failed state. This alarm often surfaces when a schema change in an upstream data source (a new column, a renamed field) breaks a downstream query that was written against the old structure.

### 2.3 Lambda Function — Google Drive Sync (TEA Data)

A Lambda function is a small, self-contained piece of code that runs on demand without any dedicated server. AWS manages all the underlying infrastructure, the function simply runs when triggered and stops when finished. The `gdrive-sync` function runs on a daily schedule, connects to a designated Google Drive folder, and copies new TEA files into the Raw layer of the data lake. It is the first link in the TEA data ingestion chain.

| Alarm Name | What It Measures | Why It Matters | Threshold | Severity |
|---|---|---|---|---|
| Sync Errors | Number of errors during function execution (`Errors`) | Errors mean today's TEA data may not have been copied into the data lake | >= 3 errors in 10 min | Critical |
| Sync Throttling | Number of times the function was temporarily blocked by AWS (`Throttles`) | Throttling causes delayed ingestion, if it recurs frequently the function needs a concurrency limit increase | >= 5 throttles in 10 min | Warning |
| Sync Duration | Maximum execution time of the function in the period (`Duration`, max) | Lambda functions have a hard 15-minute limit, if the function is cut off mid-run, the sync is incomplete | Max > 13.5 min (90% of limit) | Warning |
| Sync Error Rate | Ratio of errors to total invocations (`Errors / Invocations`) | A high error rate means the sync is unreliable even if the total error count is low | > 5% error rate | Critical |

The Sync Errors alarm is the primary alert for TEA data freshness. If it fires on a weekday morning, the team should check whether today's TEA files appeared in the data lake. The Sync Duration alarm is a leading indicator — if the function is regularly taking 13+ minutes, it will eventually be cut off as the data volume grows, and the function's logic should be reviewed. Throttling is unusual in practice (it requires many parallel invocations of the same function), but if it persists, the platform team can request a concurrency limit increase from AWS.

### 2.4 Glue Crawlers — Connect20 and Ascender Data Cataloging

A Glue Crawler is an automated process that scans data files in the lake on a schedule, figures out their structure (what columns exist, what data types they contain), and updates the data catalog so analysts can query those files through Athena. Think of it as an automated librarian that visits the filing cabinet every night, reads the labels on new folders, and updates the index. The platform runs two crawlers: the Connect20 crawler and the Ascender crawler, both cataloging their respective data files in the Bronze layer.

Both crawlers are monitored for failure through AWS EventBridge (AWS's event bus — a central channel that AWS services use to announce things that happen, which other systems can listen for). Glue automatically emits an event every time a crawler changes state, and the platform sets up an EventBridge rule that listens specifically for any crawler reporting a `Failed` state. The moment either crawler fails, the rule fires and sends a notification to the Critical topic. Because this approach watches for events rather than reading a log, it needs no log group to exist first and works even before a crawler has ever run.

| Alarm Name | What It Measures | Why It Matters | Threshold | Severity |
|---|---|---|---|---|
| Crawler Failure | Whether either crawler (Connect20 or Ascender) reported a `Failed` state, detected via an EventBridge rule on Glue's "Glue Crawler State Change" event | A failed crawl means newly delivered data is not visible to analysts, it exists in storage but cannot be queried | Any `Failed` event | Critical |

The Crawler Failure alert is a binary signal: a crawl either succeeded or it did not. When one fails, the data that crawler delivered since its last successful run will not appear in Athena query results, and the team is notified immediately.

Crawler run duration is intentionally not monitored. AWS Glue does not publish a crawler run-duration metric, and the state-change event that signals success or failure carries no elapsed-time field. The only way to alarm on how long a crawl takes would be to build a custom Lambda function to compute the duration ourselves, which was judged not worth the operational overhead for the value it would add. Duration is therefore left unmonitored.

### 2.5 S3 Data Lake — Storage Buckets

S3 (Simple Storage Service) is the storage backbone of the data platform. Data lives in S3 at every stage of the medallion pipeline: Raw data arrives from source systems exactly as delivered, Bronze data has been cleaned and standardized, Silver data is structured and ready for analytical use. Each layer has its own dedicated storage bucket, providing clear separation and independent access controls.

| Alarm Name | What It Measures | Why It Matters | Threshold | Severity |
|---|---|---|---|---|
| Raw Bucket Empty | Number of objects in the Raw bucket (`NumberOfObjects`) | If the raw bucket is empty, all upstream data feeds (Ascender replication, Connect20, Google Drive sync) have stopped delivering | < 1 object | Warning |
| Bronze Bucket Empty | Number of objects in the Bronze bucket (`NumberOfObjects`) | If the Bronze bucket is empty, the pipeline step that cleans and stages raw data has stopped running | < 1 object | Warning |
| Silver Bucket Empty | Number of objects in the Silver bucket (`NumberOfObjects`) | If the Silver bucket is empty, the structured analytical layer is unavailable | < 1 object | Warning |

One important note about S3 storage metrics: AWS reports object counts and storage sizes for S3 once per day, not in real time. These alarms are designed to catch a prolonged absence of data. For example, a bucket that is empty because a data feed has been misconfigured or stopped entirely. They are not intended to detect a gap of a few hours. An alarm on the Raw bucket would not fire until the following day's metric delivery confirms the bucket is still empty.

## 3. Optional Monitoring — Airbyte (Self-Hosted)

Airbyte is the data integration platform that connects external source systems to the data lake, handling the extraction and initial delivery of data from Connect20 and other sources. A decision has not yet been finalized on whether to use the self-hosted version (running on a dedicated AWS virtual server) or Airbyte Cloud (a fully managed service maintained by Airbyte, Inc., with no infrastructure to operate).

The monitoring in this section applies only if the self-hosted option is chosen. All of the alarms described here are inactive by default and can be enabled with a single configuration change:

```
enable_airbyte_monitoring = true
```

### 3.1 Airbyte Server — EC2 Instance Health

The self-hosted Airbyte platform runs on a dedicated EC2 instance (a virtual server) in the private network. This server runs a collection of Docker containers that handle Airbyte's scheduling, orchestration, and connector logic. Because this is a self-managed server, we're responsible for its health. AWS does not automatically restart it or migrate it if it becomes unresponsive.

| Alarm Name | What It Measures | Why It Matters | Threshold | Severity |
|---|---|---|---|---|
| Airbyte CPU | CPU utilization of the Airbyte server (`CPUUtilization`) | High CPU means active sync jobs are competing for processing time and may slow down or fail | > 80% for 15 min | Warning |
| Airbyte Status Check | AWS health checks on the server instance (`StatusCheckFailed`) | A failed status check means AWS has detected the server is unresponsive — all syncs are halted | > 0 for 2 min | Critical |
| Airbyte Disk | Percentage of disk storage used (`disk_used_percent`) | If the disk fills completely, Docker containers will crash and Airbyte will stop functioning entirely | > 85% for 15 min | Critical |
| Airbyte Memory | Percentage of RAM in use (`mem_used_percent`) | High memory pressure causes sync jobs to fail and the system to become sluggish or unresponsive | > 85% for 15 min | Warning |

The Status Check alarm is the most urgent of the four. When it fires, the Airbyte server is not responding to basic health checks from AWS, and the likely resolution is to restart the instance through the AWS console. The Disk alarm is also critical because the primary consumers of disk space: Docker images, container logs, and temporary files created during sync runs grow steadily over time and require periodic cleanup. The CPU and Memory alarms are leading indicators that the server may need to be scaled up (moved to a larger instance type) if they fire regularly.

### 3.2 Airbyte Database — RDS PostgreSQL

Airbyte stores all of its internal configuration: connector definitions, sync schedules, run history, and state tracking in a managed PostgreSQL database (RDS, AWS's managed relational database service). This database is separate from the main Redshift data warehouse and is used exclusively by Airbyte as its own bookkeeping system. If this database becomes unavailable or runs out of storage, Airbyte loses the ability to schedule syncs and record their results.

| Alarm Name | What It Measures | Why It Matters | Threshold | Severity |
|---|---|---|---|---|
| Airbyte DB CPU | CPU utilization of the Airbyte database (`CPUUtilization`) | Sustained high CPU can slow Airbyte's internal operations and sync orchestration | > 80% for 15 min | Warning |
| Airbyte DB Storage | Free storage remaining on the database volume (`FreeStorageSpace`) | If storage runs out, Airbyte stops recording sync state and may stop accepting new sync jobs | < 5 GB free | Critical |
| Airbyte DB Connections | Number of active database connections (`DatabaseConnections`) | An unusually high connection count can indicate a connection leak or an abnormal number of Airbyte workers | > 100 connections for 15 min | Warning |
| Airbyte DB Read Latency | Response time for read operations at the 99th percentile (`ReadLatency`, p99) | High read latency slows the Airbyte UI and the scheduler's ability to look up connector configurations | p99 > 50 ms | Warning |
| Airbyte DB Write Latency | Response time for write operations at the 99th percentile (`WriteLatency`, p99) | High write latency causes sync jobs to appear stuck while Airbyte waits to record job state | p99 > 50 ms | Warning |

The Storage alarm is the most operationally significant of the five. RDS storage does not reclaim itself automatically, and sync history accumulates over time. When this alarm fires, the resolution is to increase the allocated storage size through the AWS console or through a configuration update. The database can be expanded with no downtime. The latency alarms (read and write) are typically only relevant at high sync volume. If they fire consistently, the database may need to be scaled to a larger instance class.

## 4. Optional Monitoring — dbt on ECS (Self-Hosted Transformations)

dbt (data build tool) is the transformation engine that takes cleaned data from the Bronze and Silver layers and produces the Gold layer in Redshift: the final, analysis-ready tables that BI tools query. A decision has not yet been finalized on whether to use the self-managed version (running as a scheduled container job on AWS ECS Fargate, a serverless container platform) or dbt Cloud (a fully managed service maintained by dbt Labs, with no infrastructure to operate).

The monitoring in this section applies only if the self-managed option is chosen. All of the alarms described here are inactive by default and can be enabled with a single configuration change:

```
enable_dbt_ecs_monitoring = true
```

### 4.1 ECS Fargate Cluster

When dbt runs in self-managed mode, it executes as a container job on ECS Fargate (Elastic Container Service with Fargate, AWS's serverless container runtime). Fargate runs the container on demand, there is no server to manage. but the container is allocated a fixed amount of CPU and memory for each run. If the dbt transformation models grow in complexity or data volume, that allocation may need to be increased.

| Alarm Name | What It Measures | Why It Matters | Threshold | Severity |
|---|---|---|---|---|
| dbt ECS CPU | CPU utilization of the dbt container cluster (`CPUUtilization`) | Sustained high CPU means transformation runs are taking longer than expected and may approach their scheduled deadline | > 80% for 15 min | Warning |
| dbt ECS Memory | Memory utilization of the dbt container cluster (`MemoryUtilization`) | If a container exceeds its allocated memory, Fargate forcibly stops it. The transformation run fails and the Gold layer is not updated | > 80% for 15 min | Warning |

These alarms are leading indicators rather than failure alerts. A sustained CPU reading above 80% suggests the container's CPU allocation should be increased in the task definition. A sustained memory reading above 80% is more urgent. The container is at risk of being stopped mid-run by Fargate's out-of-memory protection. See [Section 4.2](#42-dbt-task-failure-event) for the alarm that fires when a run actually fails.

### 4.2 dbt Task Failure Event

This notification is not a threshold-based alarm but a direct event trigger: whenever a dbt transformation run stops with a non-zero exit code (meaning it encountered an error and did not complete normally), an automatic notification is sent immediately to the Critical SNS topic. This covers all failure reasons: a SQL error in a transformation model, a lost connection to Redshift, a Redshift outage, or an out-of-memory stop.

Any time dbt fails to complete its transformation run, the team receives an immediate critical notification. This is the most important signal for data freshness on the platform. A failed dbt run means the Gold layer data in Redshift has not been updated, and any reports or dashboards that query Redshift are showing data from the previous successful run rather than today's data.

## 5. Composite Alarm — Pipeline Health

A composite alarm is a summary signal that fires when any one of several individual critical conditions is true at the same time. Think of it as a single "is the pipeline healthy?" indicator, rather than receiving three separate critical notifications for three separate components of the same underlying problem. When the composite alarm fires, it means at least one critical component of the data pipeline has an active issue.

A composite alarm can only combine other metric alarms — components that have a measurable ALARM state. The Pipeline Health composite alarm fires when any of the following individual alarms is in an ALARM state:

- Lambda gdrive-sync errors (TEA data sync failing)
- Redshift query failures (data warehouse returning errors)

When `enable_airbyte_monitoring = true`, the Airbyte RDS low-storage alarm is also included in the composite. This ensures that a storage condition threatening the Airbyte database — which would halt all Airbyte-managed syncs — is surfaced at the pipeline level, not just as an isolated infrastructure alarm.

Glue crawler failures are deliberately not part of this composite. As described in [Section 2.4](#24-glue-crawlers--connect20-and-ascender-data-cataloging), crawler failures are detected through an EventBridge rule rather than a metric alarm, and an EventBridge rule has no ALARM state for a composite alarm to read. Crawler failures are not unmonitored, though — they still page the team immediately through their own EventBridge to Critical-topic path; they are simply not folded into this single composite signal.

When this alarm fires, the team receives a single critical notification rather than potentially several simultaneous ones for related issues. The notification identifies the composite alarm by name; the team should then check the individual component alarms (see [Section 7 — Alarm Quick Reference](#7-alarm-quick-reference)) to determine which specific component triggered it.

## 6. Dashboards

A CloudWatch dashboard is a live visual screen in the AWS console that displays graphs and charts of platform metrics updated in near-real-time. Dashboards do not send notifications, they are a pull mechanism, intended for daily health checks, investigation after an incident, or an at-a-glance view during a busy ingestion window. Anyone with AWS console access can view these dashboards at any time.

The platform provisions two dashboards.

### 6.1 Data Platform Overview

This dashboard is always active. It is designed for daily health checks and post-incident review. It is organized into four sections:

- **Redshift Serverless** — Active concurrent queries over time, query failure count, active database connections, and hourly compute usage. This section provides a clear picture of whether the data warehouse is healthy and whether its load is within normal bounds.
- **Athena** — Query execution time distribution (showing the spread between fast and slow queries), total data scanned per day (a cost proxy), and failed query count drawn from Athena's native CloudWatch metric for the `primary` workgroup. This section is useful for identifying query efficiency trends and catching unexpected cost spikes before they appear on the bill.
- **Ingestion Pipeline** — Lambda invocation count, error count, and execution duration for the Google Drive sync function. Because Glue publishes no crawler metrics, the dashboard cannot graph crawler run status or duration; in its place this section carries a short text note pointing readers to the EventBridge-based failure alerts (see [Section 2.4](#24-glue-crawlers--connect20-and-ascender-data-cataloging)) — Glue crawler failures are surfaced as an alert rather than a metric graph. This section shows whether data is arriving on schedule.
- **S3 Data Lake** — Object count per bucket (Raw, Bronze, Silver). Because S3 metrics are reported daily, this section reflects the previous day's state rather than real-time counts.

### 6.2 Compute and Jobs

This dashboard is always created but its content adjusts based on which optional monitoring components are enabled. Sections appear only when their corresponding feature flag is set to `true`.

- **dbt ECS** (visible when `enable_dbt_ecs_monitoring = true`) — ECS Fargate cluster CPU and memory utilization over time, showing the resource consumption of dbt transformation runs.
- **Airbyte EC2** (visible when `enable_airbyte_monitoring = true`) — CPU utilization, memory utilization, disk usage percentage, and a recent log lines panel for the Airbyte server instance. The log panel surfaces error messages directly on the dashboard without needing to navigate to the CloudWatch Logs console.
- **Airbyte RDS** (visible when `enable_airbyte_monitoring = true`) — CPU utilization, free storage remaining, active connection count, and read/write latency for the Airbyte configuration database.

## 7. Alarm Quick Reference

The table below summarizes every alarm in the platform. Rows marked with a single asterisk (*) require `enable_airbyte_monitoring = true`. Rows marked with a double asterisk (**) require `enable_dbt_ecs_monitoring = true`.

| Alarm | Component | Severity | Threshold | Notification |
|---|---|---|---|---|
| Active Queries | Redshift | Warning | > 50 concurrent queries | Warning topic |
| Query Failures | Redshift | Critical | >= 5 failures in 10 min | Critical topic |
| Connection Limit | Redshift | Warning | > 200 connections | Warning topic |
| Compute Usage | Redshift | Warning | Hourly compute over threshold | Warning topic |
| Slow Queries | Athena | Warning | p99 > 5 min | Warning topic |
| Cost Control | Athena | Warning | > 100 GB scanned today | Warning topic |
| Failed Queries | Athena | Critical | >= 5 failures in 10 min | Critical topic |
| Sync Errors | Lambda (TEA) | Critical | >= 3 errors in 10 min | Critical topic |
| Sync Throttling | Lambda (TEA) | Warning | >= 5 throttles in 10 min | Warning topic |
| Sync Duration | Lambda (TEA) | Warning | Max > 13.5 min | Warning topic |
| Sync Error Rate | Lambda (TEA) | Critical | > 5% error rate | Critical topic |
| Crawler Failure | Glue (Connect20 + Ascender) | Critical | Any Failed event (EventBridge) | Critical topic |
| Raw Bucket Empty | S3 | Warning | < 1 object | Warning topic |
| Bronze Bucket Empty | S3 | Warning | < 1 object | Warning topic |
| Silver Bucket Empty | S3 | Warning | < 1 object | Warning topic |
| Pipeline Health | Composite | Critical | Any critical child in ALARM | Critical topic |
| Airbyte CPU* | Airbyte EC2 | Warning | > 80% | Warning topic |
| Airbyte Status Check* | Airbyte EC2 | Critical | Any failure | Critical topic |
| Airbyte Disk* | Airbyte EC2 | Critical | > 85% | Critical topic |
| Airbyte Memory* | Airbyte EC2 | Warning | > 85% | Warning topic |
| Airbyte DB CPU* | Airbyte RDS | Warning | > 80% | Warning topic |
| Airbyte DB Storage* | Airbyte RDS | Critical | < 5 GB free | Critical topic |
| Airbyte DB Connections* | Airbyte RDS | Warning | > 100 connections | Warning topic |
| Airbyte DB Read Latency* | Airbyte RDS | Warning | p99 > 50 ms | Warning topic |
| Airbyte DB Write Latency* | Airbyte RDS | Warning | p99 > 50 ms | Warning topic |
| dbt ECS CPU** | ECS Fargate | Warning | > 80% | Warning topic |
| dbt ECS Memory** | ECS Fargate | Warning | > 80% | Warning topic |

\* Requires `enable_airbyte_monitoring = true`

\*\* Requires `enable_dbt_ecs_monitoring = true`
