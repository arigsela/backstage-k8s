# Operations Guide

## Overview

This guide covers operational procedures for managing your **${{ values.databaseName }}** MySQL database, including backup, restore, monitoring, and maintenance tasks.

## Backup & Restore

### Automated Backups

Your database is automatically backed up using the following schedule:

| Backup Type | Frequency | Retention |
|-------------|-----------|-----------|
| **Full Backup** | Daily at 2:00 AM UTC | 30 days |
| **Incremental** | Every 6 hours | 7 days |
| **Point-in-Time** | Continuous (binlog) | 7 days |

### Manual Backup

#### Creating a Manual Backup

```bash
# Create a full database backup
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysqldump -u root -p$MYSQL_ROOT_PASSWORD ${{ values.databaseName }} > backup-$(date +%Y%m%d-%H%M%S).sql

# Create a compressed backup
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysqldump -u root -p$MYSQL_ROOT_PASSWORD ${{ values.databaseName }} | gzip > backup-$(date +%Y%m%d-%H%M%S).sql.gz
```

#### Backup Specific Tables

```bash
# Backup specific tables
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysqldump -u root -p$MYSQL_ROOT_PASSWORD ${{ values.databaseName }} table1 table2 > partial-backup.sql
```

### Restore Operations

!!! danger "Restore Warning"
    Restore operations will overwrite existing data. Always verify the backup before proceeding.

#### Full Database Restore

```bash
# Restore from backup file
kubectl exec -i -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD ${{ values.databaseName }} < backup-file.sql

# Restore from compressed backup
gunzip -c backup-file.sql.gz | kubectl exec -i -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD ${{ values.databaseName }}
```

#### Point-in-Time Recovery

```bash
# List available backup points
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql-backup -o jsonpath='{.items[0].metadata.name}') -- \
  ls -la /backups/

# Restore to specific point in time
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql-backup -o jsonpath='{.items[0].metadata.name}') -- \
  restore-to-point --database=${{ values.databaseName }} --timestamp="2024-01-15 14:30:00"
```

## Database Maintenance

### Regular Maintenance Tasks

#### Optimize Tables

```sql
-- Check table status
SHOW TABLE STATUS FROM ${{ values.databaseName }};

-- Optimize specific tables
OPTIMIZE TABLE table_name;

-- Optimize all tables
SET @sql = '';
SELECT CONCAT('OPTIMIZE TABLE ', table_name, ';') 
FROM information_schema.tables 
WHERE table_schema = '${{ values.databaseName }}' 
INTO @sql;
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
```

#### Analyze Tables

```sql
-- Analyze table statistics
ANALYZE TABLE table_name;

-- Analyze all tables
SET @sql = '';
SELECT GROUP_CONCAT('ANALYZE TABLE ', table_name SEPARATOR '; ') 
FROM information_schema.tables 
WHERE table_schema = '${{ values.databaseName }}' 
INTO @sql;
SET @sql = CONCAT(@sql, ';');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
```

#### Index Maintenance

```sql
-- Check index usage
SELECT DISTINCT
    TABLE_NAME,
    INDEX_NAME,
    SEQ_IN_INDEX,
    COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = '${{ values.databaseName }}'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- Find unused indexes (requires sys schema)
SELECT * FROM sys.schema_unused_indexes 
WHERE object_schema = '${{ values.databaseName }}';
```

### Performance Monitoring

#### Database Metrics

Monitor these key metrics in [Grafana Dashboard](${{ values.grafanaUrl }}/d/mysql-overview/mysql-database-overview?var-database=${{ values.databaseName }}&var-namespace=${{ values.namespace }}):

| Metric | Warning Threshold | Critical Threshold |
|--------|-------------------|-------------------|
| **CPU Usage** | > 70% | > 85% |
| **Memory Usage** | > 80% | > 90% |
| **Disk Usage** | > 75% | > 85% |
| **Connection Count** | > 80% of max | > 95% of max |
| **Query Response Time** | > 1 second | > 5 seconds |
| **Slow Queries** | > 10/hour | > 50/hour |

#### Query Performance

```sql
-- Enable slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;

-- Find slow queries
SELECT 
    query_time,
    lock_time,
    rows_sent,
    rows_examined,
    sql_text
FROM mysql.slow_log
WHERE start_time >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
ORDER BY query_time DESC
LIMIT 10;
```

#### Connection Monitoring

```sql
-- Check current connections
SHOW PROCESSLIST;

-- Connection statistics
SHOW STATUS LIKE 'Connections';
SHOW STATUS LIKE 'Max_used_connections';
SHOW STATUS LIKE 'Threads_connected';

-- Show variables
SHOW VARIABLES LIKE 'max_connections';
```

## Scaling Operations

### Vertical Scaling (Resources)

Update the database instance resources:

```yaml
# Update the MySQLDatabase resource
apiVersion: platform.io/v1alpha1
kind: MySQLDatabase
metadata:
  name: ${{ values.appName }}
  namespace: ${{ values.namespace }}
spec:
  parameters:
    resources:
      requests:
        memory: "2Gi"
        cpu: "1000m"
      limits:
        memory: "4Gi"
        cpu: "2000m"
```

Apply the changes:

```bash
kubectl apply -f mysql-database.yaml -n ${{ values.namespace }}
```

