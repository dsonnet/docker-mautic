# Mautic Portainer Deployment Guide

## Quick Fix for Current Issue

The container `mautic-smartoys-mautic_web-1` exited with code 1 due to:
1. **Missing environment variables** - The `.mautic_env` file had undefined variable references
2. **Deprecated external_links** - Removed in favor of direct network communication

## Portainer Deployment Steps

### Step 1: Verify Prerequisites

Before deploying in Portainer, ensure these networks and resources exist:

#### Check Networks
Go to **Networks** in Portainer and verify these exist:
- `web` (for Traefik)
- `mautic-db-network` (for database connectivity)

If missing, create them:
1. Click **Add network**
2. Name: `web` (or `mautic-db-network`)
3. Driver: `bridge`
4. Click **Create network**

#### Check Database Container
1. Go to **Containers** in Portainer
2. Verify `percona-db` is running
3. Click on `percona-db` → **Inspect** → **Network settings**
4. Confirm it's connected to `mautic-db-network`

If not connected, edit the Percona stack to include:
```yaml
networks:
  mautic-db-network:
    external: true
```

### Step 2: Prepare Database

Connect to the database container:
1. In Portainer, go to **Containers** → `percona-db` → **Console**
2. Connect with `>_ /bin/bash`
3. Run:
```bash
mysql -u root -p

# In MySQL prompt:
CREATE DATABASE IF NOT EXISTS mautic CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'mautic'@'%' IDENTIFIED BY 'mautic_password_change_me';
GRANT ALL PRIVILEGES ON mautic.* TO 'mautic'@'%';
FLUSH PRIVILEGES;
EXIT;
```

### Step 3: Create Volume Directories on Host

Since you're using bind mounts, create directories on the Portainer host:

SSH into your server or use Portainer's **Host** → **Browser** feature:

```bash
sudo mkdir -p /portainer/mautic-smartoys-mautic/config
sudo mkdir -p /portainer/mautic-smartoys-mautic/logs
sudo mkdir -p /portainer/mautic-smartoys-mautic/media/files
sudo mkdir -p /portainer/mautic-smartoys-mautic/media/images
sudo mkdir -p /portainer/mautic-smartoys-cron

# Set permissions (www-data is UID 33 in Apache containers)
sudo chown -R 33:33 /portainer/mautic-smartoys-mautic
sudo chown -R 33:33 /portainer/mautic-smartoys-cron
```

### Step 4: Update Stack in Portainer

1. Go to **Stacks** in Portainer
2. Find your `mautic-smartoys` stack (or create a new one)
3. Click **Editor**
4. Paste the updated `docker-compose.yml` content
5. Under **Environment variables**, add or update:
   - Click **Load variables from .env file**
   - Paste the content of the updated `.mautic_env` file

   Or manually add these variables:
   ```
   COMPOSE_PROJECT_NAME=mautic-smartoys
   RABBITMQ_DEFAULT_VHOST=mautic
   DOCKER_MAUTIC_RUN_MIGRATIONS=1
   DOCKER_MAUTIC_LOAD_TEST_DATA=0
   ```

6. Scroll down and click **Update the stack**
7. Enable **Re-pull image and redeploy**
8. Click **Update**

### Step 5: Monitor Deployment

1. Go to **Stacks** → `mautic-smartoys` → **Containers**
2. Watch the status of containers:
   - `rabbitmq` - Should start first
   - `mautic_web` - Should start and become healthy (check mark)
   - `mautic_cron` - Starts after mautic_web is healthy
   - `mautic_worker` - Starts after mautic_web is healthy

3. Check logs for any errors:
   - Click on container name
   - Go to **Logs** tab
   - Look for errors

### Step 6: Verify Deployment

#### Check Container Health
```bash
# SSH to server or use Portainer console
docker ps | grep mautic
```

All containers should show "Up" status, and `mautic_web` should show "(healthy)".

#### Test Database Connection
In Portainer, go to container `mautic_web` → **Console** → Connect:
```bash
php -r "new PDO('mysql:host=percona-db;dbname=mautic', 'mautic', 'mautic_password_change_me');"
```

Should complete without errors.

#### Access Application
Visit: `https://newsletter.smartoys.be`

You should see the Mautic interface or installation wizard.

## Troubleshooting in Portainer

### Container Exits Immediately

**View logs:**
1. Go to **Containers**
2. Show stopped containers (toggle at top)
3. Click on the exited container
4. Go to **Logs** tab
5. Scroll to the bottom for error messages

**Common errors:**

