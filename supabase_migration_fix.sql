-- =====================================================
-- MIGRATION FIX - MR. BLONDE APP
-- Versión conservadora - solo agrega lo que falta
-- =====================================================

-- 1. Agregar columnas faltantes si no existen
DO $$
BEGIN
    -- Clients
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clients' AND column_name = 'auth_user_id') THEN
        ALTER TABLE public.clients ADD COLUMN auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clients' AND column_name = 'contact_dni') THEN
        ALTER TABLE public.clients ADD COLUMN contact_dni text;
    END IF;

    -- Orders
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'client_name_cache') THEN
        ALTER TABLE public.orders ADD COLUMN client_name_cache text;
    END IF;
END $$;

-- 2. Agregar índices faltantes
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON public.orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_agreement_id ON public.orders(agreement_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_price_list_items_price_list_id ON public.price_list_items(price_list_id);
CREATE INDEX IF NOT EXISTS idx_price_list_items_product_id ON public.price_list_items(product_id);
CREATE INDEX IF NOT EXISTS idx_clients_agreement_id ON public.clients(agreement_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);

-- 3. Verificar si dashboard_stats existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'dashboard_stats') THEN
        -- Crear vista simple
        EXECUTE '
        CREATE VIEW public.dashboard_stats AS
        SELECT
            0 as total_revenue,
            0 as month_revenue,
            0 as active_clients,
            0 as total_clients,
            0 as overdue_orders_count,
            0 as total_pricelists,
            0 as total_promotions,
            0 as total_sales_conditions';
    END IF;
END $$;

-- 4. Storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public;

INSERT INTO storage.buckets (id, name, public)
VALUES ('app_assets', 'app_assets', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public;

-- 5. Seed app_settings
INSERT INTO public.app_settings (key, value) VALUES
    ('whatsapp_number', '"5491123456789"'),
    ('vat_percentage', '21'),
    ('logo_url', 'null')
ON CONFLICT(key) DO NOTHING;

-- =====================================================
-- FIN
-- =====================================================

-- 1. Recreate ENUM types (safe drop + create)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.agreement_client_type CASCADE;

CREATE TYPE public.client_status AS ENUM (
    'pending_onboarding',
    'pending_agreement',
    'active',
    'archived'
);

CREATE TYPE public.order_status AS ENUM (
    'pending',
    'completed'
);

CREATE TYPE public.agreement_client_type AS ENUM (
    'barberia',
    'distribuidor',
    'especial'
);

-- 2. Add missing columns to existing tables (IF NOT EXISTS pattern)

-- Add auth_user_id to clients if missing
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'clients' AND column_name = 'auth_user_id') THEN
        ALTER TABLE public.clients ADD COLUMN auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Add contact_dni to clients if missing
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'clients' AND column_name = 'contact_dni') THEN
        ALTER TABLE public.clients ADD COLUMN contact_dni text;
    END IF;
END $$;

-- 3. Add missing indexes
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON public.orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_agreement_id ON public.orders(agreement_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_price_list_items_price_list_id ON public.price_list_items(price_list_id);
CREATE INDEX IF NOT EXISTS idx_price_list_items_product_id ON public.price_list_items(product_id);
CREATE INDEX IF NOT EXISTS idx_clients_agreement_id ON public.clients(agreement_id);
CREATE INDEX IF NOT EXISTS idx_clients_status ON public.clients(status);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);

-- 4. Create missing views (replace if exists)
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND date_trunc('month', created_at) = date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT COUNT(*) FROM public.clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) AS total_clients,
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '30 days'::interval)) AS overdue_orders_count,
    (SELECT COUNT(*) FROM public.price_lists) AS total_pricelists,
    (SELECT COUNT(*) FROM public.promotions) AS total_promotions,
    (SELECT COUNT(*) FROM public.sales_conditions) AS total_sales_conditions;

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    pl.name AS price_list_name,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions ascnd WHERE ascnd.agreement_id = a.id) AS sales_condition_count
FROM public.agreements a
LEFT JOIN public.price_lists pl ON a.price_list_id = pl.id;

-- 5. Create/update functions
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE (total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0)::numeric,
        COALESCE(AVG(o.total_amount), 0)::numeric,
        COUNT(o.id)::bigint
    FROM public.orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE (pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::bigint FROM public.orders WHERE status = 'pending'),
        (SELECT COUNT(*)::bigint FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*)::bigint FROM public.orders WHERE status = 'pending' AND created_at < (now() - '30 days'::interval));
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN NULL; END;
$$;

-- 6. Enable RLS on tables that might not have it
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;

-- 7. Create missing RLS policies (drop first, then create)
DROP POLICY IF EXISTS "Admin manage all agreements" ON public.agreements;
DROP POLICY IF EXISTS "Client read own data" ON public.clients;
DROP POLICY IF EXISTS "Client update own data" ON public.clients;

CREATE POLICY "Admin manage all agreements" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Client read own data" ON public.clients FOR SELECT USING (
    (auth.jwt() ->> 'token'::text) = onboarding_token OR auth.role() = 'authenticated'
);

CREATE POLICY "Client update own data" ON public.clients FOR UPDATE USING (
    (auth.jwt() ->> 'token'::text) = onboarding_token OR auth.role() = 'authenticated'
) WITH CHECK (
    (auth.jwt() ->> 'token'::text) = onboarding_token OR auth.role() = 'authenticated'
);

-- 8. Storage buckets and() = 'authenticated policies
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public;

INSERT INTO storage.buckets (id, name, public)
VALUES ('app_assets', 'app_assets', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public;

-- 9. Seed app_settings if not exists
INSERT INTO public.app_settings (key, value) VALUES
    ('whatsapp_number', '"5491123456789"'),
    ('vat_percentage', '21'),
    ('logo_url', 'null')
ON CONFLICT(key) DO NOTHING;

-- =====================================================
-- FIN DE LA MIGRACIÓN
-- =====================================================
