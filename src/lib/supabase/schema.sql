-- ----------------------------
-- BLONDE ORDERS - SUPABASE SCHEMA
-- ----------------------------

-- ----------------------------
-- 1. EXTENSIONS
-- ----------------------------
-- Habilita la extensión pgcrypto si no está habilitada
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


-- ----------------------------
-- 2. TABLAS
-- ----------------------------

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    description text,
    base_price real DEFAULT 0 NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    category text
);
ALTER TABLE public.products OWNER TO postgres;
ALTER TABLE ONLY public.products ADD CONSTRAINT products_pkey PRIMARY KEY (id);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    description text,
    rules jsonb
);
ALTER TABLE public.promotions OWNER TO postgres;
ALTER TABLE ONLY public.promotions ADD CONSTRAINT promotions_pkey PRIMARY KEY (id);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.price_lists OWNER TO postgres;
ALTER TABLE ONLY public.price_lists ADD CONSTRAINT price_lists_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.price_lists ADD CONSTRAINT price_lists_name_key UNIQUE (name);

-- Tabla de Items en Listas de Precios (Tabla Pivote)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price real NOT NULL,
    volume_price real -- Precio especial para compras por volumen (ej: >150 unidades)
);
ALTER TABLE public.price_list_items OWNER TO postgres;
ALTER TABLE ONLY public.price_list_items ADD CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id);
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE;
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_name text NOT NULL,
    client_type public.client_type_enum NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid -- Referencia a la lista de precios
);
ALTER TABLE public.agreements OWNER TO postgres;
ALTER TABLE ONLY public.agreements ADD CONSTRAINT agreements_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.agreements ADD CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name);
ALTER TABLE public.agreements ADD CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL;


-- Tabla de Promociones por Convenio (Tabla Pivote)
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL
);
ALTER TABLE public.agreement_promotions OWNER TO postgres;
ALTER TABLE ONLY public.agreement_promotions ADD CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id);
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE;


-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    cuit text,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text,
    instagram text,
    status public.client_status_enum DEFAULT 'pending_onboarding'::public.client_status_enum NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_id uuid
);
ALTER TABLE public.clients OWNER TO postgres;
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_cuit_key UNIQUE (cuit);
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_email_key UNIQUE (email);
ALTER TABLE ONLY public.clients ADD CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token);
ALTER TABLE public.clients ADD CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL;


-- ----------------------------
-- 3. ENUMS
-- ----------------------------
CREATE TYPE public.client_type_enum AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active');

-- ----------------------------
-- 4. POLÍTICAS DE SEGURIDAD (RLS)
-- ----------------------------
-- Habilitar RLS en todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;


-- Políticas para products
-- Permitir lectura a todos, pero escritura solo a usuarios autenticados (admins)
DROP POLICY IF EXISTS "Allow read access to everyone" ON public.products;
CREATE POLICY "Allow read access to everyone" ON public.products FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow authenticated users to manage products" ON public.products;
CREATE POLICY "Allow authenticated users to manage products" ON public.products FOR ALL USING (auth.role() = 'authenticated');

-- Políticas para promotions
-- Permitir lectura a todos, pero escritura solo a usuarios autenticados (admins)
DROP POLICY IF EXISTS "Allow read access to everyone" ON public.promotions;
CREATE POLICY "Allow read access to everyone" ON public.promotions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow authenticated users to manage promotions" ON public.promotions;
CREATE POLICY "Allow authenticated users to manage promotions" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');

-- Políticas para price_lists
-- Solo los usuarios autenticados (admins) pueden gestionar listas de precios
DROP POLICY IF EXISTS "Allow authenticated users to manage price lists" ON public.price_lists;
CREATE POLICY "Allow authenticated users to manage price lists" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Allow public read access to price lists" ON public.price_lists;
CREATE POLICY "Allow public read access to price lists" ON public.price_lists FOR SELECT USING (true);


-- Políticas para price_list_items
-- Solo los usuarios autenticados (admins) pueden gestionar los items
DROP POLICY IF EXISTS "Allow authenticated users to manage price list items" ON public.price_list_items;
CREATE POLICY "Allow authenticated users to manage price list items" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Allow public read access to price list items" ON public.price_list_items;
CREATE POLICY "Allow public read access to price list items" ON public.price_list_items FOR SELECT USING (true);


-- Políticas para agreements
-- Permitir lectura a todos, pero escritura solo a usuarios autenticados (admins)
DROP POLICY IF EXISTS "Allow read access to everyone" ON public.agreements;
CREATE POLICY "Allow read access to everyone" ON public.agreements FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow authenticated users to manage agreements" ON public.agreements;
CREATE POLICY "Allow authenticated users to manage agreements" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');


-- Políticas para agreement_promotions
-- Permitir lectura a todos, pero escritura solo a usuarios autenticados (admins)
DROP POLICY IF EXISTS "Allow read access to everyone" ON public.agreement_promotions;
CREATE POLICY "Allow read access to everyone" ON public.agreement_promotions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow authenticated users to manage agreement promotions" ON public.agreement_promotions;
CREATE POLICY "Allow authenticated users to manage agreement promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');


-- Políticas para clients
-- Permitir lectura y escritura a admins. Permitir actualización a usuarios anónimos si tienen el token correcto.
DROP POLICY IF EXISTS "Allow authenticated users to manage clients" ON public.clients;
CREATE POLICY "Allow authenticated users to manage clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Allow anonymous user to read their own data via token" ON public.clients;
CREATE POLICY "Allow anonymous user to read their own data via token" ON public.clients FOR SELECT USING ((current_setting('request.jwt.claims', true)::jsonb ->> 'token') = onboarding_token::text);
DROP POLICY IF EXISTS "Allow anonymous user to update their own data" ON public.clients;
CREATE POLICY "Allow anonymous user to update their own data" ON public.clients FOR UPDATE USING (onboarding_token::text = (current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token'));


-- Deshabilitar RLS para el rol de servicio (usado en el backend)
ALTER TABLE public.products BYPASS ROW LEVEL SECURITY;
ALTER TABLE public.promotions BYPASS ROW LEVEL SECURITY;
ALTER TABLE public.price_lists BYPASS ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items BYPASS ROW LEVEL SECURITY;
ALTER TABLE public.agreements BYPASS ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions BYPASS ROW LEVEL SECURITY;
ALTER TABLE public.clients BYPASS ROW LEVEL SECURITY;
