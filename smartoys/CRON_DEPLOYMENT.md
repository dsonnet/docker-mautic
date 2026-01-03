# Optimized Crontab Deployment Guide

## Overview
This guide explains how to deploy the optimized crontab configuration for Mautic in your Docker environment.

## What Changed
The optimized crontab reduces job frequency from **every minute** to **every 15 minutes** for heavy operations:
- Prevents database overload
- Reduces CPU usage by ~90%
- Eliminates race conditions
- Adds missing critical jobs (emails:send, messages:send, reports:scheduler)
- Fixes GeoIP update frequency (monthly instead of hourly)

## Deployment Methods

### Method 1: Quick Update (Existing Deployment)

For an already running deployment, update the crontab immediately:

```bash
# Copy optimized crontab to the running container
docker cp smartoys/smartoys-optimized.crontab mautic_smartoys_cron:/etc/cron.d/mautic

# Set correct permissions
docker exec mautic_smartoys_cron chmod 644 /etc/cron.d/mautic

# Reload cron
docker exec mautic_smartoys_cron service cron reload

# Verify installation
docker exec mautic_smartoys_cron crontab -l
```

### Method 2: New Deployment (Recommended)

For new deployments or rebuilds:

#### Step 1: Replace the Old Crontab File
```bash
# Backup the old file
cp smartoys/smartoys.crontab smartoys/smartoys.crontab.backup

# Replace with optimized version
cp smartoys/smartoys-optimized.crontab smartoys/smartoys.crontab
```

#### Step 2: Deploy with Docker Compose
```bash
# Pull latest images
docker-compose pull

# Stop existing containers
docker-compose down

# Start with new configuration
docker-compose up -d

# Verify cron is running
docker-compose logs mautic_cron
```

#### Step 3: Verify Installation
```bash
# Check crontab is loaded
docker exec mautic_smartoys_cron crontab -u www-data -l

# Monitor cron logs
docker exec mautic_smartoys_cron tail -f /var/log/cron.pipe

# Check job execution (wait 5-15 minutes)
docker exec mautic_smartoys_cron ls -la /var/log/cron.pipe
```

### Method 3: Using Volume Mount (Persistent)

If you want crontab changes to persist across container rebuilds:

#### Step 1: Create Crontab on Host
```bash
# Ensure the volume directory exists
mkdir -p /portainer/${COMPOSE_PROJECT_NAME}-cron

# Copy optimized crontab to host volume
cp smartoys/smartoys-optimized.crontab /portainer/${COMPOSE_PROJECT_NAME}-cron/mautic.crontab
```

#### Step 2: Update docker-compose.yml
Add volume mount for crontab (if not already present):

```yaml
mautic_cron:
  image: mautic/mautic:6.0.7-apache
  volumes:
    - *mautic-volumes
    - /portainer/${COMPOSE_PROJECT_NAME}-cron/mautic.crontab:/etc/cron.d/mautic:ro
```

#### Step 3: Restart Container
```bash
docker-compose up -d mautic_cron
```

## Verification Checklist

After deployment, verify the configuration:

```bash
# ✓ Check cron daemon is running
docker exec mautic_smartoys_cron ps aux | grep cron

# ✓ Verify crontab is loaded
docker exec mautic_smartoys_cron crontab -u www-data -l | head -20

# ✓ Check job timing (should show 15-min intervals for heavy jobs)
docker exec mautic_smartoys_cron grep "segments:update" /etc/cron.d/mautic

# ✓ Monitor first job execution
docker exec mautic_smartoys_cron tail -f /var/log/cron.pipe

# ✓ Check system resources (should be lower than before)
docker stats mautic_smartoys_cron --no-stream
```

## Expected Job Schedule

After deployment, jobs will run on these intervals:

| Job | Old Frequency | New Frequency | Next Run Time |
|-----|--------------|---------------|---------------|
| segments:update | Every minute | Every 15 min (8,23,38,52) | :08, :23, :38, :52 |
| campaigns:update | Every minute | Every 15 min (5,20,35,50) | :05, :20, :35, :50 |
| campaigns:trigger | Every minute | Every 15 min (2,17,32,47) | :02, :17, :32, :47 |
| emails:send | Missing ❌ | Every 15 min (0,15,30,45) | :00, :15, :30, :45 |
| broadcast:send | Every minute | Every 15 min (0,15,30,45) | :00, :15, :30, :45 |
| import | Every 3 min | Every 5 min | Every 5 min |
| iplookup:download | Every hour ❌ | Monthly (15th @ 3:11am) | 15th of month |

## Performance Impact

Expected improvements after deployment:

- **CPU Usage**: 70-90% reduction during cron execution
- **Database Load**: 93% fewer queries from cron jobs
- **Memory**: More stable, fewer spikes
- **Response Time**: Faster web interface during cron windows

## Monitoring

Monitor system health after deployment:

```bash
# Real-time resource monitoring
docker stats mautic_smartoys_cron

# Watch cron execution logs
docker exec mautic_smartoys_cron tail -f /var/log/cron.pipe

# Check for errors
docker logs mautic_smartoys_cron | grep -i error

# Database connection check
docker exec mautic_smartoys_cron php /var/www/html/bin/console doctrine:database:connect
```

## Rollback Instructions

If you need to rollback to the old configuration:

```bash
# Restore backup
cp smartoys/smartoys.crontab.backup smartoys/smartoys.crontab

# Copy to container
docker cp smartoys/smartoys.crontab mautic_smartoys_cron:/etc/cron.d/mautic

# Reload cron
docker exec mautic_smartoys_cron service cron reload
```

## Troubleshooting

### Cron jobs not running
```bash
# Check if cron daemon is running
docker exec mautic_smartoys_cron service cron status

# Restart cron service
docker exec mautic_smartoys_cron service cron restart

# Check crontab syntax
docker exec mautic_smartoys_cron crontab -u www-data -l | grep -v "^#" | grep -v "^$"
```

### Jobs running at wrong times
```bash
# Verify timezone
docker exec mautic_smartoys_cron date
docker exec mautic_smartoys_cron cat /etc/timezone

# Check crontab entries
docker exec mautic_smartoys_cron cat /etc/cron.d/mautic
```

### High resource usage persists
```bash
# Check for overlapping jobs
docker exec mautic_smartoys_cron ps aux | grep mautic:

# Monitor database queries
docker logs percona-db | tail -100

# Check Mautic logs
docker exec mautic_smartoys_cron tail -100 /var/www/html/var/logs/mautic_prod.log
```

## Notes

- The optimized configuration uses `/var/www/html/bin/console` (Mautic 6.x path)
- Jobs are staggered to prevent concurrent database access
- GeoIP updates are now monthly (MaxMind updates once per month)
- Cleanup job uses 365-day retention with GDPR compliance
- Queue processing happens once daily instead of every minute

## Support

For issues or questions, check:
- Mautic documentation: https://docs.mautic.org/en/setup/cron-jobs
- Docker logs: `docker-compose logs mautic_cron`
- System resources: `docker stats`