#### "Failed to connect to database"
- Check if `percona-db` is running
- Verify database credentials in environment variables
- Ensure both containers are on `mautic-db-network`

#### "Permission denied" errors
```bash
# Fix on host
sudo chown -R 33:33 /portainer/mautic-smartoys-mautic
sudo chown -R 33:33 /portainer/mautic-smartoys-cron
```

#### "Network not found"
Create missing networks in Portainer:
- **Networks** → **Add network**

### Container Stuck in "Unhealthy" State

Check the healthcheck:
1. Container → **Inspect** → Search for "Health"
2. View health check logs

For `mautic_web`, the healthcheck runs: `curl http://localhost`

If failing, check:
- Is Apache running inside container?
- View container logs for startup errors

### Traefik Not Routing Traffic

1. Check Traefik container logs
2. Verify `mautic_web` is on `web` network
3. Check Traefik labels on `mautic_web`:
   - Should have `traefik.enable=true`
   - Router for `newsletter.smartoys.be`

### RabbitMQ Connection Issues

Check if RabbitMQ is running:
1. **Containers** → Find `rabbitmq` 
2. Should be on same network as mautic services
3. Check logs for errors

## Environment Variables Reference

These should be set in Portainer stack environment:

```bash
# Stack Variables
COMPOSE_PROJECT_NAME=mautic-smartoys
RABBITMQ_DEFAULT_VHOST=mautic
DOCKER_MAUTIC_RUN_MIGRATIONS=1
DOCKER_MAUTIC_LOAD_TEST_DATA=0

# Database Configuration (in .env section or as variables)
MAUTIC_DB_HOST=percona-db
MAUTIC_DB_PORT=3306
MAUTIC_DB_DATABASE=mautic
MAUTIC_DB_USER=mautic
MAUTIC_DB_PASSWORD=your_secure_password_here

# RabbitMQ
MAUTIC_MESSENGER_DSN_EMAIL=amqp://guest:guest@rabbitmq:5672/mautic/messages
MAUTIC_MESSENGER_DSN_HIT=amqp://guest:guest@rabbitmq:5672/mautic/messages

# Mautic Settings
MAUTIC_TRUSTED_PROXIES=0.0.0.0/0
MAUTIC_URL=https://newsletter.smartoys.be
```

## Portainer Stack Configuration

### Option 1: Using Web Editor
1. Copy content of `docker-compose.yml`
2. Paste into Portainer stack editor
3. Add environment variables manually

### Option 2: Using Git Repository
1. **Stacks** → **Add stack**
2. Select **Repository**
3. Point to your Git repo containing these files
4. Set **Compose path**: `docker-compose.yml`
5. Add environment variables

### Option 3: Using Upload
1. **Stacks** → **Add stack**
2. Select **Upload**
3. Upload `docker-compose.yml`
4. Add environment variables

## Security Checklist

Before going to production:

- [ ] Change default database password in `.mautic_env`
- [ ] Update database user password in percona-db
- [ ] Verify Traefik SSL certificate is valid
- [ ] Review Mautic security settings
- [ ] Set up backup for `/portainer/mautic-smartoys-mautic` directory
- [ ] Set up database backups
- [ ] Configure proper SMTP settings in Mautic
- [ ] Review and adjust container resource limits if needed

## Next Steps

After successful deployment:

1. **Complete Mautic Setup**
   - Visit `https://newsletter.smartoys.be`
   - Follow installation wizard (if fresh install)
   - Configure SMTP for email sending

2. **Configure Monitoring**
   - Set up container health monitoring in Portainer
   - Configure log aggregation
   - Set up alerts for container failures

3. **Backup Strategy**
   - Database: Use percona backup tools
   - Files: Back up `/portainer/mautic-smartoys-mautic` directory
   - Consider using Portainer backups feature

4. **Performance Tuning**
   - Monitor container resource usage
   - Adjust memory/CPU limits if needed
   - Configure RabbitMQ queue settings

## Quick Commands for SSH Access

If you need to SSH to the server:

```bash
# View all mautic containers
docker ps -a | grep mautic

# View logs
docker logs -f mautic-smartoys-mautic_web-1

# Execute command in container
docker exec -it mautic-smartoys-mautic_web-1 bash

# Restart stack
cd /portainer/mautic-smartoys
docker-compose restart

# View networks
docker network ls | grep -E 'web|mautic'

# Check if container is on network
docker network inspect mautic-db-network
```

## Support Resources

- Mautic Documentation: https://docs.mautic.org/
- Portainer Documentation: https://docs.portainer.io/
- Docker Compose Reference: https://docs.docker.com/compose/
