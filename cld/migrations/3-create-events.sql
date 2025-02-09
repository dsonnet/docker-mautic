CREATE EVENT IF NOT EXISTS delete_old_email_stats
ON SCHEDULE EVERY 1 DAY
STARTS '2025-02-11 00:00:00'
DO
  DELETE FROM email_stats
  WHERE date_sent < DATE_SUB(NOW(), INTERVAL 3 MONTH);


CREATE EVENT IF NOT EXISTS delete_old_page_hits
ON SCHEDULE EVERY 1 DAY
STARTS '2025-02-11 02:00:00'
DO
  DELETE FROM page_hits
  WHERE date_hit < DATE_SUB(NOW(), INTERVAL 3 MONTH);


CREATE EVENT IF NOT EXISTS delete_old_lead_devices
ON SCHEDULE EVERY 1 DAY
STARTS '2025-02-11 03:00:00'
DO
delete
FROM lead_devices
WHERE date_added < DATE_SUB(NOW(), INTERVAL 3 YEAR);


CREATE EVENT IF NOT EXISTS delete_old_email_copies
ON SCHEDULE EVERY 1 DAY
STARTS '2025-02-11 04:00:00'
delete
FROM email_copies 
where date_created < DATE_SUB(NOW(), INTERVAL 2 YEAR);