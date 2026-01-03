# Mautic Deployment Troubleshooting Guide

## Issues Fixed

### 1. Environment Variables Issue
**Problem:** The [`.mautic_env`](.mautic_env:1) file referenced undefined variables (`${MYSQL_HOST}`, `${MYSQL_USER}`, etc.)

**Solution:** Updated [`.mautic_env`](.mautic_env:1) with concrete values that work with the external percona-db container.

### 2. External Links Deprecated
**Problem:** The `external_links` directive in [`docker-compose.yml`](docker-compose.yml:1) is deprecated and can cause issues.

**Solution:** Removed `external_links` - containers on the same network can communicate directly using service names.

## Prerequisites for Deployment

Before deploying the stack, verify these prerequisites on your **remote server**:

### 1. External Networks Must Exist
```bash
# Check if networks exist
docker network ls | grep -E 'web|mautic-db-network'

# Create networks if they don't exist
docker network create web
docker network create mautic-db-network
```

### 2. Database Container Must Be Running
```bash
# Verify percona-db is running and on mautic-db-network
docker ps | grep percona-db
docker inspect percona-db | grep -A 10 Networks
```

### 3. Volume Directories Must Exist with Proper Permissions
```bash
# Create volume directories (on remote server)
sudo mkdir -p /portainer/mautic-smartoys-mautic/{config,logs,media/files,media/images}
sudo mkdir -p /portainer/mautic-smartoys-cron

# Set proper permissions (www-data is UID 33 in Apache container)
sudo chown -R 33:33 /portainer/mautic-smartoys-mautic
sudo chown -R 33:33 /portainer/mautic-smartoys-cron
```

### 4. Database Must Be Configured
Connect to percona-db and ensure the database exists:
```bash
docker exec -it percona-db mysql -u root -p

# In MySQL shell:
CREATE DATABASE IF NOT EXISTS mautic CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'mautic'@'%' IDENTIFIED BY 'mautic_password_change_me';
GRANT ALL PRIVILEGES ON mautic.* TO 'mautic'@'%';
FLUSH PRIVILEGES;
EXIT;
```

## Important Configuration Updates Needed

### Update Database Password
Edit [`.mautic_env`](.mautic_env:1) and change the database password:
```bash
MAUTIC_DB_PASSWORD=your_secure_password_here
```

This password must match the one set in the database.

## Deployment Steps

1. **Upload the updated files to your remote server:**
   ```bash
   scp .mautic_env docker-compose.yml user@your-server:/path/to/mautic/
   ```

2. **SSH into your remote server:**
   ```bash
   ssh user@your-server
   cd /path/to/mautic/
   ```

3. **Verify prerequisites (run all commands in Prerequisites section above)**

4. **Deploy the stack:**
   ```bash
   # Using docker-compose
   docker-compose up -d
   
   # Or in Portainer, redeploy the stack with the updated files
   ```

5. **Monitor the deployment:**
   ```bash
   # Watch container status
   docker-compose ps
   
   # View logs in real-time
   docker-compose logs -f mautic_web
   ```

## Common Errors and Solutions

### Error: "network web not found"
```bash
docker network create web
```

### Error: "network mautic-db-network not found"
```bash
docker network create mautic-db-network
```

### Error: "Cannot connect to database"
- Ensure percona-db is running: `docker ps | grep percona`
- Ensure percona-db is on mautic-db-network: `docker inspect percona-db`
- Verify database credentials match in both percona and mautic configurations
- Check if database exists: `docker exec percona-db mysql -u root -p -e "SHOW DATABASES;"`

### Error: "Permission denied" in container logs
```bash
sudo chown -R 33:33 /portainer/mautic-smartoys-mautic
sudo chown -R 33:33 /portainer/mautic-smartoys-cron
```

### Container exits immediately (exit code 1)
Check the logs for specific errors:
```bash
docker-compose logs mautic_web
```

Common causes:
- Missing environment variables (fixed in updated `.mautic_env`)
- Database connection failure
- Volume permission issues
- Missing external networks

## Verification Commands

After deployment, verify everything is working:

```bash
# Check all containers are running
docker-compose ps

# Check mautic_web health
docker inspect mautic-smartoys-mautic_web-1 | grep -A 5 Health

# Test database connectivity from mautic container
docker exec mautic-smartoys-mautic_web-1 php -r "new PDO('mysql:host=percona-db;dbname=mautic', 'mautic', 'mautic_password_change_me');"

# Check Traefik routing
curl -H "Host: newsletter.smartoys.be" http://localhost

# View application logs
docker-compose logs -f mautic_web
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Traefik (web network)                │
│                  newsletter.smartoys.be → HTTPS              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              mautic_web (networks: default, web,             │
│                       mautic-db-network)                     │
│                   Port 80 (internal)                         │
└──────────┬──────────────────────────────────┬───────────────┘
           │                                  │
           │ healthcheck                      │ database
           ▼                                  ▼
┌──────────────────────┐          ┌─────────────────────────┐
│   mautic_cron        │          │  percona-db             │
│   (cron jobs)        │          │  (external container)   │
└──────────────────────┘          │  mautic-db-network      │
           │                      └─────────────────────────┘
           ▼
┌──────────────────────┐
│   mautic_worker      │
│   (queue processor)  │
└──────────────────────┘
           │
           ▼
┌──────────────────────┐
│   rabbitmq           │
│   (message queue)    │
└──────────────────────┘
```

## Next Steps

After successful deployment:

1. Access Mautic at `https://newsletter.smartoys.be`
2. Complete the installation wizard (if fresh install)
3. Configure cron jobs (handled automatically by mautic_cron container)
4. Set up email sending (SMTP configuration)
5. Monitor logs for any errors

## Support

If you encounter issues not covered here:
1. Check container logs: `docker-compose logs <service_name>`
2. Verify network connectivity between containers
3. Review Mautic documentation: https://docs.mautic.org/
