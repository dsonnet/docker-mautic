# Simple Deployment (No Build Required)

## Problem

The custom Dockerfile build is failing in Portainer due to package dependency issues with Percona Toolkit on Oracle Linux.

## Solution

Use **pre-built images** instead of building a custom image. This approach:
- ✅ No build required - deploys instantly
- ✅ Uses official Percona images
- ✅ Separates database and analysis concerns
- ✅ Runs in Portainer without issues

## Architecture

```
┌─────────────────────────┐
│   Percona Server        │  Official image
│   percona-db            │  (no build needed)
└─────────────────────────┘
           │
           │ shared logs volume
           ├──────────────┐
           │              │
┌──────────┴──────┐  ┌────┴─────────────┐
│ Slow Query Log  │  │ Percona Toolkit  │ Official image
│ mysql-slow.log  │  │ (sidecar)        │ (no build needed)
└─────────────────┘  └──────────────────┘
```

## Deployment in Portainer

### Step 1: Create Network
- **Portainer → Networks → Add network**
- Name: `mautic-db-network`
- Driver: bridge
- Click **Create**

### Step 2: Deploy Percona Stack (Simple Version)
- **Portainer → Stacks → Add stack**
- Name: `percona-db`
- Build method: **Repository** or **Web editor**
- If Repository:
  - URL: Your Git repo
  - Compose path: `percona/docker-compose.percona-simple.yml`  ← Use this file
- If Web editor: Copy content from below

**Environment variables:**
```
MYSQL_ROOT_PASSWORD=your_password
MYSQL_DATABASE=mautic
MYSQL_USER=mautic
MYSQL_PASSWORD=your_password
NETWORK_NAME=mautic-db-network
```

Click **Deploy the stack**

### Compose File Content

If using web editor, paste this:

```yaml
version: '3.8'

services:
  percona-db:
    image: percona/percona-server:8.0.44
    container_name: percona-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
      - ./logs:/var/log/mysql
    ports:
      - "3306:3306"
    command:
      - --slow_query_log=1
      - --slow_query_log_file=/var/log/mysql/mysql-slow.log
      - --long_query_time=1
      - --log_queries_not_using_indexes=1
      - --log_slow_admin_statements=1
      - --sql-mode=STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
      - --max_connections=200
      - --innodb_buffer_pool_size=1G
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - mautic-db-network

  percona-toolkit:
    image: perconalab/percona-toolkit:latest
    container_name: percona-toolkit
    volumes:
      - ./logs:/var/log/mysql:ro
      - ./reports:/reports
    command: tail -f /dev/null
    networks:
      - mautic-db-network
    depends_on:
      - percona-db

volumes:
  mysql-data:

networks:
  mautic-db-network:
    name: ${NETWORK_NAME:-mautic-db-network}
    driver: bridge
```

### Step 3: Verify Deployment
- **Portainer → Stacks → percona-db**
- Status should be **Active**
- Two containers running:
  - `percona-db` (database)
  - `percona-toolkit` (analysis tool)

### Step 4: Deploy Mautic Stack
Follow previous instructions - use the updated `docker-compose.yml` without `external_links`.

## Running Analysis

### Manual Analysis

**Via Portainer Console:**

1. **Access Toolkit Container**
   - Portainer → Containers → percona-toolkit → Console → Connect

2. **Run Analysis**
   ```bash
   # Slow query digest
   pt-query-digest /var/log/mysql/mysql-slow.log > /reports/slow-query-report-$(date +%Y%m%d).txt
   
   # View top 10 queries
   pt-query-digest --limit 10 /var/log/mysql/mysql-slow.log
   
   # Check for duplicate indexes (from toolkit container)
   pt-duplicate-key-checker -h percona-db -u root -p
   ```

3. **View Reports**
   ```bash
   ls -la /reports/
   cat /reports/slow-query-report-*.txt
   ```

### Download Reports

Reports are saved to `percona/reports/` directory on the host, which you can access via:
- FTP/SFTP to your server
- Docker volume browser in Portainer (if available)
- SSH and copy files

## Automated Analysis (Optional)

If you want automated daily/weekly reports, you can add a cron container to the stack:

```yaml
  cron:
    image: alpine:latest
    container_name: percona-cron
    volumes:
      - ./logs:/var/log/mysql:ro
      - ./reports:/reports
      - ./scripts:/scripts:ro
    entrypoint: /bin/sh
    command:
      - -c
      - |
        apk add --no-cache dcron perl
        echo "0 2 * * * pt-query-digest /var/log/mysql/mysql-slow.log > /reports/daily-$(date +\%Y\%m\%d).txt" | crontab -
        crond -f
    networks:
      - mautic-db-network
    depends_on:
      - percona-toolkit
```

## Benefits of This Approach

✅ **No Build** - Uses official images only  
✅ **Fast Deployment** - Instant, no compilation  
✅ **Reliable** - No package dependency issues  
✅ **Flexible** - Run analysis on-demand  
✅ **Portainer-Friendly** - Works perfectly in Portainer  
✅ **Easy Updates** - Just pull new images  

## Comparison

| Feature | Custom Build | Simple (No Build) |
|---------|-------------|-------------------|
| Deployment time | 5-10 minutes | Instant |
| Build errors | Possible | None |
| Automated analysis | Built-in cron | Manual or add cron container |
| Portainer compatibility | Complex | Perfect |
| Maintenance | Rebuild on updates | Pull new images |
| Reliability | Depends on packages | Very reliable |

## Recommended Workflow

1. **Deploy simple stack** (no build)
2. **Get familiar** with analysis tools
3. **Run manual** analysis when needed
4. **Later**: Add cron container if you want automation

This is the **recommended approach for Portainer** - simple, reliable, and effective.

## Migrating from Custom Build

If you already tried the custom build approach:

1. Delete the failing stack in Portainer
2. Deploy with `docker-compose.percona-simple.yml` instead
3. Everything else remains the same
4. Run analysis manually from toolkit container

## Next Steps

1. ✅ Deploy simple stack (no build)
2. ✅ Verify both containers running
3. ✅ Deploy/update Mautic stack
4. ✅ Run manual analysis to test
5. ✅ Review reports
6. (Optional) Add automated cron later
