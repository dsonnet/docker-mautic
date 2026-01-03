# Percona Server with Slow Query Analysis

This directory contains a separate Docker setup for Percona Server 8.0.44 with integrated Percona Toolkit for automated slow query analysis.

## Features

- **Percona Server 8.0.44** with optimized MySQL configuration
- **Percona Toolkit** for comprehensive query analysis
- **Automated Analysis**:
  - Daily slow query reports (2 AM UTC / 3 AM CET)
  - Weekly index analysis (Sunday 3 AM UTC / 4 AM CET)
  - Weekly improvement suggestions (Sunday 4 AM UTC / 5 AM CET)
- **Persistent Logs** for historical analysis
- **Shared Network** with main Mautic application stack

## Directory Structure

```
percona/
├── Dockerfile.percona              # Custom Percona image with toolkit
├── docker-compose.percona.yml      # Database service configuration
├── docker-entrypoint-wrapper.sh    # Custom entrypoint for cron setup
├── .env.percona                    # Environment variables
├── README.md                       # This file
├── scripts/                        # Analysis scripts
│   ├── analyze-slow-queries.sh     # Daily slow query analysis
│   ├── analyze-indexes.sh          # Weekly index analysis
│   ├── suggest-improvements.sh     # Weekly improvement suggestions
│   └── setup-cron.sh              # Cron job configuration
└── logs/                          # Persistent log storage (created on start)
    ├── mysql-slow.log             # Current slow query log
    ├── mysql-slow.log.YYYYMMDD_*  # Rotated slow query logs
    └── analysis/                  # Analysis reports
        ├── slow-query-report-*.txt
        ├── index-analysis-*.txt
        ├── improvements-*.txt
        └── cron.log
```

## Quick Start

### 1. Configure Environment Variables

Edit `.env.percona` and set your database credentials:

```bash
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_DATABASE=mautic
MYSQL_USER=mautic
MYSQL_PASSWORD=your_secure_password
```

⚠️ **Important**: Use the same credentials as your existing Mautic setup!

### 2. Start the Percona Database

```bash
cd percona
docker-compose -f docker-compose.percona.yml up -d
```

This will:
- Build the custom Percona image with Percona Toolkit
- Start the database container
- Create the shared network `mautic-db-network`
- Set up automated analysis cron jobs

### 3. Verify Database is Running

```bash
docker-compose -f docker-compose.percona.yml ps
docker logs percona-db
```

### 4. Start the Main Mautic Stack

```bash
cd ..
docker-compose up -d
```

The Mautic services will connect to the Percona database via the shared network.

## Analysis Reports

### Viewing Reports

Reports are saved in `logs/analysis/`:

```bash
# List all reports
ls -lht logs/analysis/

# View latest slow query report
cat logs/analysis/slow-query-report-*.txt | head -100

# View latest index analysis
cat logs/analysis/index-analysis-*.txt

# View improvement suggestions
cat logs/analysis/improvements-*.txt

# View cron execution log
tail -f logs/analysis/cron.log
```

### Report Types

1. **Slow Query Report** (`slow-query-report-YYYYMMDD_HHMMSS.txt`)
   - Top 20 queries by total execution time
   - Query fingerprints and execution statistics
   - Generated daily at 2 AM UTC
   - Retained for 7 days

2. **Index Analysis** (`index-analysis-YYYYMMDD_HHMMSS.txt`)
   - Duplicate and redundant indexes
   - Index usage statistics
   - Table size information
   - Generated weekly on Sundays at 3 AM UTC
   - Retained for 30 days

3. **Improvement Suggestions** (`improvements-YYYYMMDD_HHMMSS.txt`)
   - Top queries by different metrics
   - Queries not using indexes
   - Actionable optimization recommendations
   - Generated weekly on Sundays at 4 AM UTC
   - Retained for 30 days

## Manual Analysis

### Access the Container

```bash
docker exec -it percona-db bash
```

### Run Manual Analysis

```bash
# Immediate slow query analysis
/opt/analysis/analyze-slow-queries.sh

# Immediate index analysis
/opt/analysis/analyze-indexes.sh

# Immediate improvement suggestions
/opt/analysis/suggest-improvements.sh
```

### Using Percona Toolkit Directly

```bash
# Access container
docker exec -it percona-db bash

# Analyze slow query log
pt-query-digest /var/log/mysql/mysql-slow.log

# Get top 10 queries by execution time
pt-query-digest --limit 10 --order-by Query_time:sum /var/log/mysql/mysql-slow.log

# Get queries not using indexes
pt-query-digest --filter '($event->{No_index_used} eq "Yes")' /var/log/mysql/mysql-slow.log

# Check for duplicate indexes
pt-duplicate-key-checker -h localhost -u root -p

# Analyze specific query with EXPLAIN
mysql -u root -p
mysql> USE mautic;
mysql> EXPLAIN SELECT ...;
```

### Other Useful Percona Toolkit Commands

```bash
# Check table statistics
pt-mysql-summary -- -h localhost -u root -p

# Find unused indexes
pt-index-usage /var/log/mysql/mysql-slow.log.*

# Analyze query response time
pt-query-digest --group-by fingerprint /var/log/mysql/mysql-slow.log

# Visual explain for complex queries
pt-visual-explain -h localhost -u root -p -D mautic -e "SELECT ..."
```

## Configuration

### Slow Query Settings

