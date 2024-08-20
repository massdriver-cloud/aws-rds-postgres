## AWS RDS PostgreSQL

Amazon Relational Database Service (RDS) for PostgreSQL is a managed relational database service that makes it easy to set up, operate, and scale PostgreSQL deployments in the cloud. With Amazon RDS, you can deploy and scale PostgreSQL databases in minutes with cost-efficient and resizable hardware capacity. This service handles time-consuming database administration tasks such as backups, software patching, monitoring, scaling, and replication, thereby freeing you up to focus on application development.

### Design Decisions

- **Engine Selection**: This module is designed specifically for PostgreSQL, ensuring that all configurations and optimizations are tailored for this database engine.
- **Security**: The module includes configurations for VPC security groups to control access, and uses AWS KMS for encryption at rest.
- **Monitoring**: Enhanced monitoring and CloudWatch alarms are enabled to provide detailed insights and alerting capabilities.
- **Backup and Recovery**: Configurations for automated backups with customizable retention periods and settings for final snapshots during deletion are included to facilitate data protection and disaster recovery.
- **Parameter Group Management**: Parameter groups allow for one-click database parameter settings based on best practices.

### Runbook

#### Instance Connection Issues

Unable to connect to your RDS PostgreSQL instance.

Use the AWS CLI to describe the DB instance and check for issues such as incorrect security groups, availability, and endpoint status.

```sh
aws rds describe-db-instances --db-instance-identifier your-db-instance-identifier
```

Ensure the `Endpoint` information is correct. The response information should include the endpoint address and port.

#### High CPU Utilization

When your RDS instance experiences high CPU utilization.

Check CloudWatch metrics to monitor CPUUtilization.

```sh
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization --dimensions Name=DBInstanceIdentifier,Value=your-db-instance-identifier --start-time 2022-01-01T23:18:00 --end-time 2022-01-01T23:23:00 --period 60 --statistics Average
```

Consider actions such as upgrading your DB instance class or optimizing your queries.

#### Low Free Storage Space

When free storage space is low.

Check CloudWatch metrics for FreeStorageSpace.

```sh
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name FreeStorageSpace --dimensions Name=DBInstanceIdentifier,Value=your-db-instance-identifier --start-time 2022-01-01T23:18:00 --end-time 2022-01-01T23:23:00 --period 60 --statistics Average
```

Consider actions such as increasing your allocated storage or cleaning up old data.

#### Postgres Connection Slowness

If connections to your PostgreSQL database seem slow.

Log into your PostgreSQL instance and run diagnostic queries.

```sql
SELECT * FROM pg_stat_activity;
```

This query will show currently active connections. Look for any unexpected long-running transactions or high connection counts.

```sql
EXPLAIN ANALYZE SELECT * FROM your_table WHERE your_condition;
```

The `EXPLAIN ANALYZE` command helps you examine query plans and identify potential inefficiencies.

#### Error in Parameter Group Application

Issues applying new parameters through the parameter group.

Review applied parameters and their statuses.

```sql
SELECT name, setting, source FROM pg_settings;
```

Validate that the parameters configured match your expected settings and adjust as necessary.

If changes are not immediate, remember some parameters may require an instance restart to take effect.

