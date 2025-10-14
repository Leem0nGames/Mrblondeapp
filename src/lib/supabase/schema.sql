
-- 1. Eliminar todo en orden inverso para evitar problemas de dependencias
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);

-- 2. Crear las tablas

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text NULL,
    category character varying NULL,
    image_url text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT products_pkey PRIMARY KEY (id)
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT price_lists_pkey PRIMARY KEY (id),
    CONSTRAINT price_lists_name_key UNIQUE (name)
);
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;

-- Tabla de Items de Listas de Precios
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric NOT NULL,
    volume_price numeric NULL,
    CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE,
    CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE
);
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_name character varying NOT NULL,
    client_type public.client_type NOT NULL,
    price_list_id uuid NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT agreements_pkey PRIMARY KEY (id),
    CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name),
    CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL
);
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    cuit character varying NULL,
    contact_name character varying NULL,
    contact_dni character varying NULL,
    address character varying NULL,
    delivery_window text NULL,
    email character varying NULL,
    instagram character varying NULL,
    status public.client_status NOT NULL DEFAULT 'pending_onboarding'::public.client_status,
    onboarding_token uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status character varying NULL,
    CONSTRAINT clients_pkey PRIMARY KEY (id),
    CONSTRAINT clients_cuit_key UNIQUE (cuit),
    CONSTRAINT clients_email_key UNIQUE (email),
    CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token),
    CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL
);
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL DEFAULT 'pending'::public.order_status,
    client_name_cache character varying NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT orders_pkey PRIMARY KEY (id),
    CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id),
    CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id)
);
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Tabla de Items de Pedidos
CREATE TABLE public.order_items (
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL,
    CONSTRAINT order_items_pkey PRIMARY KEY (order_id, product_id),
    CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE,
    CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT
);
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text NULL,
    rules jsonb NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT promotions_pkey PRIMARY KEY (id)
);
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;

-- Tabla de Union Convenios-Promociones
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL,
    CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id),
    CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE
);
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text NULL,
    rules jsonb NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT sales_conditions_pkey PRIMARY KEY (id)
);
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;

-- Tabla de Union Convenios-Condiciones de Venta
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL,
    CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id),
    CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions(id) ON DELETE CASCADE
);
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;

-- Tabla para Estadísticas del Dashboard
CREATE TABLE public.dashboard_stats (
    id integer NOT NULL PRIMARY KEY DEFAULT 1,
    total_revenue numeric NOT NULL DEFAULT 0,
    month_revenue numeric NOT NULL DEFAULT 0,
    active_clients integer NOT NULL DEFAULT 0,
    CONSTRAINT single_row_check CHECK (id = 1)
);
ALTER TABLE public.dashboard_stats ENABLE ROW LEVEL SECURITY;
INSERT INTO public.dashboard_stats (id, total_revenue, month_revenue, active_clients) VALUES (1, 0, 0, 0) ON CONFLICT(id) DO NOTHING;


-- 3. Crear Vistas y Funciones

-- Vista para convenios con contadores
CREATE OR REPLACE VIEW public.agreements_with_counts AS
 SELECT a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) as sales_condition_count,
    pl.name AS price_list_name
   FROM public.agreements a
     LEFT JOIN public.price_lists pl ON a.price_list_id = pl.id;

-- Función para estadísticas de cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        COUNT(id) as total_orders
    FROM
        public.orders
    WHERE
        client_id = p_client_id AND status = 'completed';
$$;

-- Función para incrementar ingresos
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.dashboard_stats
    SET total_revenue = total_revenue + amount_to_add
    WHERE id = 1;
END;
$$;


-- 4. Policies (RLS)

-- Políticas permisivas para tablas públicas (lectura)
CREATE POLICY "Allow public read access to products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access to pricelists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access to pricelist items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access to promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreement promotions" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to sales conditions" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreement sales conditions" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to clients" ON public.clients FOR SELECT USING (true);

-- Políticas de escritura para rol "authenticated"
CREATE POLICY "Allow insert/update for authenticated users" ON public.clients
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON public.products
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON public.price_lists
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON public.price_list_items
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON public.agreements
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON public.promotions
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON public.agreement_promotions
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON public.sales_conditions
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON public.agreement_sales_conditions
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Políticas para pedidos
CREATE POLICY "Allow users to create their own orders" ON public.orders
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL); -- Cualquiera puede insertar si no es anónimo

CREATE POLICY "Allow authenticated users to manage orders" ON public.orders
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow users to create order items" ON public.order_items
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Allow authenticated users to manage order items" ON public.order_items
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Políticas para el dashboard
CREATE POLICY "Allow authenticated users to read dashboard stats" ON public.dashboard_stats
FOR SELECT USING (auth.role() = 'authenticated');


-- 5. Storage

-- Create a bucket for product images.
-- This is a one-time operation, so we check if it exists first.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'product_images') THEN
        INSERT INTO storage.buckets (id, name, public)
        VALUES ('product_images', 'product_images', true);
    END IF;
END $$;


-- Set up Row Level Security policies for the 'product_images' bucket.
-- Allow public read access.
CREATE POLICY "Allow public read access to product images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

-- Allow authenticated users to insert, update, and delete their own images.
CREATE POLICY "Allow authenticated users to manage product images"
ON storage.objects FOR ALL
USING ( auth.role() = 'authenticated' )
WITH CHECK ( auth.role() = 'authenticated' );
