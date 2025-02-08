
SELECT TABLE_NAME, COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME = 'details' 
  AND TABLE_SCHEMA = 'mailing';

UPDATE emails
SET headers = '{}'
WHERE headers = ''
   OR JSON_VALID(headers) = 0;


UPDATE audit_log
SET details = '{}'
WHERE details = ''
   OR JSON_VALID(details) = 0;


UPDATE sms_message_stats
SET details = '{}'
WHERE details = ''
   OR JSON_VALID(details) = 0;