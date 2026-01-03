# Deployment and Migration Guide

This guide explains how to migrate from your existing Mautic setup to the new separated Percona database stack with slow query analysis.

## Migration Strategy

There are two approaches to deploying this setup:

### Option A: New Installation (Recommended for Testing)

Deploy to a new environment first to test everything works correctly.

### Option B: In-Place Migration (Production)

Migrate your existing production setup with minimal downtime.

---

## Option A: New Installation

Perfect for testing or new deployments.

### Steps

1. **Clone/Copy the percona directory** to your project
2. **Configure environment** in `percona/.env.percona`
3. **Build and start** Percona stack
4. **Start** Mautic stack
5. **Verify** everything works

Follow the [`QUICKSTART.md`](QUICKSTART.md:1) guide.

---

## Option B: In-Place Migration

⚠️ **Important**: This involves downtime. Plan accordingly.

### Prerequisites

- [ ] Backup your database
- [ ] Backup your environment files
- [ ] Test in staging environment first
- [ ] Schedule maintenance window

### Migration Steps

#### Step 1: Backup Current Database

```bash
# Create backup directory
mkdir -p ~/backups/$(date +%Y%m%d)

# Backup database
docker exec <current-db-container> mysqldump \
  -u root -p${MYSQL_ROOT_PASSWORD} \
  --all-databases \
  --single-transaction \
  --quick \
  --lock-tables=false \
  > ~/backups/$(date +%Y%m%d)/mautic_full_backup.sql

# Verify backup
ls -lh ~/backups/$(date +%Y%m%d)/
```

#### Step 2: Stop Current Services

```bash
cd /home/dsonnet/repos/php/docker-mautic
docker-compose down
```

**Note**: Your database data remains in the `mysql-data` volume.

#### Step 3: Copy Database Volume Data (Optional but Recommended)

If you want to preserve your existing data with the new Percona setup:

```bash
# Export data from old volume
docker run --rm \
  -v docker-mautic_mysql-data:/source:ro \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/mysql-data.tar.gz -C /source .
```

#### Step 4: Configure Percona Environment

```bash
cd percona

# Copy existing credentials to new env file
cat > .env.percona << EOF
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_HOST=percona-db
MYSQL_PORT=3306
COMPOSE_PROJECT_NAME=mautic
NETWORK_NAME=mautic-db-network
EOF
```

#### Step 5: Build and Start Percona Stack

```bash
# Build the image
docker-compose -f docker-compose.percona.yml build

# Start database only (without -d to see logs)
docker-compose -f docker-compose.percona.yml up
```

Watch for:
- ✅ MySQL starting successfully
- ✅ Cron service starting
- ✅ Cron jobs being configured
- ✅ No error messages

Press `Ctrl+C` and restart in detached mode:

```bash
docker-compose -f docker-compose.percona.yml up -d
```

#### Step 6: Restore Database (if starting fresh)

If you need to restore from backup:

```bash
docker exec -i percona-db mysql -u root -p${MYSQL_ROOT_PASSWORD} < ~/backups/YYYYMMDD/mautic_full_backup.sql
```

Or import existing volume data:

```bash
# Stop the database
docker-compose -f docker-compose.percona.yml down

# Import data to new volume
docker run --rm \
  -v docker-mautic_mysql-data:/source:ro \
  -v percona_mysql-data:/dest \
  alpine sh -c "cd /source && tar cf - . | (cd /dest && tar xf -)"

# Restart database
docker-compose -f docker-compose.percona.yml up -d
```

#### Step 7: Update Mautic Environment Variables

```bash
cd ..

# Update .mautic_env if needed
nano .mautic_env
```

Ensure these values are set:
```bash
MAUTIC_DB_HOST=percona-db
MAUTIC_DB_PORT=3306
```

#### Step 8: Start Mautic Services

```bash
docker-compose up -d
```

#### Step 9: Verify Everything Works

```bash
# Check all services are running
docker-compose ps

# Check database connection
docker exec mautic_web nc -zv percona-db 3306

# Check Mautic is accessible
curl -I http://localhost

# Check database tables
docker exec percona-db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "USE mautic; SHOW TABLES;"

# Test slow query logging
docker exec percona-db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT SLEEP(2);"
docker exec percona-db cat /var/log/mysql/mysql-slow.log
```

#### Step 10: Test Analysis Scripts

```bash
# Run manual analysis
docker exec percona-db /opt/analysis/analyze-slow-queries.sh

# Verify report was created
docker exec percona-db ls -la /var/log/mysql/analysis/

# View the report
docker exec percona-db cat /var/log/mysql/analysis/slow-query-report-*.txt
```

