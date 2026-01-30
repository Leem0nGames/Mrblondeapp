-- VISTA: dashboard_stats
-- Agregar esta vista en Supabase SQL Editor

CREATE VIEW dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT COUNT(*) FROM clients WHERE status = 'active') as active_clients,
    (SELECT COUNT(*) FROM clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) as total_clients,
    (SELECT COUNT(*) FROM price_lists) as total_pricelists,
    (SELECT COUNT(*) FROM promotions) as total_promotions,
    (SELECT COUNT(*) FROM sales_conditions) as total_sales_conditions;