Current configuration in [`docker-compose.percona.yml`](docker-compose.percona.yml:20):

- `slow_query_log=1` - Enable slow query logging
- `slow_query_log_file=/var/log/mysql/mysql-slow.log` - Log file location
- `long_query_time=1` - Queries slower than 1 second are logged
- `log_queries_not_using_indexes=1` - Log queries without indexes
- `log_slow_admin_statements=1` - Log slow admin commands

To adjust the threshold, modify the `long_query_time` value in [`docker-compose.percona.yml`](docker-compose.percona.yml:22).

### Cron Schedule

Current schedule (all times in UTC):

- **Daily Analysis**: 2:00 AM UTC (3:00 AM CET)
- **Weekly Index Check**: Sunday 3:00 AM UTC (4:00 AM CET)
- **Weekly Improvements**: Sunday 4:00 AM UTC (5:00 AM CET)

To modify, edit [`scripts/setup-cron.sh`](scripts/setup-cron.sh:1) and rebuild the container.

### Memory Settings

Current buffer pool size: **1GB**

Adjust in [`docker-compose.percona.yml`](docker-compose.percona.yml:28) based on available RAM:

```yaml
- --innodb_buffer_pool_size=2G  # For systems with 4GB+ RAM
```

## Maintenance

### Viewing Logs

```bash
# Database logs
docker logs percona-db

# Follow database logs
docker logs -f percona-db

# Slow query log
docker exec percona-db tail -f /var/log/mysql/mysql-slow.log

# Cron execution log
docker exec percona-db tail -f /var/log/mysql/analysis/cron.log
```

### Backup Database

```bash
# Backup to local file
docker exec percona-db mysqldump -u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DATABASE} > backup_$(date +%Y%m%d).sql

# Backup with compression
docker exec percona-db mysqldump -u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DATABASE} | gzip > backup_$(date +%Y%m%d).sql.gz
```

### Restore Database

```bash
# Restore from backup
docker exec -i percona-db mysql -u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DATABASE} < backup.sql
```

### Clean Old Logs

Old logs are automatically cleaned:
- Slow query reports: 7 days
- Index analysis: 30 days
- Improvement reports: 30 days
- Rotated slow logs: 7 days

Manual cleanup:

```bash
docker exec percona-db find /var/log/mysql/analysis -name "*.txt" -mtime +7 -delete
```

## Troubleshooting

### Database Won't Start

```bash
# Check logs
docker logs percona-db

# Check if port is already in use
netstat -tulpn | grep 3306

# Verify environment variables
docker exec percona-db env | grep MYSQL
```

### Mautic Can't Connect to Database

```bash
# Verify network exists
docker network ls | grep mautic-db-network

# Check if container is on network
docker network inspect mautic-db-network

# Test connection from Mautic container
docker exec mautic_web ping percona-db
docker exec mautic_web nc -zv percona-db 3306
```

### Cron Jobs Not Running

```bash
# Check if cron is running
docker exec percona-db service cron status

# Verify cron configuration
docker exec percona-db cat /etc/cron.d/mysql-analysis

# Check cron logs
docker exec percona-db cat /var/log/mysql/analysis/cron.log

# Manually trigger analysis
docker exec percona-db /opt/analysis/analyze-slow-queries.sh
```

### No Slow Queries Logged

```bash
# Verify slow query log is enabled
docker exec percona-db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW VARIABLES LIKE 'slow_query%';"

# Check current threshold
docker exec percona-db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW VARIABLES LIKE 'long_query_time';"

# View current slow queries (if any)
docker exec percona-db cat /var/log/mysql/mysql-slow.log
```

### Analysis Scripts Fail

```bash
# Test script manually
docker exec percona-db bash -x /opt/analysis/analyze-slow-queries.sh

# Check Percona Toolkit is installed
docker exec percona-db which pt-query-digest

# Verify permissions
docker exec percona-db ls -la /opt/analysis/
```

## Stopping and Removing

### Stop Database (keep data)

```bash
cd percona
docker-compose -f docker-compose.percona.yml stop
```

### Stop and Remove (keep data)

```bash
cd percona
docker-compose -f docker-compose.percona.yml down
```

### Remove Everything (including data)

⚠️ **Warning**: This will delete all database data!

```bash
cd percona
docker-compose -f docker-compose.percona.yml down -v
```

## Performance Optimization Workflow

1. **Monitor Reports**: Review weekly improvement suggestions
2. **Identify Issues**: Focus on queries with high execution time or rows examined
3. **Analyze Queries**: Use `EXPLAIN` to understand query execution plans
4. **Add Indexes**: Create indexes for frequently filtered/joined columns
5. **Test Changes**: Verify improvements in staging environment
6. **Deploy**: Apply optimizations to production
7. **Validate**: Compare next week's reports to measure impact

## Security Notes

- Change default passwords in `.env.percona`
- Restrict port `3306` access via firewall if exposed
- Keep Percona Server and Toolkit updated
- Review analysis reports for sensitive data exposure
- Secure log files with appropriate permissions

## Support

For issues related to:
- **Percona Server**: https://www.percona.com/doc/percona-server/8.0/
- **Percona Toolkit**: https://www.percona.com/doc/percona-toolkit/
- **Docker Compose**: https://docs.docker.com/compose/

## Version Information

- **Percona Server**: 8.0.44
- **Percona Toolkit**: Latest from Percona repository
- **Docker Compose**: 3.8
