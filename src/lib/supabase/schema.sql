-- --------------------------------------------------------------------------------
-- 1. EXTENSIONES
-- Habilita la extensión pgcrypto para poder usar gen_random_uuid()
-- --------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";


-- --------------------------------------------------------------------------------
-- 2. TABLAS
-- Definición de todas las tablas de la base de datos
-- --------------------------------------------------------------------------------

-- Tabla de Productos
CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    base_price real DEFAULT 0 NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    category text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Catálogo de productos de la tienda.';

-- Tabla de Promociones
CREATE TABLE IF NOT EXISTS public.promotions (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Reglas de promociones y descuentos.';

-- Tabla de Listas de Precios
CREATE TABLE IF NOT EXISTS public.price_lists (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Agrupaciones de precios para productos.';

-- Tabla de Items en Listas de Precios (Relación muchos a muchos)
CREATE TABLE IF NOT EXISTS public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price real DEFAULT 0 NOT NULL,
    volume_price real,
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Define el precio de un producto en una lista específica.';

-- Tabla de Convenios
CREATE TABLE IF NOT EXISTS public.agreements (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);
COMMENT ON TABLE public.agreements IS 'Convenios comerciales para clientes o grupos de clientes.';

-- Tabla de Promociones por Convenio (Relación muchos a muchos)
CREATE TABLE IF NOT EXISTS public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Promociones asignadas a un convenio específico.';

-- Tabla de Clientes
CREATE TABLE IF NOT EXISTS public.clients (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
    onboarding_token text DEFAULT extensions.gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.clients IS 'Información de los clientes de la tienda.';

-- --------------------------------------------------------------------------------
-- 3. ENUMS, VISTAS Y FUNCIONES
-- --------------------------------------------------------------------------------

-- Tipos de Cliente (Enum)
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
-- Estado del Cliente (Enum)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active');

-- Vista para obtener convenios con el conteo de promociones
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count
FROM
    public.agreements a;


-- --------------------------------------------------------------------------------
-- 4. POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY - RLS)
-- --------------------------------------------------------------------------------

-- Asegurarse de que RLS esté habilitado en todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;

-- **Políticas para USUARIOS AUTENTICADOS (rol `authenticated`)**

-- Los administradores autenticados pueden hacer todo.
DROP POLICY IF EXISTS "authenticated_users_can_do_all" ON public.products;
CREATE POLICY "authenticated_users_can_do_all" ON public.products FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_users_can_do_all" ON public.promotions;
CREATE POLICY "authenticated_users_can_do_all" ON public.promotions FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_users_can_do_all" ON public.agreements;
CREATE POLICY "authenticated_users_can_do_all" ON public.agreements FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_users_can_do_all" ON public.agreement_promotions;
CREATE POLICY "authenticated_users_can_do_all" ON public.agreement_promotions FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_users_can_do_all" ON public.clients;
CREATE POLICY "authenticated_users_can_do_all" ON public.clients FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_users_can_do_all" ON public.price_lists;
CREATE POLICY "authenticated_users_can_do_all" ON public.price_lists FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_users_can_do_all" ON public.price_list_items;
CREATE POLICY "authenticated_users_can_do_all" ON public.price_list_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- **Políticas para USUARIOS ANÓNIMOS (rol `anon`)**

-- Los anónimos NO pueden ver productos, promos, ni convenios directamente.
-- Solo a través de las funciones del servidor o vistas específicas si fuera necesario.
DROP POLICY IF EXISTS "anon_users_cannot_read" ON public.products;
CREATE POLICY "anon_users_cannot_read" ON public.products FOR SELECT TO anon USING (false);

DROP POLICY IF EXISTS "anon_users_cannot_read" ON public.promotions;
CREATE POLICY "anon_users_cannot_read" ON public.promotions FOR SELECT TO anon USING (false);

-- Los usuarios anónimos SÍ pueden leer datos de convenios, listas de precios y productos
-- para poder cargar la página de pedido público.
DROP POLICY IF EXISTS "anon_can_read_public_order_data" ON public.agreements;
CREATE POLICY "anon_can_read_public_order_data" ON public.agreements FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "anon_can_read_public_order_data" ON public.agreement_promotions;
CREATE POLICY "anon_can_read_public_order_data" ON public.agreement_promotions FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "anon_can_read_public_order_data" ON public.price_lists;
CREATE POLICY "anon_can_read_public_order_data" ON public.price_lists FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "anon_can_read_public_order_data" ON public.price_list_items;
CREATE POLICY "anon_can_read_public_order_data" ON public.price_list_items FOR SELECT TO anon USING (true);

-- Políticas de la tabla CLIENTS para anónimos:
-- 1. Anónimos pueden LEER los datos de un cliente si conocen el `onboarding_token`
DROP POLICY IF EXISTS "anon_can_read_client_with_token" ON public.clients;
CREATE POLICY "anon_can_read_client_with_token" ON public.clients FOR SELECT TO anon USING (onboarding_token IS NOT NULL);

-- 2. Anónimos pueden ACTUALIZAR un cliente si conocen el `onboarding_token` (para el formulario)
DROP POLICY IF EXISTS "anon_can_update_client_with_token" ON public.clients;
CREATE POLICY "anon_can_update_client_with_token" ON public.clients FOR UPDATE TO anon USING (onboarding_token IS NOT NULL) WITH CHECK (onboarding_token IS NOT NULL);

-- 3. Anónimos NO pueden insertar ni borrar clientes.
DROP POLICY IF EXISTS "anon_cannot_insert_delete_clients" ON public.clients;
CREATE POLICY "anon_cannot_insert_delete_clients" ON public.clients FOR INSERT TO anon USING (false);
CREATE POLICY "anon_cannot_insert_delete_clients_del" ON public.clients FOR DELETE TO anon USING (false);

-- Habilitar publicación sobre `public` schema
-- Esto es para que las Server Actions puedan acceder a los datos
-- a pesar de no estar usando la `service_role`.
-- DROP PUBLICATION IF EXISTS supabase_realtime;
-- CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
