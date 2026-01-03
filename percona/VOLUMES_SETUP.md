# Manual Docker Volume Setup for Percona MySQL

This guide explains how to manually create and manage Docker volumes for your Percona MySQL database.

## Overview

The docker-compose configuration now uses Docker named volumes instead of bind mounts. These volumes need to be created manually before starting the services.

## Required Volumes

- `mautic-db-data` - MySQL database files
- `mautic-db-logs` - MySQL slow query and error logs
- `mautic-db-scripts` - Analysis scripts for Percona Toolkit
- `mautic-db-reports` - Generated reports from Percona Toolkit

## Creating the Volumes

### Option 1: Basic Volume Creation

Create the volumes with default settings:

```bash
docker volume create mautic-db-data
docker volume create mautic-db-logs
docker volume create mautic-db-scripts
docker volume create mautic-db-reports
```

### Option 2: Volumes with Specific Driver Options

If you want to store volumes in a specific location on your host:

```bash
# Create volume with local driver pointing to specific directory
docker volume create \
  --driver local \
  --opt type=none \
  --opt device=/portainer/mautic-db/data \
  --opt o=bind \
  mautic-db-data

docker volume create \
  --driver local \
  --opt type=none \
  --opt device=/portainer/mautic-db/logs \
  --opt o=bind \
  mautic-db-logs

docker volume create \
  --driver local \
  --opt type=none \
  --opt device=/portainer/mautic-db/scripts \
  --opt o=bind \
  mautic-db-scripts

docker volume create \
  --driver local \
  --opt type=none \
  --opt device=/portainer/mautic-db/reports \
  --opt o=bind \
  mautic-db-reports
```

### Option 3: Volumes with Labels

Add labels for better organization:

```bash
docker volume create \
  --label project=mautic \
  --label component=database \
  --label type=data \
  mautic-db-data

docker volume create \
  --label project=mautic \
  --label component=database \
  --label type=logs \
  mautic-db-logs

docker volume create \
  --label project=mautic \
  --label component=toolkit \
  --label type=scripts \
  mautic-db-scripts

docker volume create \
  --label project=mautic \
  --label component=toolkit \
  --label type=reports \
  mautic-db-reports
```

## Migrating Existing Data

If you have existing data in `/portainer/mautic-db/data`, you can migrate it:

### Method 1: Copy Data to New Volume

```bash
# Create the volume first
docker volume create mautic-db-data

# Run a temporary container to copy data
docker run --rm \
  -v /portainer/mautic-db/data:/source:ro \
  -v mautic-db-data:/destination \
  alpine \
  sh -c "cp -av /source/. /destination/"

# Repeat for logs
docker volume create mautic-db-logs
docker run --rm \
  -v /portainer/mautic-db/logs:/source:ro \
  -v mautic-db-logs:/destination \
  alpine \
  sh -c "cp -av /source/. /destination/"
```

### Method 2: Use Volume with Bind Mount (Hybrid Approach)

This keeps your data in the existing location but manages it as a Docker volume:

```bash
docker volume create \
  --driver local \
  --opt type=none \
  --opt device=/portainer/mautic-db/data \
  --opt o=bind \
  mautic-db-data
```

## Managing Volumes

### List Volumes
```bash
docker volume ls
# Filter by project
docker volume ls --filter label=project=mautic
```

### Inspect a Volume
```bash
docker volume inspect mautic-db-data
```

### View Volume Location
```bash
# Default Docker volume location
docker volume inspect mautic-db-data --format '{{ .Mountpoint }}'
```

### Backup a Volume
```bash
# Backup data volume to tar archive
docker run --rm \
  -v mautic-db-data:/data \
  -v $(pwd):/backup \
  alpine \
  tar czf /backup/mautic-db-data-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore from Backup
```bash
# Restore data from tar archive
docker run --rm \
  -v mautic-db-data:/data \
  -v $(pwd):/backup \
  alpine \
  sh -c "cd /data && tar xzf /backup/mautic-db-data-YYYYMMDD.tar.gz"
```

### Remove Volumes (Warning: Data Loss!)
```bash
# Remove individual volume
docker volume rm mautic-db-data

# Remove all project volumes
docker volume ls --filter label=project=mautic -q | xargs docker volume rm
```

## Starting the Services

After creating the volumes:

```bash
cd percona
docker-compose -f docker-compose.percona.yml up -d
```

## Troubleshooting

### Volume Already Exists
If you get "volume already exists" error, check if it's from a previous setup:
```bash
docker volume inspect mautic-db-data
```

### Permission Issues
If you encounter permission issues, ensure the volume directory has correct permissions:
```bash
# For bind-mounted volumes
sudo chown -R 999:999 /portainer/mautic-db/data
sudo chown -R 999:999 /portainer/mautic-db/logs
```

### Check Volume Usage
```bash
# See disk space used by volume
docker system df -v | grep mautic
```

## Best Practices

1. **Backup Regularly**: Create automated backups of your data volume
2. **Use Labels**: Tag volumes with project and component labels for easier management
3. **Monitor Disk Space**: Keep track of volume sizes, especially for logs
4. **Test Restores**: Periodically test your backup/restore procedures
5. **Document Custom Paths**: If using bind mounts, document the paths in your project README

## Advantages of Named Volumes vs Bind Mounts

✅ **Named Volumes:**
- Docker manages lifecycle
- Better portability
- Easier backup/restore with Docker commands
- Better performance on Docker Desktop (Mac/Windows)
- Clearer in docker-compose files

✅ **Bind Mounts (with volume driver):**
- Full control over data location
- Easy direct access to files
- Can use existing directory structures
- Simpler for development

The updated configuration uses named volumes marked as `external: true`, giving you full control over volume creation while benefiting from Docker's volume management.
