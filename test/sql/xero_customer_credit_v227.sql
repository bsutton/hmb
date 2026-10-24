INSERT INTO customer (id) VALUES (1);
INSERT INTO xero_customer_credit
 (tenant_id, external_id, customer_id, credit_date, amount, remaining_credit)
VALUES ('test-tenant', 'test-credit', 1, '2026-01-01', 10000, 10000);
