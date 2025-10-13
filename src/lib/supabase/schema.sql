
-- 1. Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    description text,
    base_price real DEFAULT 0 NOT NULL,
    category text
);
ALTER TABLE public.products OWNER TO postgres;
ALTER TABLE ONLY public.products ADD CONSTRAINT products_pkey PRIMARY KEY (id);

-- 2. Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    prices_include_vat boolean DEFAULT true NOT NULL
);
ALTER TABLE public.price_lists OWNER TO postgres;
ALTER TABLE ONLY public.price_lists ADD CONSTRAINT price_lists_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.price_lists ADD CONSTRAINT price_lists_name_key UNIQUE (name);

-- 3. Tabla de Items de Listas de Precios (Tabla Pivote)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price real NOT NULL,
    volume_price real
);
ALTER TABLE public.price_list_items OWNER TO postgres;
ALTER TABLE ONLY public.price_list_items ADD CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id);
ALTER TABLE ONLY public.price_list_items ADD CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.price_list_items ADD CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

-- 4. Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_name text NOT NULL,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid
);
ALTER TABLE public.agreements OWNER TO postgres;
ALTER TABLE ONLY public.agreements ADD CONSTRAINT agreements_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.agreements ADD CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name);
ALTER TABLE ONLY public.agreements ADD CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL;


-- 5. Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.promotions OWNER TO postgres;
ALTER TABLE ONLY public.promotions ADD CONSTRAINT promotions_pkey PRIMARY KEY (id);

-- 6. Tabla de Convenios y Promociones (Pivote)
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL
);
ALTER TABLE public.agreement_promotions OWNER TO postgres;
ALTER TABLE ONLY public.agreement_promotions ADD CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id);
ALTER TABLE ONLY public.agreement_promotions ADD CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.agreement_promotions ADD CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE;

-- 7. Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    description text,
    rules jsonb
);
ALTER TABLE public.sales_conditions OWNER TO postgres;
ALTER TABLE ONLY public.sales_conditions ADD CONSTRAINT sales_conditions_pkey PRIMARY KEY (id);

-- 8. Tabla de Convenios y Condiciones de Venta (Pivote)
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL
);
ALTER TABLE public.agreement_sales_conditions OWNER TO postgres;
ALTER TABLE ONLY public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id);
ALTER TABLE ONLY public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions(id) ON DELETE CASCADE;

-- 9. Tabla de Clientes
CREATE TYPE public.client_status AS ENUM (
    'pending_onboarding',
    'pending_agreement',
    'active',
    'archived'
);
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cuit text,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text,
    instagram text,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.clients OWNER TO postgres;
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_cuit_key UNIQUE (cuit);
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_email_key UNIQUE (email);
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token);


-- 10. Tabla de Pedidos
CREATE TYPE public.order_status AS ENUM (
    'pending',
    'completed'
);
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount real NOT NULL,
    status public.order_status DEFAULT 'pending'::public.order_status NOT NULL,
    client_name_cache text NOT NULL
);
ALTER TABLE public.orders OWNER TO postgres;
ALTER TABLE ONLY public.orders ADD CONSTRAINT orders_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.orders ADD CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.orders ADD CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT;

-- 11. Tabla de Items de Pedido
CREATE TABLE public.order_items (
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit real NOT NULL
);
ALTER TABLE public.order_items OWNER TO postgres;
ALTER TABLE ONLY public.order_items ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_id, product_id);
ALTER TABLE ONLY public.order_items ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.order_items ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;

-- 12. Tabla de Estadísticas del Dashboard
CREATE TABLE public.dashboard_stats (
    id integer PRIMARY KEY,
    total_revenue real DEFAULT 0 NOT NULL,
    month_revenue real DEFAULT 0 NOT NULL,
    active_clients integer DEFAULT 0 NOT NULL,
    CONSTRAINT single_row_check CHECK (id = 1)
);
ALTER TABLE public.dashboard_stats OWNER TO postgres;
-- Insertar la única fila de estadísticas
INSERT INTO public.dashboard_stats (id) VALUES (1);

--
-- VISTAS (VIEWS)
--

-- Vista para convenios con conteo de promos y condiciones
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascnd WHERE ascnd.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;
ALTER TABLE public.agreements_with_counts OWNER TO postgres;


--
-- FUNCIONES (RPC)
--

-- Función para incrementar los ingresos totales en la tabla de estadísticas
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add real)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.dashboard_stats
    SET total_revenue = total_revenue + amount_to_add
    WHERE id = 1;
END;
$$;
ALTER FUNCTION public.increment_total_revenue(real) OWNER TO postgres;

-- Función para obtener estadísticas de un cliente específico
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent double precision, total_orders bigint, average_order_value double precision)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0.0)::double precision AS total_spent,
        COUNT(o.id)::bigint AS total_orders,
        COALESCE(AVG(o.total_amount), 0.0)::double precision AS average_order_value
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id
        AND o.status = 'completed';
END;
$$;
ALTER FUNCTION public.get_client_stats(uuid) OWNER TO postgres;
