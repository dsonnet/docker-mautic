

UPDATE emails
SET headers = '{}'
WHERE headers = ''
   OR JSON_VALID(headers) = 0;


UPDATE audit_log
SET details = '{}'
WHERE details = ''
   OR JSON_VALID(details) = 0;