### Storage Expansion

!!! warning "Storage Expansion"
    Storage expansion requires downtime. Plan maintenance windows accordingly.

```bash
# Check current storage
kubectl get pvc -n ${{ values.namespace }} -l app=mysql

# Update storage size (example: increase to 50Gi)
kubectl patch pvc mysql-data-${{ values.appName }}-0 -n ${{ values.namespace }} -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'

# Monitor the expansion
kubectl get events -n ${{ values.namespace }} --field-selector involvedObject.kind=PersistentVolumeClaim
```

## Troubleshooting

### Common Issues

#### High CPU Usage

```sql
-- Find expensive queries
SELECT 
    DIGEST_TEXT as query,
    COUNT_STAR as exec_count,
    AVG_TIMER_WAIT/1000000000 as avg_exec_time_sec,
    SUM_TIMER_WAIT/1000000000 as total_exec_time_sec
FROM performance_schema.events_statements_summary_by_digest 
ORDER BY SUM_TIMER_WAIT DESC 
LIMIT 10;
```

#### Connection Issues

```bash
# Check database connectivity
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysql -u${{ values.username }} -p -e "SELECT 1;"

# Check service endpoints
kubectl get endpoints mysql -n ${{ values.namespace }}

# Verify network policies
kubectl get networkpolicies -n ${{ values.namespace }}
```

#### Disk Space Issues

```bash
# Check disk usage
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  df -h

# Find large tables
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "
    SELECT 
        table_schema as 'Database',
        table_name as 'Table',
        round(((data_length + index_length) / 1024 / 1024), 2) as 'Size MB'
    FROM information_schema.tables 
    WHERE table_schema = '${{ values.databaseName }}'
    ORDER BY (data_length + index_length) DESC;"
```

### Log Analysis

#### Application Logs

```bash
# View MySQL error logs
kubectl logs -n ${{ values.namespace }} -l app=mysql --tail=100

# Follow logs in real-time
kubectl logs -n ${{ values.namespace }} -l app=mysql -f

# Get logs from specific time
kubectl logs -n ${{ values.namespace }} -l app=mysql --since=1h
```

#### Slow Query Analysis

```bash
# Export slow query log
kubectl exec -n ${{ values.namespace }} \
  $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  cat /var/log/mysql/slow.log > slow-queries-$(date +%Y%m%d).log

# Analyze with mysqldumpslow (if available)
mysqldumpslow -s t -t 10 slow-queries-$(date +%Y%m%d).log
```

## Emergency Procedures

### Database Corruption

1. **Stop all applications** connecting to the database
2. **Take immediate backup** if possible
3. **Run consistency check**:
   ```bash
   kubectl exec -n ${{ values.namespace }} \
     $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
     mysqlcheck -u root -p$MYSQL_ROOT_PASSWORD --all-databases --check
   ```
4. **Repair if needed**:
   ```bash
   kubectl exec -n ${{ values.namespace }} \
     $(kubectl get pods -n ${{ values.namespace }} -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
     mysqlcheck -u root -p$MYSQL_ROOT_PASSWORD --all-databases --repair
   ```

### Security Incident

1. **Immediately rotate passwords**:
   ```bash
   # Generate new password
   NEW_PASSWORD=$(openssl rand -base64 32)
   
   # Update in Vault
   vault kv put secret/${{ values.appName }} DB_PASSWORD="$NEW_PASSWORD"
   ```

2. **Review access logs**:
   ```sql
   -- Check recent connections
   SELECT * FROM mysql.general_log 
   WHERE event_time >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
   ORDER BY event_time DESC;
   ```

3. **Contact security team** via [Slack](${{ values.slackChannel }})

### Disaster Recovery

1. **Assess the situation** and determine recovery point objective
2. **Choose appropriate backup** based on recovery requirements
3. **Follow restore procedures** outlined above
4. **Verify data integrity** after restoration
5. **Update applications** with new connection details if needed

## Monitoring & Alerting

### Key Alerts

The following alerts are configured for your database:

- **Database Down**: MySQL service unavailable
- **High CPU**: CPU usage > 85% for 5 minutes
- **High Memory**: Memory usage > 90% for 5 minutes
- **Disk Full**: Disk usage > 85%
- **Slow Queries**: > 50 slow queries per hour
- **Replication Lag**: > 30 seconds (if applicable)

### Grafana Dashboards

Access your monitoring dashboards:

- [MySQL Overview](${{ values.grafanaUrl }}/d/mysql-overview/mysql-database-overview?var-database=${{ values.databaseName }}&var-namespace=${{ values.namespace }})
- [MySQL Performance](${{ values.grafanaUrl }}/d/mysql-performance/mysql-performance?var-database=${{ values.databaseName }})
- [MySQL Connections](${{ values.grafanaUrl }}/d/mysql-connections/mysql-connections?var-namespace=${{ values.namespace }})

## Getting Help

For operational support:

- **Platform Team**: [Slack Channel](https://slack.com/app_redirect?channel=${{ values.slackChannel }})
- **Emergency**: Page the on-call DBA
- **Documentation**: See [troubleshooting guide](troubleshooting.md)

## Next Steps

- [Performance Tuning →](performance.md)
- [Security Best Practices →](security.md)
- [Troubleshooting Guide →](troubleshooting.md)