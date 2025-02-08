ALTER TABLE leads
ADD INDEX idx_lastactive_id (last_active DESC, id DESC);
