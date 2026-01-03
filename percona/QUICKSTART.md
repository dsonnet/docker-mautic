# Percona Slow Query Analysis - Quick Start Guide

## Prerequisites

- Docker and Docker Compose installed
- Existing Mautic environment variables configured

## Step-by-Step Setup

### Step 1: Configure Environment

```bash
cd percona
cp .env.percona .env.percona.local
nano .env.percona.local
```

Set these values (use your existing Mautic credentials):
```bash
MYSQL_ROOT_PASSWORD=your_root_password
MYSQL_DATABASE=mautic
MYSQL_USER=mautic
MYSQL_PASSWORD=your_mautic_password
```

### Step 2: Build and Start Percona Database

```bash
# Build the custom image
docker-compose -f docker-compose.percona.yml build

# Start the database
docker-compose -f docker-compose.percona.yml up -d

# Check it's running
docker-compose -f docker-compose.percona.yml ps
docker logs percona-db
```

Expected output: You should see MySQL starting and cron jobs being configured.

### Step 3: Verify Network Creation

```bash
docker network ls | grep mautic-db-network
```

You should see the `mautic-db-network` network listed.

### Step 4: Update Main Mautic Stack

The main [`docker-compose.yml`](../docker-compose.yml:1) has already been updated to use the external database.

**Before starting Mautic**, ensure you update your environment variables:

```bash
cd ..
nano .mautic_env
```

Make sure these are set correctly:
```bash
MYSQL_HOST=percona-db
MYSQL_PORT=3306
```

### Step 5: Start Mautic Services

```bash
cd ..
docker-compose down  # Stop existing services if running
docker-compose up -d
```

### Step 6: Verify Everything Works

```bash
# Check all services are running
docker-compose ps

# Test database connection from Mautic
docker exec mautic_web nc -zv percona-db 3306

# Check if Mautic web is accessible
curl -I http://localhost
```

### Step 7: Verify Analysis Scripts

```bash
# Run manual analysis to test
docker exec percona-db /opt/analysis/analyze-slow-queries.sh

# Check the report was created
docker exec percona-db ls -la /var/log/mysql/analysis/

# View the report
docker exec percona-db cat /var/log/mysql/analysis/slow-query-report-*.txt
```

## Daily Usage

### View Analysis Reports

```bash
cd percona
docker exec percona-db ls -lht /var/log/mysql/analysis/
```

### Run Manual Analysis

```bash
# Slow query analysis
docker exec percona-db /opt/analysis/analyze-slow-queries.sh

# Index analysis
docker exec percona-db /opt/analysis/analyze-indexes.sh

# Improvement suggestions
docker exec percona-db /opt/analysis/suggest-improvements.sh
```

### Access MySQL CLI

```bash
docker exec -it percona-db mysql -u root -p
# Enter password from .env.percona.local
```

### View Slow Query Log Live

```bash
docker exec percona-db tail -f /var/log/mysql/mysql-slow.log
```

## Troubleshooting

### Issue: Mautic can't connect to database

**Solution 1**: Check network
```bash
docker network inspect mautic-db-network
```

**Solution 2**: Verify database is running
```bash
docker logs percona-db
```

**Solution 3**: Check credentials in `.mautic_env`
```bash
cat ../.mautic_env | grep MYSQL
```

### Issue: No slow queries logged

**Solution**: The threshold is 1 second. Either:
1. Wait for slow queries to occur naturally
2. Lower the threshold in [`docker-compose.percona.yml`](docker-compose.percona.yml:22)
3. Run a slow query manually:
```bash
docker exec percona-db mysql -u root -p -e "SELECT SLEEP(2);"
```

### Issue: Analysis reports empty

This is normal if:
- Database is new (no queries yet)
- No queries exceed the slow query threshold
- Less than 24 hours since startup

Generate some queries by using Mautic, then check again.

## Next Steps

1. ✅ Database is running with analysis enabled
2. ✅ Automated reports will be generated daily/weekly
3. 📊 Review reports in `logs/analysis/` directory
4. 🔧 Implement suggested optimizations
5. 📈 Monitor performance improvements

See [`README.md`](README.md:1) for complete documentation.
