# Portainer Deployment Guide

This guide explains how to deploy the Percona slow query analysis setup using Portainer.

## Overview

You'll deploy **two separate stacks** in Portainer:
1. **Percona Stack** - Database with analysis tools
2. **Mautic Stack** - Your existing application (updated to connect to Percona)

Both stacks communicate via a shared Docker network.

## Prerequisites

- Portainer installed and accessible
- Git repository access to this project
- Existing Mautic stack credentials

## Deployment Steps

### Step 1: Create Shared Network in Portainer

1. **Navigate to Networks**
   - Portainer → Networks → Add network

2. **Create Network**
   - **Name:** `mautic-db-network`
   - **Driver:** bridge
   - **IPV4 Network configuration:** (optional)
     - Subnet: `172.20.0.0/16`
     - Gateway: `172.20.0.1`
   - Click **Create the network**

### Step 2: Deploy Percona Stack

#### Option A: Via Git Repository (Recommended)

1. **Navigate to Stacks**
   - Portainer → Stacks → Add stack

2. **Configure Stack**
   - **Name:** `percona-db` (or your preferred name)
   - **Build method:** Repository
   - **Repository URL:** Your git repository URL
   - **Repository reference:** main (or your branch)
   - **Compose path:** `percona/docker-compose.percona.yml`
   - **Authentication:** Configure if private repo

3. **Environment Variables**
   
   Click **Add environment variable** for each:
   
   ```
   MYSQL_ROOT_PASSWORD = your_secure_root_password
   MYSQL_DATABASE = mautic
   MYSQL_USER = mautic
   MYSQL_PASSWORD = your_secure_password
   MYSQL_HOST = percona-db
   MYSQL_PORT = 3306
   COMPOSE_PROJECT_NAME = mautic
   NETWORK_NAME = mautic-db-network
   ```
   
   **Important:** Use the same credentials as your existing Mautic stack!

4. **Deploy Stack**
   - Click **Deploy the stack**
   - Wait for Portainer to build and start the container

#### Option B: Via Web Editor

1. **Navigate to Stacks**
   - Portainer → Stacks → Add stack

2. **Configure Stack**
   - **Name:** `percona-db`
   - **Build method:** Web editor

3. **Paste Compose File**
   
   Copy content from [`docker-compose.percona.yml`](docker-compose.percona.yml:1) into the editor

4. **Set Environment Variables**
   
   Same as Option A above

5. **Deploy Stack**

#### Option C: Via Upload

1. **Prepare Files Locally**
   ```bash
   cd percona
   tar czf percona-stack.tar.gz \
     docker-compose.percona.yml \
     Dockerfile.percona \
     docker-entrypoint-wrapper.sh \
     scripts/
   ```

2. **Upload in Portainer**
   - Portainer → Stacks → Add stack
   - **Name:** `percona-db`
   - **Build method:** Upload
   - Upload `percona-stack.tar.gz`
   - Set environment variables
   - Deploy

### Step 3: Verify Percona Stack

1. **Check Stack Status**
   - Portainer → Stacks → percona-db
   - Status should be "Active"
   - All services should be green/running

2. **View Container Logs**
   - Portainer → Containers → percona-db
   - Click **Logs**
   - Look for:
     - ✅ MySQL initialization completed
     - ✅ Cron service started
     - ✅ Cron jobs configured

3. **Test Database Connection**
   - Portainer → Containers → percona-db → Console
   - Click **Connect**
   - Run:
     ```bash
     mysql -u root -p
     # Enter your MYSQL_ROOT_PASSWORD
     SHOW DATABASES;
     EXIT;
     ```

### Step 4: Update Mautic Stack

Your existing Mautic stack needs to be updated to use the external Percona database.

#### Option A: Update Existing Stack

1. **Navigate to Your Mautic Stack**
   - Portainer → Stacks → [your-mautic-stack]

2. **Click Editor**
   - Replace content with updated [`docker-compose.yml`](../docker-compose.yml:1)

