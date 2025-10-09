-- ----------------------------------------------------------------
-- 1. EXTENSIONS
-- ----------------------------------------------------------------
-- Habilitar la extensión pgcrypto para generar UUIDs
create extension if not exists pgcrypto with schema extensions;


-- ----------------------------------------------------------------
-- 2. TIPOS DE DATOS PERSONALIZADOS (ENUMS)
-- ----------------------------------------------------------------

-- Tipo para el estado de un cliente
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_status') THEN
        CREATE TYPE public.client_status AS ENUM (
            'pending_onboarding',
            'pending_agreement',
            'active'
        );
    END IF;
END$$;

-- Tipo para el tipo de cliente en un convenio
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_type') THEN
        CREATE TYPE public.client_type AS ENUM (
            'barberia',
            'distribuidor',
            'especial'
        );
    END IF;
END$$;


-- ----------------------------------------------------------------
-- 3. TABLAS
-- ----------------------------------------------------------------

-- Tabla de Productos
CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    base_price real DEFAULT 0 NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    category text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Tabla de Listas de Precios
CREATE TABLE IF NOT EXISTS public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;

-- Tabla de Convenios
CREATE TABLE IF NOT EXISTS public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type DEFAULT 'barberia'::public.client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid
);
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;

-- Tabla de Clientes
CREATE TABLE IF NOT EXISTS public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;


-- Tabla de Promociones
CREATE TABLE IF NOT EXISTS public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;


-- ----------------------------------------------------------------
-- 4. TABLAS DE UNIÓN (PIVOT TABLES)
-- ----------------------------------------------------------------

-- Unión entre Listas de Precios y Productos
CREATE TABLE IF NOT EXISTS public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price real NOT NULL,
    volume_price real,
    PRIMARY KEY (price_list_id, product_id)
);
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;

-- Unión entre Convenios y Promociones
CREATE TABLE IF NOT EXISTS public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;


-- ----------------------------------------------------------------
-- 5. CLAVES FORÁNEAS (RELACIONES)
-- ----------------------------------------------------------------

-- Relación: Convenio -> Lista de Precios
ALTER TABLE public.agreements DROP CONSTRAINT IF EXISTS agreements_price_list_id_fkey;
ALTER TABLE public.agreements ADD CONSTRAINT agreements_price_list_id_fkey 
    FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL;

-- Relación: Cliente -> Convenio
ALTER TABLE public.clients DROP CONSTRAINT IF EXISTS clients_agreement_id_fkey;
ALTER TABLE public.clients ADD CONSTRAINT clients_agreement_id_fkey 
    FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL;

-- Relación: Item de Lista de Precio -> Lista de Precio
ALTER TABLE public.price_list_items DROP CONSTRAINT IF EXISTS price_list_items_price_list_id_fkey;
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_price_list_id_fkey
    FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE;

-- Relación: Item de Lista de Precio -> Producto
ALTER TABLE public.price_list_items DROP CONSTRAINT IF EXISTS price_list_items_product_id_fkey;
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_product_id_fkey
    FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

-- Relación: Promoción de Convenio -> Convenio
ALTER TABLE public.agreement_promotions DROP CONSTRAINT IF EXISTS agreement_promotions_agreement_id_fkey;
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_agreement_id_fkey
    FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;

-- Relación: Promoción de Convenio -> Promoción
ALTER TABLE public.agreement_promotions DROP CONSTRAINT IF EXISTS agreement_promotions_promotion_id_fkey;
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_promotion_id_fkey
    FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE;


-- ----------------------------------------------------------------
-- 6. POLÍTICAS DE SEGURIDAD DE NIVEL DE FILA (RLS)
-- ----------------------------------------------------------------

-- Función helper para verificar rol de autenticado
CREATE OR REPLACE FUNCTION is_authenticated()
RETURNS boolean AS $$
BEGIN
    RETURN (auth.role() = 'authenticated');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --- Políticas para 'products' ---
DROP POLICY IF EXISTS "Los usuarios autenticados pueden ver y gestionar productos" ON public.products;
CREATE POLICY "Los usuarios autenticados pueden ver y gestionar productos" ON public.products
    FOR ALL USING (is_authenticated());

-- --- Políticas para 'price_lists' ---
DROP POLICY IF EXISTS "Los usuarios autenticados pueden ver y gestionar listas de precios" ON public.price_lists;
CREATE POLICY "Los usuarios autenticados pueden ver y gestionar listas de precios" ON public.price_lists
    FOR ALL USING (is_authenticated());

-- --- Políticas para 'price_list_items' ---
DROP POLICY IF EXISTS "Los usuarios autenticados pueden gestionar items de listas" ON public.price_list_items;
CREATE POLICY "Los usuarios autenticados pueden gestionar items de listas" ON public.price_list_items
    FOR ALL USING (is_authenticated());

-- --- Políticas para 'agreements' ---
DROP POLICY IF EXISTS "Cualquiera puede ver convenios (para página de pedido)" ON public.agreements;
CREATE POLICY "Cualquiera puede ver convenios (para página de pedido)" ON public.agreements
    FOR SELECT USING (true);
    
DROP POLICY IF EXISTS "Usuarios autenticados pueden gestionar convenios" ON public.agreements;
CREATE POLICY "Usuarios autenticados pueden gestionar convenios" ON public.agreements
    FOR (INSERT, UPDATE, DELETE) USING (is_authenticated());

-- --- Políticas para 'agreement_promotions' ---
DROP POLICY IF EXISTS "Cualquiera puede ver las promociones de un convenio" ON public.agreement_promotions;
CREATE POLICY "Cualquiera puede ver las promociones de un convenio" ON public.agreement_promotions
    FOR SELECT USING (true);
    
DROP POLICY IF EXISTS "Usuarios autenticados pueden gestionar promociones de convenios" ON public.agreement_promotions;
CREATE POLICY "Usuarios autenticados pueden gestionar promociones de convenios" ON public.agreement_promotions
    FOR (INSERT, UPDATE, DELETE) USING (is_authenticated());
    
-- --- Políticas para 'clients' ---
DROP POLICY IF EXISTS "Cualquiera puede ver datos de cliente por token de onboarding" ON public.clients;
CREATE POLICY "Cualquiera puede ver datos de cliente por token de onboarding" ON public.clients
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Los nuevos clientes pueden actualizar sus propios datos" ON public.clients;
CREATE POLICY "Los nuevos clientes pueden actualizar sus propios datos" ON public.clients
    FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Los usuarios autenticados pueden gestionar clientes" ON public.clients;
CREATE POLICY "Los usuarios autenticados pueden gestionar clientes" ON public.clients
    FOR ALL USING (is_authenticated());

-- --- Políticas para 'promotions' ---
DROP POLICY IF EXISTS "Cualquiera puede ver promociones" ON public.promotions;
CREATE POLICY "Cualquiera puede ver promociones" ON public.promotions
    FOR SELECT USING (true);
    
DROP POLICY IF EXISTS "Usuarios autenticados pueden gestionar promociones" ON public.promotions;
CREATE POLICY "Usuarios autenticados pueden gestionar promociones" ON public.promotions
    FOR (INSERT, UPDATE, DELETE) USING (is_authenticated());
    
-- ----------------------------------------------------------------
-- 7. VISTAS (VIEWS)
-- ----------------------------------------------------------------
-- (Actualmente no se usan vistas, pero se podrían agregar aquí en el futuro si es necesario)
-- ----------------------------------------------------------------

-- Finalización del script
