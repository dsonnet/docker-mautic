# Quick Fix Checklist for Portainer

## The Problem
Container `mautic-smartoys-mautic_web-1` exited with code 1 due to:
- ❌ Missing environment variables (`.mautic_env` had undefined `${MYSQL_*}` references)
- ❌ Deprecated `external_links` in docker-compose.yml

## The Solution - 5 Steps

### ✅ Step 1: Update Stack Files in Portainer

1. Go to **Stacks** → Find `mautic-smartoys` stack
2. Click **Editor**
3. Replace the entire content with the updated `docker-compose.yml` from this repo
4. Click **Update the stack**

### ✅ Step 2: Add Environment Variables

In the same stack editor, scroll to **Environment variables** section and add:

```
COMPOSE_PROJECT_NAME=mautic-smartoys
RABBITMQ_DEFAULT_VHOST=mautic
DOCKER_MAUTIC_RUN_MIGRATIONS=1
DOCKER_MAUTIC_LOAD_TEST_DATA=0
MAUTIC_DB_HOST=percona-db
MAUTIC_DB_PORT=3306
MAUTIC_DB_DATABASE=mautic
MAUTIC_DB_USER=mautic
MAUTIC_DB_PASSWORD=CHANGE_THIS_PASSWORD
MAUTIC_MESSENGER_DSN_EMAIL=amqp://guest:guest@rabbitmq:5672/mautic/messages
MAUTIC_MESSENGER_DSN_HIT=amqp://guest:guest@rabbitmq:5672/mautic/messages
MAUTIC_TRUSTED_PROXIES=0.0.0.0/0
MAUTIC_URL=https://newsletter.smartoys.be
```

**⚠️ IMPORTANT:** Change `MAUTIC_DB_PASSWORD` to match your actual database password!

### ✅ Step 3: Verify Networks Exist

Go to **Networks** in Portainer and verify these networks exist:
- [ ] `web` (for Traefik)
- [ ] `mautic-db-network` (for database)

If missing, create them:
- Click **Add network**
- Name: `web` or `mautic-db-network`
- Driver: `bridge`
- Click **Create network**

### ✅ Step 4: Verify Database Setup

1. Go to **Containers** → `percona-db` → **Console**
2. Click **Connect** (select /bin/bash)
3. Run:
```bash
mysql -u root -p

# In MySQL prompt, run these commands:
CREATE DATABASE IF NOT EXISTS mautic CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'mautic'@'%' IDENTIFIED BY 'CHANGE_THIS_PASSWORD';
GRANT ALL PRIVILEGES ON mautic.* TO 'mautic'@'%';
FLUSH PRIVILEGES;
EXIT;
```

**⚠️ Use the same password as in Step 2!**

### ✅ Step 5: Create Volume Directories

SSH to your server and run:

```bash
sudo mkdir -p /portainer/mautic-smartoys-mautic/config
sudo mkdir -p /portainer/mautic-smartoys-mautic/logs
sudo mkdir -p /portainer/mautic-smartoys-mautic/media/files
sudo mkdir -p /portainer/mautic-smartoys-mautic/media/images
sudo mkdir -p /portainer/mautic-smartoys-cron

sudo chown -R 33:33 /portainer/mautic-smartoys-mautic
sudo chown -R 33:33 /portainer/mautic-smartoys-cron
```

## Deploy!

After completing all steps:

1. In Portainer, go to **Stacks** → `mautic-smartoys`
2. Click **Update the stack**
3. Enable **Re-pull image and redeploy**
4. Click **Update**

## Monitor Deployment

Watch the containers start in order:
1. `rabbitmq` - starts first
2. `mautic_web` - waits for database, should become healthy (✓)
3. `mautic_cron` - starts after mautic_web is healthy
4. `mautic_worker` - starts after mautic_web is healthy

To view logs:
- Click container name → **Logs** tab

## Verify Success

✅ All containers show "Up" status
✅ `mautic_web` shows "(healthy)"
✅ No errors in logs
✅ Access `https://newsletter.smartoys.be` - should show Mautic

## If It Still Fails

1. **Check container logs** in Portainer:
   - Containers → Find stopped container → Logs tab
   
2. **Common issues:**
   - Database password mismatch → Update both `.env` and MySQL
   - Networks don't exist → Create them in Networks section
   - Permission denied → Run the `chown` commands above
   - Can't connect to database → Verify `percona-db` is running and on `mautic-db-network`

3. **Full troubleshooting:** See `PORTAINER_DEPLOYMENT.md` in this repo

## Files Changed

- ✅ [`.mautic_env`](.mautic_env:1) - Fixed environment variables
- ✅ [`docker-compose.yml`](docker-compose.yml:1) - Removed deprecated `external_links`
- 📄 `PORTAINER_DEPLOYMENT.md` - Detailed Portainer guide
- 📄 `DEPLOYMENT_TROUBLESHOOTING.md` - General troubleshooting

## Need More Help?

- See detailed guide: `PORTAINER_DEPLOYMENT.md`
- Check Mautic docs: https://docs.mautic.org/
- Review container logs in Portainer for specific errors
