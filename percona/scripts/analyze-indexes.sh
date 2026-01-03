#!/bin/bash
# analyze-indexes.sh - Analyze index usage and suggest improvements

DATE=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/var/log/mysql/analysis"
REPORT_FILE="${REPORT_DIR}/index-analysis-${DATE}.txt"

# Database credentials from environment
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS="${MYSQL_ROOT_PASSWORD}"
MYSQL_DB="${MYSQL_DATABASE}"

echo "=== Index Analysis Report ===" > ${REPORT_FILE}
echo "Generated: $(date)" >> ${REPORT_FILE}
echo "Server: $(hostname)" >> ${REPORT_FILE}
echo "Database: ${MYSQL_DB}" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

# Wait for MySQL to be ready
until mysqladmin ping -h localhost --silent 2>/dev/null; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

# 1. Check for duplicate indexes
echo "=== Duplicate Index Check ===" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}
echo "Checking for duplicate or redundant indexes..." >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

pt-duplicate-key-checker \
    --host localhost \
    --user ${MYSQL_USER} \
    --password="${MYSQL_PASS}" \
    --databases ${MYSQL_DB} >> ${REPORT_FILE} 2>&1

echo "" >> ${REPORT_FILE}

# 2. Index usage from slow log (if available)
echo "=== Index Usage Analysis from Slow Query Logs ===" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

# Find recent slow log files
SLOW_LOGS=$(find /var/log/mysql -name "mysql-slow.log.*" -mtime -7 2>/dev/null)

if [ -n "$SLOW_LOGS" ]; then
    echo "Analyzing slow query logs from the last 7 days..." >> ${REPORT_FILE}
    echo "" >> ${REPORT_FILE}
    
    pt-index-usage \
        --host localhost \
        --user ${MYSQL_USER} \
        --password="${MYSQL_PASS}" \
        $SLOW_LOGS >> ${REPORT_FILE} 2>&1
else
    echo "No slow query logs found from the last 7 days." >> ${REPORT_FILE}
    echo "Consider running this analysis after some slow queries have been logged." >> ${REPORT_FILE}
fi

echo "" >> ${REPORT_FILE}

# 3. Table statistics
echo "=== Database Table Statistics ===" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

mysql -h localhost -u ${MYSQL_USER} -p"${MYSQL_PASS}" ${MYSQL_DB} -e "
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)',
    ROUND((index_length / 1024 / 1024), 2) AS 'Index Size (MB)',
    table_rows AS 'Rows'
FROM information_schema.TABLES
WHERE table_schema = '${MYSQL_DB}'
ORDER BY (data_length + index_length) DESC
LIMIT 20;
" >> ${REPORT_FILE} 2>&1

echo "" >> ${REPORT_FILE}
echo "=== Recommendations ===" >> ${REPORT_FILE}
echo "1. Review and remove duplicate indexes to reduce storage and improve write performance" >> ${REPORT_FILE}
echo "2. Add indexes for columns frequently used in WHERE, JOIN, and ORDER BY clauses" >> ${REPORT_FILE}
echo "3. Consider composite indexes for queries with multiple WHERE conditions" >> ${REPORT_FILE}
echo "4. Monitor index usage - unused indexes should be removed" >> ${REPORT_FILE}
echo "5. Large tables may benefit from index optimization and ANALYZE TABLE" >> ${REPORT_FILE}

echo "" >> ${REPORT_FILE}
echo "=== Analysis Complete ===" >> ${REPORT_FILE}
echo "Report saved to: ${REPORT_FILE}" >> ${REPORT_FILE}

# Keep only last 30 days of index reports (weekly = 4-5 reports)
find ${REPORT_DIR} -name "index-analysis-*.txt" -mtime +30 -delete 2>/dev/null || true

# Log completion
echo "$(date): Index analysis completed successfully - ${REPORT_FILE}"
