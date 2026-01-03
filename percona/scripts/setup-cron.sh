#!/bin/bash
# setup-cron.sh - Set up cron jobs for automated analysis

# Ensure log directory exists
mkdir -p /var/log/mysql/analysis

# Create cron configuration
cat > /etc/cron.d/mysql-analysis << 'EOF'
# MySQL Slow Query Analysis Cron Jobs
# Note: Times are in UTC

# Daily slow query analysis at 2 AM UTC (3 AM CET)
0 2 * * * root /opt/analysis/analyze-slow-queries.sh >> /var/log/mysql/analysis/cron.log 2>&1

# Weekly index analysis - Sundays at 3 AM UTC (4 AM CET)
0 3 * * 0 root /opt/analysis/analyze-indexes.sh >> /var/log/mysql/analysis/cron.log 2>&1

# Weekly improvement suggestions - Sundays at 4 AM UTC (5 AM CET)
0 4 * * 0 root /opt/analysis/suggest-improvements.sh >> /var/log/mysql/analysis/cron.log 2>&1

# Empty line at end of file required
EOF

# Set correct permissions
chmod 644 /etc/cron.d/mysql-analysis

# Reload cron
if command -v service &> /dev/null; then
    service cron reload 2>/dev/null || true
fi

# Log setup
echo "$(date): MySQL analysis cron jobs configured successfully"
echo "  - Daily slow query analysis: 2 AM UTC"
echo "  - Weekly index analysis: Sunday 3 AM UTC"
echo "  - Weekly improvements: Sunday 4 AM UTC"
echo "  - Logs: /var/log/mysql/analysis/cron.log"
