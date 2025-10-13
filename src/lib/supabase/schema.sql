
-- Versión del Esquema: 5
-- Descripción: Script SQL idempotente para crear la estructura completa de la DB de Blonde Orders.

-- --- LIMPIEZA INICIAL ---
-- Borra las tablas existentes en el orden correcto para evitar errores de dependencia.
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.dashboard_stats;

-- --- TABLAS PRINCIPALES ---

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    description text,
    base_price numeric(10, 2) DEFAULT 0.00 NOT NULL,
    category character varying,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT products_base_price_check CHECK ((base_price >= (0)::numeric))
);
ALTER TABLE public.products ADD CONSTRAINT products_pkey PRIMARY KEY (id);
ALTER TABLE public.products ADD CONSTRAINT products_name_key UNIQUE (name);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.price_lists ADD CONSTRAINT price_lists_pkey PRIMARY KEY (id);
ALTER TABLE public.price_lists ADD CONSTRAINT price_lists_name_key UNIQUE (name);


-- Tabla de Ítems de la Lista de Precios (tabla pivot)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric(10, 2) NOT NULL,
    volume_price numeric(10, 2),
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT price_list_items_price_check CHECK ((price > (0)::numeric)),
    CONSTRAINT price_list_items_volume_price_check CHECK (((volume_price IS NULL) OR (volume_price > (0)::numeric)))
);
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id);
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE;
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_name character varying NOT NULL,
    client_type character varying DEFAULT 'barberia'::character varying NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    price_list_id uuid
);
ALTER TABLE public.agreements ADD CONSTRAINT agreements_pkey PRIMARY KEY (id);
ALTER TABLE public.agreements ADD CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name);
ALTER TABLE public.agreements ADD CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL;
ALTER TABLE public.agreements ADD CONSTRAINT agreements_client_type_check CHECK (((client_type)::text = ANY ((ARRAY['barberia'::character varying, 'distribuidor'::character varying, 'especial'::character varying])::text[])));


-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cuit character varying,
    contact_name character varying,
    contact_dni character varying,
    address character varying,
    delivery_window character varying,
    email character varying,
    instagram character varying,
    status character varying DEFAULT 'pending_onboarding'::character varying NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_id uuid,
    created_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.clients ADD CONSTRAINT clients_pkey PRIMARY KEY (id);
ALTER TABLE public.clients ADD CONSTRAINT clients_cuit_key UNIQUE (cuit);
ALTER TABLE public.clients ADD CONSTRAINT clients_email_key UNIQUE (email);
ALTER TABLE public.clients ADD CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token);
ALTER TABLE public.clients ADD CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL;
ALTER TABLE public.clients ADD CONSTRAINT clients_status_check CHECK (((status)::text = ANY ((ARRAY['pending_onboarding'::character varying, 'pending_agreement'::character varying, 'active'::character varying, 'archived'::character varying])::text[])));


-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.promotions ADD CONSTRAINT promotions_pkey PRIMARY KEY (id);


-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.sales_conditions ADD CONSTRAINT sales_conditions_pkey PRIMARY KEY (id);


-- Tabla de Convenios y Promociones (pivot)
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL
);
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id);
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE;


-- Tabla de Convenios y Condiciones de Venta (pivot)
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL
);
ALTER TABLE public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id);
ALTER TABLE public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;
ALTER TABLE public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions(id) ON DELETE CASCADE;


-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    client_name_cache character varying NOT NULL
);
ALTER TABLE public.orders ADD CONSTRAINT orders_pkey PRIMARY KEY (id);
ALTER TABLE public.orders ADD CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE RESTRICT;
ALTER TABLE public.orders ADD CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'completed'::character varying])::text[])));


-- Tabla de Ítems del Pedido
CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);
ALTER TABLE public.order_items ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
ALTER TABLE public.order_items ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);
ALTER TABLE public.order_items ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
ALTER TABLE public.order_items ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;
ALTER TABLE public.order_items ADD CONSTRAINT order_items_quantity_check CHECK ((quantity > 0));


-- Tabla para Estadísticas del Dashboard (pre-agregada)
CREATE TABLE public.dashboard_stats (
    id integer PRIMARY KEY,
    total_revenue numeric(12, 2) DEFAULT 0.00 NOT NULL,
    month_revenue numeric(12, 2) DEFAULT 0.00 NOT NULL,
    active_clients integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_dashboard_stats CHECK (id = 1)
);
-- Insertar la fila única para las estadísticas
INSERT INTO public.dashboard_stats (id) VALUES (1);


-- --- VISTAS ---

-- Vista para contar promociones y condiciones por convenio
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;


-- --- FUNCIONES RPC ---

-- Función para obtener estadísticas de un cliente específico
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
        client_id = p_client_id
        AND status = 'completed';
$$;

-- Función para incrementar los ingresos totales de forma segura
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE sql
AS $$
    UPDATE public.dashboard_stats
    SET total_revenue = total_revenue + amount_to_add
    WHERE id = 1;
$$;
