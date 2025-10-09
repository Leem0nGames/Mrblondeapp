-- Nota: Este script es idempotente. Puedes ejecutarlo múltiples veces sin causar errores.

-- 1. Tipos Enum
CREATE TYPE client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active');
CREATE TYPE promotion_type AS ENUM ('buy_x_get_y_free', 'free_shipping');

-- 2. Tabla de Productos
CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    base_price numeric(10,2) DEFAULT 0.00 NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    category character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT products_stock_check CHECK ((stock >= 0))
);
-- Habilitar RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
-- Políticas RLS para products
DROP POLICY IF EXISTS "Los usuarios autenticados pueden ver productos" ON public.products;
CREATE POLICY "Los usuarios autenticados pueden ver productos" ON public.products FOR SELECT USING (true);
DROP POLICY IF EXISTS "Los administradores pueden gestionar productos" ON public.products;
CREATE POLICY "Los administradores pueden gestionar productos" ON public.products FOR ALL USING (auth.role() = 'authenticated');


-- 3. Tabla de Listas de Precios
CREATE TABLE IF NOT EXISTS public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
-- Habilitar RLS
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
-- Políticas RLS para price_lists
DROP POLICY IF EXISTS "Los usuarios pueden ver listas de precios" ON public.price_lists;
CREATE POLICY "Los usuarios pueden ver listas de precios" ON public.price_lists FOR SELECT USING (true);
DROP POLICY IF EXISTS "Los administradores pueden gestionar listas de precios" ON public.price_lists;
CREATE POLICY "Los administradores pueden gestionar listas de precios" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');


-- 4. Tabla de Items de Listas de Precios (Tabla Pivote)
CREATE TABLE IF NOT EXISTS public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10,2) NOT NULL,
    volume_price numeric(10,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (price_list_id, product_id)
);
-- Habilitar RLS
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
-- Políticas RLS para price_list_items
DROP POLICY IF EXISTS "Los usuarios pueden ver items de listas de precios" ON public.price_list_items;
CREATE POLICY "Los usuarios pueden ver items de listas de precios" ON public.price_list_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "Los administradores pueden gestionar items de listas de precios" ON public.price_list_items;
CREATE POLICY "Los administradores pueden gestionar items de listas de precios" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');


-- 5. Tabla de Convenios
CREATE TABLE IF NOT EXISTS public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name character varying NOT NULL UNIQUE,
    client_type client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid,
    CONSTRAINT fk_price_list FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL
);
-- Habilitar RLS
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
-- Políticas RLS para agreements
DROP POLICY IF EXISTS "Los usuarios pueden ver convenios" ON public.agreements;
CREATE POLICY "Los usuarios pueden ver convenios" ON public.agreements FOR SELECT USING (true);
DROP POLICY IF EXISTS "Los administradores pueden gestionar convenios" ON public.agreements;
CREATE POLICY "Los administradores pueden gestionar convenios" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');


-- 6. Tabla de Promociones
CREATE TABLE IF NOT EXISTS public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
-- Habilitar RLS
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
-- Políticas RLS para promotions
DROP POLICY IF EXISTS "Los usuarios pueden ver promociones" ON public.promotions;
CREATE POLICY "Los usuarios pueden ver promociones" ON public.promotions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Los administradores pueden gestionar promociones" ON public.promotions;
CREATE POLICY "Los administradores pueden gestionar promociones" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');


-- 7. Tabla de Convenios y Promociones (Tabla Pivote)
CREATE TABLE IF NOT EXISTS public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);
-- Habilitar RLS
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
-- Políticas RLS para agreement_promotions
DROP POLICY IF EXISTS "Los usuarios pueden ver las promociones de un convenio" ON public.agreement_promotions;
CREATE POLICY "Los usuarios pueden ver las promociones de un convenio" ON public.agreement_promotions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Los administradores pueden gestionar las promociones de un convenio" ON public.agreement_promotions;
CREATE POLICY "Los administradores pueden gestionar las promociones de un convenio" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');


-- 8. Tabla de Clientes
CREATE TABLE IF NOT EXISTS public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    cuit character varying(11) UNIQUE,
    contact_name text,
    contact_dni character varying(8),
    address text,
    delivery_window text,
    email character varying UNIQUE,
    instagram character varying,
    status client_status DEFAULT 'pending_onboarding'::client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
-- Habilitar RLS
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
-- Políticas RLS para clients
DROP POLICY IF EXISTS "Los usuarios autenticados pueden ver clientes" ON public.clients;
CREATE POLICY "Los usuarios autenticados pueden ver clientes" ON public.clients FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Cualquiera puede completar su propio formulario de onboarding" ON public.clients;
CREATE POLICY "Cualquiera puede completar su propio formulario de onboarding" ON public.clients FOR UPDATE USING (onboarding_token = (select nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'onboarding_token')::uuid) WITH CHECK (onboarding_token = (select nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'onboarding_token')::uuid);
DROP POLICY IF EXISTS "Los administradores pueden gestionar clientes" ON public.clients;
CREATE POLICY "Los administradores pueden gestionar clientes" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Cualquiera puede ver su propio registro de cliente por token" ON public.clients;
CREATE POLICY "Cualquiera puede ver su propio registro de cliente por token" ON public.clients FOR SELECT USING (onboarding_token = (select nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'onboarding_token')::uuid);
