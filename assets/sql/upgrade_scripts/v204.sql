UPDATE mailing_recipient
SET route_order = NULL,
    route_batch = NULL,
    modifiedDate = strftime('%Y-%m-%dT%H:%M:%f', 'now')
WHERE mailing_id IN (
  SELECT id
  FROM mailing
  WHERE route_optimised = 0
);

UPDATE mailing
SET status = 'draft',
    modifiedDate = strftime('%Y-%m-%dT%H:%M:%f', 'now')
WHERE route_optimised = 0
  AND status = 'routeReady';
