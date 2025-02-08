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
  WHERE date_hit < DATE_SUB(NOW(), INTERVAL 18 MONTH);