---

## Rollback Plan

If something goes wrong, you can rollback:

### Quick Rollback

```bash
# Stop new setup
cd percona
docker-compose -f docker-compose.percona.yml down
cd ..
docker-compose down

# Restore original docker-compose.yml from git
git checkout docker-compose.yml

# Start original setup
docker-compose up -d
```

### Full Rollback with Data Restore

```bash
# Stop everything
docker-compose down
cd percona
docker-compose -f docker-compose.percona.yml down -v
cd ..

# Restore docker-compose.yml
git checkout docker-compose.yml

# Restore database from backup
docker-compose up -d db
sleep 10
docker exec -i <db-container> mysql -u root -p${MYSQL_ROOT_PASSWORD} < ~/backups/YYYYMMDD/mautic_full_backup.sql

# Start remaining services
docker-compose up -d
```

---

## Post-Migration Checklist

After successful migration:

- [ ] All Mautic services are running
- [ ] Mautic web interface is accessible
- [ ] Database contains all data
- [ ] Cron jobs are running
- [ ] Analysis scripts execute successfully
- [ ] Slow query log is being populated
- [ ] Network connectivity is working
- [ ] No error messages in logs

### Verification Commands

```bash
# Service status
docker-compose ps
cd percona && docker-compose -f docker-compose.percona.yml ps

# Logs check
docker logs percona-db | tail -50
docker logs mautic_web | tail -50

# Database connectivity
docker exec mautic_web php -r "new PDO('mysql:host=percona-db;dbname=mautic', 'mautic', '${MYSQL_PASSWORD}');" && echo "Connection OK"

# Cron status
docker exec percona-db service cron status
docker exec percona-db cat /var/log/mysql/analysis/cron.log
```

---

## Monitoring After Migration

### First 24 Hours

- Monitor application logs for database connection issues
- Check slow query log is being populated
- Verify cron jobs run at scheduled times
- Monitor disk space for log growth

### First Week

- Review first daily slow query report
- Check first weekly index analysis (Sunday)
- Verify reports are being generated correctly
- Assess if `long_query_time` threshold needs adjustment

### Commands

```bash
# Watch slow query log
docker exec percona-db tail -f /var/log/mysql/mysql-slow.log

# Monitor cron execution
docker exec percona-db tail -f /var/log/mysql/analysis/cron.log

# Check disk usage
docker exec percona-db df -h /var/log/mysql
docker exec percona-db du -sh /var/log/mysql/*
```

---

## Troubleshooting Common Migration Issues

### Issue: Services can't find database

**Symptom**: `Connection refused` or `Unknown MySQL server host 'percona-db'`

**Solution**:
```bash
# Verify network exists
docker network ls | grep mautic-db-network

# Recreate network if needed
docker network create mautic-db-network

# Restart services
docker-compose restart
```

### Issue: Database container won't start

**Symptom**: Container exits immediately

**Solution**:
```bash
# Check logs
docker logs percona-db

# Common causes:
# 1. Port 3306 already in use
sudo netstat -tulpn | grep 3306

# 2. Permission issues with volumes
docker volume inspect percona_mysql-data

# 3. Corrupted data - restore from backup
```

### Issue: Old database data not accessible

**Symptom**: Empty database after migration

**Solution**:
```bash
# Check if volume was properly created
docker volume ls | grep mysql-data

# Verify volume data
docker run --rm -v percona_mysql-data:/data alpine ls -la /data

# Restore from backup if needed
docker exec -i percona-db mysql -u root -p${MYSQL_ROOT_PASSWORD} < backup.sql
```

---

## Performance Tuning Post-Migration

### Analyze First Week's Reports

1. Review slow query patterns
2. Identify most expensive queries
3. Check for missing indexes
4. Look for duplicate indexes

### Adjust Configuration

Based on analysis, consider adjusting:

```yaml
# In docker-compose.percona.yml
command:
  - --long_query_time=0.5          # Lower threshold for more queries
  - --innodb_buffer_pool_size=2G   # Increase for more RAM
  - --max_connections=300          # Increase for more connections
```

### Implement Optimizations

1. Add recommended indexes
2. Optimize identified slow queries
3. Remove duplicate indexes
4. Update application code as needed

---

## Support and Documentation

- **Main Documentation**: [`README.md`](README.md:1)
- **Quick Start**: [`QUICKSTART.md`](QUICKSTART.md:1)
- **Implementation Plan**: [`../plans/percona-analysis-implementation-plan.md`](../plans/percona-analysis-implementation-plan.md:1)

For issues, check the Troubleshooting section in [`README.md`](README.md:1).
