ALTER TABLE leads
ADD INDEX idx_lastactive_id (last_active DESC, id DESC);


CREATE INDEX idx_leadlists_leads_filter 
    ON lead_lists_leads (leadlist_id, manually_added, lead_id);