3. **Update Environment Variables**
   
   Ensure these are set (or in your .mautic_env file):
   ```
   MYSQL_HOST = percona-db
   MYSQL_PORT = 3306
   MYSQL_DATABASE = mautic
   MYSQL_USER = mautic
   MYSQL_PASSWORD = your_secure_password
   ```

4. **Update Stack**
   - Click **Update the stack**
   - Enable: **Re-pull image and redeploy**
   - Click **Update**

#### Option B: Redeploy Stack

1. **Stop Existing Stack**
   - Portainer → Stacks → [your-mautic-stack]
   - Click **Stop this stack**

2. **Delete Stack** (optional, keeps volumes)
   - Click **Delete this stack**
   - ⚠️ Ensure you keep volumes!

3. **Create New Stack**
   - Follow same process as Percona
   - Use updated [`docker-compose.yml`](../docker-compose.yml:1)
   - Set environment variables
   - Deploy

### Step 5: Verify Integration

1. **Check Network Connectivity**
   
   From Mautic container:
   - Portainer → Containers → mautic_web → Console
   - Click **Connect**
   - Run:
     ```bash
     ping percona-db
     nc -zv percona-db 3306
     ```

2. **Check Mautic Web Interface**
   - Access your Mautic URL
   - Verify it loads correctly
   - Check database connectivity

3. **Verify Both Stacks Running**
   - Portainer → Stacks
   - Both `percona-db` and `mautic` should be Active

## Managing Analysis Reports in Portainer

### View Analysis Reports

1. **Access Percona Container Console**
   - Portainer → Containers → percona-db
   - Click **Console** → **Connect**

2. **List Reports**
   ```bash
   ls -lht /var/log/mysql/analysis/
   ```

3. **View Report**
   ```bash
   cat /var/log/mysql/analysis/slow-query-report-*.txt | less
   ```

### Download Reports

#### Method 1: Using Container Console

```bash
# In Portainer console
cat /var/log/mysql/analysis/slow-query-report-*.txt
# Copy output from browser
```

#### Method 2: Using Volume Browser (if available)

1. Portainer → Volumes → percona_mysql-data (if logs are in volume)
2. Browse to `analysis/` folder
3. Download files

#### Method 3: Via Docker Exec Locally

```bash
# On the Portainer host machine
docker cp percona-db:/var/log/mysql/analysis/ ./reports/
```

### Run Manual Analysis

1. **Access Console**
   - Portainer → Containers → percona-db → Console → Connect

2. **Run Scripts**
   ```bash
   # Slow query analysis
   /opt/analysis/analyze-slow-queries.sh
   
   # Index analysis
   /opt/analysis/analyze-indexes.sh
   
   # Improvement suggestions
   /opt/analysis/suggest-improvements.sh
   ```

3. **View Results**
   ```bash
   ls -la /var/log/mysql/analysis/
   cat /var/log/mysql/analysis/slow-query-report-*.txt
   ```

## Monitoring in Portainer

### View Container Stats

1. **Navigate to Container**
   - Portainer → Containers → percona-db

2. **Stats Tab**
   - CPU usage
   - Memory usage
   - Network I/O
   - Block I/O

### View Logs

1. **Navigate to Container**
   - Portainer → Containers → percona-db

2. **Logs Tab**
   - View real-time logs
   - Search logs
   - Download logs

### Check Cron Jobs

1. **Access Console**
   - Portainer → Containers → percona-db → Console

2. **Check Cron Status**
   ```bash
   service cron status
   cat /etc/cron.d/mysql-analysis
   tail -f /var/log/mysql/analysis/cron.log
   ```

## Portainer-Specific Configurations

### Stack Environment Variables

You can update environment variables without redeploying:

1. **Navigate to Stack**
   - Portainer → Stacks → percona-db

2. **Click Editor**
   - Modify environment variables section

3. **Update Stack**
   - Click **Update the stack**

### Volume Management

#### Backup Percona Volumes

1. **Navigate to Volumes**
   - Portainer → Volumes

2. **Find Volume**
   - `percona_mysql-data` (database data)

