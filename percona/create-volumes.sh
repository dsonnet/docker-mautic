#!/bin/bash

# Script to create Docker volumes for Mautic Percona database
# Usage: ./create-volumes.sh [method]
# Methods: simple, bind, labels

set -e

METHOD=${1:-simple}

echo "Creating Docker volumes for Mautic database..."
echo "Method: $METHOD"
echo ""

case $METHOD in
  simple)
    echo "Creating volumes with default settings..."
    docker volume create mautic-db-data
    docker volume create mautic-db-logs
    docker volume create mautic-db-scripts
    docker volume create mautic-db-reports
    ;;
    
  bind)
    echo "Creating volumes with bind mounts to /portainer/mautic-db/..."
    
    # Create directories if they don't exist
    sudo mkdir -p /portainer/mautic-db/data
    sudo mkdir -p /portainer/mautic-db/logs
    sudo mkdir -p /portainer/mautic-db/scripts
    sudo mkdir -p /portainer/mautic-db/reports
    
    # Set permissions for MySQL user (UID 999)
    sudo chown -R 999:999 /portainer/mautic-db/data
    sudo chown -R 999:999 /portainer/mautic-db/logs
    
    # Create volumes pointing to these directories
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
    ;;
    
  labels)
    echo "Creating volumes with labels..."
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
    ;;
    
  *)
    echo "Unknown method: $METHOD"
    echo "Available methods: simple, bind, labels"
    exit 1
    ;;
esac

echo ""
echo "✓ Volumes created successfully!"
echo ""
echo "List of created volumes:"
docker volume ls | grep mautic-db

echo ""
echo "To inspect a volume, run:"
echo "  docker volume inspect mautic-db-data"
echo ""
echo "To start the services, run:"
echo "  docker-compose -f docker-compose.percona.yml up -d"
