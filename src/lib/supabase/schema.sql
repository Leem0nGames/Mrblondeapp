
-- 1. Limpieza y Reseteo
-- Primero, eliminamos objetos que dependen de otros, como vistas y funciones.
-- Usamos CASCADE para que elimine automáticamente cualquier objeto dependiente.

DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;

-- Luego, eliminamos las tablas. CASCADE se encargará de las claves foráneas.
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.app_meta CASCADE;


-- Por último, los tipos (ENUMs).
DROP TYPE IF EXISTS public.client_status;
DROP TYPE IF EXISTS public.order_status;
DROP TYPE IF EXISTS public.client_type;

-- 2. Creación de Tipos (ENUMs)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');

-- 3. Creación de Tablas

CREATE TABLE public.app_meta (
    key TEXT PRIMARY KEY,
    value JSONB
);

CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.price_list_items (
    price_list_id UUID REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL,
    volume_price NUMERIC(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.sales_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name TEXT NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    fiscal_status TEXT,
    status public.client_status NOT NULL,
    onboarding_token UUID NOT NULL UNIQUE,
    agreement_id UUID REFERENCES public.agreements(id) ON DELETE SET NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(id),
    agreement_id UUID NOT NULL REFERENCES public.agreements(id),
    total_amount NUMERIC(10, 2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    quantity INTEGER NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL
);

CREATE TABLE public.agreement_promotions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id UUID NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id UUID NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- 4. Vistas y Funciones

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions as_cond WHERE as_cond.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) as month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') as active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '2 days')) as overdue_orders_count;


CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE (pending_orders_count INT, pending_clients_count INT, overdue_orders_count INT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::INT FROM public.orders WHERE status = 'pending'),
        (SELECT COUNT(*)::INT FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*)::INT FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '2 days'));
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
DECLARE
    current_value numeric;
BEGIN
    -- Obtener el valor actual
    SELECT (value->>'total_revenue')::numeric INTO current_value FROM app_meta WHERE key = 'legacy_stats';
    
    -- Si no existe, inicializar
    IF current_value IS NULL THEN
        current_value := 0;
    END IF;
    
    -- Incrementar el valor
    current_value := current_value + amount_to_add;
    
    -- Actualizar o insertar el registro
    INSERT INTO app_meta (key, value)
    VALUES ('legacy_stats', jsonb_build_object('total_revenue', current_value))
    ON CONFLICT (key) DO UPDATE
    SET value = jsonb_set(app_meta.value, '{total_revenue}', to_jsonb(current_value));
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COUNT(o.id) AS total_orders,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;


-- 5. Row-Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;

-- 6. Políticas de RLS
-- Permitir acceso total al 'service_role' para bypassear RLS en el backend
CREATE POLICY "Allow all for service role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.app_meta FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Permitir acceso de lectura a todos en tablas que no contienen información sensible
CREATE POLICY "Allow public read access on products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access on promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access on sales_conditions" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read access on price_lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access on price_list_items" ON public.price_list_items FOR SELECT USING (true);

-- Políticas para usuarios autenticados (administradores)
CREATE POLICY "Allow authenticated users full access on products" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on agreements" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on promotions" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Políticas para acceso anónimo (página de pedido, onboarding)
CREATE POLICY "Allow anonymous insert on orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous insert on order_items" ON public.order_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous read access on agreements for order page" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access on clients for onboarding" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow anonymous update on clients for onboarding" ON public.clients FOR UPDATE USING (onboarding_token IS NOT NULL) WITH CHECK (onboarding_token IS NOT NULL);

-- 7. Políticas de Almacenamiento (Storage)
DROP POLICY IF EXISTS "Allow public read access on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin full access to product_images" ON storage.objects;

CREATE POLICY "Allow public read access on product_images" ON storage.objects
FOR SELECT
USING (bucket_id = 'product_images');

CREATE POLICY "Allow admin full access to product_images" ON storage.objects
FOR ALL
USING (bucket_id = 'product_images' AND auth.role() = 'authenticated')
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
