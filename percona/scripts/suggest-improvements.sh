#!/bin/bash
# suggest-improvements.sh - Extract top slow queries and suggest improvements

DATE=$(date +%Y%m%d_%H%M%S)
SLOW_LOG="/var/log/mysql/mysql-slow.log"
REPORT_DIR="/var/log/mysql/analysis"
REPORT_FILE="${REPORT_DIR}/improvements-${DATE}.txt"

# Database credentials from environment
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS="${MYSQL_ROOT_PASSWORD}"
MYSQL_DB="${MYSQL_DATABASE}"

echo "=== Query Improvement Suggestions ===" > ${REPORT_FILE}
echo "Generated: $(date)" >> ${REPORT_FILE}
echo "Server: $(hostname)" >> ${REPORT_FILE}
echo "Database: ${MYSQL_DB}" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

# Find slow log files from last week
RECENT_LOGS=$(find /var/log/mysql -name "mysql-slow.log*" -mtime -7 2>/dev/null | sort)

if [ -z "$RECENT_LOGS" ]; then
    echo "No slow query logs found from the last 7 days." >> ${REPORT_FILE}
    echo "Run queries to generate slow log data first." >> ${REPORT_FILE}
    exit 0
fi

# 1. Top queries by different metrics
echo "=== Top Queries by Different Metrics ===" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

echo "--- Top 10 by Execution Time ---" >> ${REPORT_FILE}
pt-query-digest \
    --limit 10 \
    --order-by Query_time:sum \
    --output query_report \
    $RECENT_LOGS >> ${REPORT_FILE} 2>&1

echo "" >> ${REPORT_FILE}
echo "--- Top 10 by Rows Examined ---" >> ${REPORT_FILE}
pt-query-digest \
    --limit 10 \
    --order-by Rows_examined:sum \
    --output query_report \
    $RECENT_LOGS >> ${REPORT_FILE} 2>&1

echo "" >> ${REPORT_FILE}
echo "--- Queries NOT Using Indexes ---" >> ${REPORT_FILE}
pt-query-digest \
    --limit 10 \
    --filter '($event->{No_index_used} eq "Yes") || ($event->{No_good_index_used} eq "Yes")' \
    --output query_report \
    $RECENT_LOGS >> ${REPORT_FILE} 2>&1

# 2. Performance statistics
echo "" >> ${REPORT_FILE}
echo "=== Overall Performance Statistics ===" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

mysql -h localhost -u ${MYSQL_USER} -p"${MYSQL_PASS}" -e "
SHOW GLOBAL STATUS LIKE 'Slow_queries';
SHOW GLOBAL STATUS LIKE 'Questions';
SHOW GLOBAL STATUS LIKE 'Uptime';
" >> ${REPORT_FILE} 2>&1

# 3. Table statistics for slow queries
echo "" >> ${REPORT_FILE}
echo "=== Tables Frequently Queried (from slow log) ===" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}

# Extract table names and count occurrences
pt-query-digest \
    --limit 20 \
    --group-by tables \
    $RECENT_LOGS >> ${REPORT_FILE} 2>&1

# 4. Actionable recommendations
echo "" >> ${REPORT_FILE}
echo "=== Actionable Recommendations ===" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}
echo "OPTIMIZATION PRIORITIES:" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}
echo "1. INDEXES:" >> ${REPORT_FILE}
echo "   - Add indexes for columns in WHERE, JOIN, and ORDER BY clauses" >> ${REPORT_FILE}
echo "   - Focus on queries with high Rows_examined to Rows_sent ratio" >> ${REPORT_FILE}
echo "   - Create covering indexes for frequently accessed column sets" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}
echo "2. QUERY OPTIMIZATION:" >> ${REPORT_FILE}
echo "   - Rewrite queries that perform full table scans" >> ${REPORT_FILE}
echo "   - Avoid SELECT * - specify only needed columns" >> ${REPORT_FILE}
echo "   - Use LIMIT to restrict result sets" >> ${REPORT_FILE}
echo "   - Consider query caching for frequently repeated queries" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}
echo "3. SCHEMA OPTIMIZATION:" >> ${REPORT_FILE}
echo "   - Review table structures for normalization issues" >> ${REPORT_FILE}
echo "   - Consider partitioning for very large tables" >> ${REPORT_FILE}
echo "   - Use appropriate data types to minimize storage" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}
echo "4. MONITORING:" >> ${REPORT_FILE}
echo "   - Track query patterns over time" >> ${REPORT_FILE}
echo "   - Set up alerts for queries exceeding time thresholds" >> ${REPORT_FILE}
echo "   - Review this report weekly and act on recommendations" >> ${REPORT_FILE}
echo "" >> ${REPORT_FILE}
echo "5. TESTING:" >> ${REPORT_FILE}
echo "   - Use EXPLAIN to understand query execution plans" >> ${REPORT_FILE}
echo "   - Test optimizations in staging before production" >> ${REPORT_FILE}
echo "   - Measure impact using before/after comparisons" >> ${REPORT_FILE}

echo "" >> ${REPORT_FILE}
echo "=== Next Steps ===" >> ${REPORT_FILE}
echo "1. Review the top queries by execution time" >> ${REPORT_FILE}
echo "2. Run EXPLAIN on slow queries to understand execution plans" >> ${REPORT_FILE}
echo "3. Add missing indexes identified in the analysis" >> ${REPORT_FILE}
echo "4. Rewrite inefficient queries" >> ${REPORT_FILE}
echo "5. Monitor improvements in next week's report" >> ${REPORT_FILE}

echo "" >> ${REPORT_FILE}
echo "=== Analysis Complete ===" >> ${REPORT_FILE}
echo "Report saved to: ${REPORT_FILE}" >> ${REPORT_FILE}

# Keep only last 30 days of improvement reports
find ${REPORT_DIR} -name "improvements-*.txt" -mtime +30 -delete 2>/dev/null || true

# Log completion
echo "$(date): Improvement suggestions completed successfully - ${REPORT_FILE}"
