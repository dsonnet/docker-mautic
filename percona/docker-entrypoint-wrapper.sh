#!/bin/bash
set -e

# Start cron in background
service cron start

# Setup cron jobs after MySQL starts
(
    # Wait for MySQL to be ready
    echo "Waiting for MySQL to start..."
    until mysqladmin ping -h localhost --silent 2>/dev/null; do
        sleep 2
    done
    
    echo "MySQL is ready. Setting up cron jobs..."
    /opt/analysis/setup-cron.sh
    echo "Cron jobs configured successfully."
) &

# Execute the original docker-entrypoint
exec docker-entrypoint.sh "$@"
