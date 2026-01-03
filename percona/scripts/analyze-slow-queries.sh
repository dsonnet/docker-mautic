#!/bin/bash
# analyze-slow-queries.sh - Daily slow query analysis

DATE=$(date +%Y%m%d_%H%M%S)
SLOW_LOG="/var/log/mysql/mysql-slow.log"
REPORT_DIR="/var/log/mysql/analysis"
REPORT_FILE="${REPORT_DIR}/slow-query-report-${DATE}.txt"

# Ensure report directory exists
mkdir -p ${REPORT_DIR}

echo "=== Percona Slow Query Analysis Report ===" > ${REPORT_FILE}
echo "Generated: $(date)" >> ${REPORT_FILE}
echo "Server: $(hostname)" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

# Check if slow log exists
if [ ! -f ${SLOW_LOG} ]; then
    echo "WARNING: Slow query log not found at ${SLOW_LOG}" >> ${REPORT_FILE}
    echo "No slow queries to analyze." >> ${REPORT_FILE}
    exit 0
fi

# Check if slow log has content
if [ ! -s ${SLOW_LOG} ]; then
    echo "INFO: Slow query log is empty. No queries to analyze." >> ${REPORT_FILE}
    exit 0
fi

# 1. Generate digest report
echo "--- Top 20 Queries by Total Time ---" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}
pt-query-digest \
    --limit 20 \
    --order-by Query_time:sum \
    ${SLOW_LOG} >> ${REPORT_FILE} 2>&1

# 2. Rotate slow log
if [ -f ${SLOW_LOG} ]; then
    mv ${SLOW_LOG} ${SLOW_LOG}.${DATE}
    # Touch new log file so MySQL can write to it
    touch ${SLOW_LOG}
    chmod 644 ${SLOW_LOG}
    chown mysql:mysql ${SLOW_LOG}
    
    # Signal MySQL to reopen log files
    if command -v mysqladmin &> /dev/null; then
        mysqladmin flush-logs 2>/dev/null || true
    fi
fi

# 3. Keep only last 7 days of reports
find ${REPORT_DIR} -name "slow-query-report-*.txt" -mtime +7 -delete 2>/dev/null || true
find /var/log/mysql -name "mysql-slow.log.*" -mtime +7 -delete 2>/dev/null || true

echo "" >> ${REPORT_FILE}
echo "=== Analysis Complete ===" >> ${REPORT_FILE}
echo "Report saved to: ${REPORT_FILE}" >> ${REPORT_FILE}

# Log completion
echo "$(date): Slow query analysis completed successfully - ${REPORT_FILE}"