3. **Backup** (via host)
   ```bash
   docker run --rm \
     -v percona_mysql-data:/source:ro \
     -v $(pwd):/backup \
     alpine tar czf /backup/percona-backup-$(date +%Y%m%d).tar.gz -C /source .
   ```

#### View Volume Contents

1. **Portainer → Volumes → percona_mysql-data**
2. Click **Browse** (if available in your Portainer version)

### Container Actions

Via Portainer UI, you can:
- ✅ Start/Stop/Restart containers
- ✅ View logs in real-time
- ✅ Access console
- ✅ Inspect container details
- ✅ View resource usage
- ✅ Duplicate container configuration

## Updating the Setup

### Update Percona Configuration

1. **Edit Stack**
   - Portainer → Stacks → percona-db → Editor

2. **Modify Configuration**
   - Change `long_query_time`, `innodb_buffer_pool_size`, etc.

3. **Update Stack**
   - Click **Update the stack**
   - Enable **Re-pull and redeploy**

### Update Analysis Scripts

If you modify scripts in Git:

1. **Pull Changes**
   - Portainer → Stacks → percona-db → Editor
   - Click **Pull and redeploy**

Or rebuild:

1. **Stop Stack**
2. **Delete Stack** (keep volumes)
3. **Redeploy** with updated repository

## Troubleshooting in Portainer

### Issue: Percona Stack Won't Start

1. **Check Stack Logs**
   - Portainer → Stacks → percona-db → Logs

2. **Check Container Logs**
   - Portainer → Containers → percona-db → Logs

3. **Common Issues**
   - Environment variables not set
   - Network not created
   - Port 3306 conflict

### Issue: Mautic Can't Connect

1. **Verify Network**
   - Portainer → Networks → mautic-db-network
   - Check both stacks are connected

2. **Test from Container**
   - Portainer → Containers → mautic_web → Console
   ```bash
   ping percona-db
   telnet percona-db 3306
   ```

3. **Check Environment Variables**
   - Portainer → Stacks → mautic → Editor
   - Verify `MYSQL_HOST=percona-db`

### Issue: Reports Not Generated

1. **Check Cron**
   - Portainer → Containers → percona-db → Console
   ```bash
   service cron status
   cat /var/log/mysql/analysis/cron.log
   ```

2. **Run Manually**
   ```bash
   /opt/analysis/analyze-slow-queries.sh
   ```

3. **Check Permissions**
   ```bash
   ls -la /opt/analysis/
   ls -la /var/log/mysql/analysis/
   ```

## Best Practices for Portainer

1. **Use Stack Names Consistently**
   - Easier to identify and manage

2. **Set Environment Variables in Portainer**
   - Don't commit credentials to Git
   - Use Portainer's env var feature

3. **Use Git Repository Method**
   - Easy updates via pull
   - Version control

4. **Regular Backups**
   - Backup Percona volumes weekly
   - Export stack configurations

5. **Monitor Resource Usage**
   - Check Stats tab regularly
   - Adjust memory/CPU limits if needed

6. **Label Your Resources**
   - Add labels to stacks/containers
   - Easier filtering and organization

## Portainer UI Locations

Quick reference for common tasks:

| Task | Location |
|------|----------|
| Create network | Portainer → Networks → Add network |
| Add stack | Portainer → Stacks → Add stack |
| View logs | Portainer → Containers → [container] → Logs |
| Access console | Portainer → Containers → [container] → Console |
| View stats | Portainer → Containers → [container] → Stats |
| Edit stack | Portainer → Stacks → [stack] → Editor |
| Update stack | Portainer → Stacks → [stack] → Editor → Update |
| Manage volumes | Portainer → Volumes |
| View networks | Portainer → Networks |

## Summary

The Percona setup works seamlessly with Portainer:

✅ Deploy as separate stacks
✅ Manage via Portainer UI
✅ View logs and stats in real-time
✅ Access console for analysis
✅ Update via Git or web editor
✅ Monitor resource usage
✅ Backup and restore via Portainer

For detailed CLI commands and troubleshooting, see [`README.md`](README.md:1).
