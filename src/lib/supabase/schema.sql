
-- =============================================
-- Guía de Uso:
-- Este script es idempotente, lo que significa que
-- puedes ejecutarlo de forma segura en cualquier momento.
-- Se encargará de limpiar y reconfigurar las tablas
-- y funciones para que coincidan con el estado
-- actual de la aplicación.
--
-- Para usarlo:
-- 1. Copia todo el contenido de este archivo.
-- 2. Pégalo en el "SQL Editor" de tu panel de Supabase.
-- 3. Haz clic en "RUN".
-- =============================================


-- --- BORRADO DE OBJETOS ANTIGUOS (para asegurar idempotencia) ---
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;

DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;


-- --- CREACIÓN DE TABLAS ---

-- Tabla de Productos
CREATE TABLE public.products (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "base_price" numeric NOT NULL CHECK (base_price >= 0),
    "category" text,
    "stock" integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL UNIQUE,
    "prices_include_vat" boolean DEFAULT true NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "agreement_name" text NOT NULL UNIQUE,
    "client_type" text NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    "price_list_id" uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Ítems de una Lista de Precios (Tabla Pivote)
CREATE TABLE public.price_list_items (
    "price_list_id" uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    "price" numeric NOT NULL CHECK (price >= 0),
    "volume_price" numeric CHECK (volume_price >= 0),
    "created_at" timestamptz DEFAULT now() NOT NULL,
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Clientes
CREATE TABLE public.clients (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "cuit" text UNIQUE,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text UNIQUE,
    "instagram" text,
    "status" text NOT NULL DEFAULT 'pending_onboarding' CHECK (status IN ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    "onboarding_token" uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    "agreement_id" uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Promociones por Convenio (Tabla Pivote)
CREATE TABLE public.agreement_promotions (
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    "promotion_id" uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Condiciones de Venta por Convenio (Tabla Pivote)
CREATE TABLE public.agreement_sales_conditions (
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    "sales_condition_id" uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "client_id" uuid REFERENCES public.clients(id),
    "agreement_id" uuid REFERENCES public.agreements(id),
    "client_name_cache" text,
    "total_amount" numeric NOT NULL,
    "status" text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Ítems de un Pedido
CREATE TABLE public.order_items (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "order_id" uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    "product_id" uuid REFERENCES public.products(id) ON DELETE SET NULL,
    "quantity" integer NOT NULL,
    "price_per_unit" numeric NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);


-- --- SEED DATA (datos de ejemplo para empezar) ---

-- Insertar productos de ejemplo
INSERT INTO public.products (name, description, base_price, stock, category) VALUES
('Cera para Peinar "Efecto Mate"', 'Cera de alta fijación con acabado mate natural. Contenido: 100g.', 12500, 100, 'Ceras'),
('Pomada "Brillo Clásico"', 'Pomada a base de agua con fijación media y alto brillo. Contenido: 100g.', 12000, 80, 'Ceras'),
('Polvo de Volumen "Textura Instantánea"', 'Polvo voluminizador para un look con textura y sin peso. Contenido: 20g.', 10500, 150, 'Fijadores'),
('Shampoo "Limpieza Profunda" con Carbón Activado', 'Shampoo para eliminar impurezas y exceso de grasa. Contenido: 350ml.', 9800, 120, 'Cuidado Capilar'),
('Acondicionador "Hidratación Intensa" con Keratina', 'Acondicionador para restaurar la suavidad y el brillo. Contenido: 350ml.', 9800, 120, 'Cuidado Capilar'),
('Aceite para Barba "Leñador"', 'Mezcla de aceites naturales para hidratar barba y piel. Aroma amaderado. Contenido: 30ml.', 8500, 200, 'Cuidado de Barba'),
('Bálsamo para Barba "Control y Suavidad"', 'Bálsamo para modelar y suavizar la barba. Contenido: 60g.', 9200, 90, 'Cuidado de Barba'),
('Tónico Capilar "Anti-Caída" con Biotina', 'Tónico para fortalecer el folículo y prevenir la caída. Contenido: 150ml.', 15000, 70, 'Tratamientos'),
('Spray Fijador "Fuerza Extrema"', 'Spray de máxima duración para peinados que desafían la gravedad. Contenido: 250ml.', 11500, 100, 'Fijadores');

-- Insertar listas de precios de ejemplo
INSERT INTO public.price_lists (name, prices_include_vat) VALUES
('Lista General Barberías 2024', true),
('Lista Distribuidores Mayoristas', false);

-- Insertar promociones de ejemplo
INSERT INTO public.promotions (name, description, rules) VALUES
('Promo Lanzamiento Ceras', 'Llevando 8 ceras o pomadas, te llevas 2 de regalo.', '{"buy": 8, "get": 2, "type": "buy_x_get_y_free"}'),
('Envío Gratis CABA', 'Envío sin cargo en Capital Federal para compras de 12 o más unidades.', '{"min_units": 12, "locations": ["CABA"], "type": "free_shipping"}');

-- --- CREACIÓN DE VISTAS (para simplificar consultas) ---

-- Vista para obtener convenios con contadores
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = a.id) as sales_condition_count
FROM
    public.agreements a;


-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') as active_clients;


-- --- CREACIÓN DE FUNCIONES (para lógica de negocio en la DB) ---

-- Función para obtener estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COUNT(id) AS total_orders,
        COALESCE(AVG(total_amount), 0) AS average_order_value
    FROM
        public.orders
    WHERE
        client_id = p_client_id AND status = 'completed';
$$;


-- Función para incrementar los ingresos totales de forma segura
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Esta es una forma de ejemplo, en una app real podría ser más complejo.
    -- La idea es evitar race conditions si dos pedidos se completan al mismo tiempo.
    -- Por ahora, no tenemos una tabla de `stats`, así que esta función es conceptual.
    -- En el futuro, podría actualizar una tabla pre-agregada.
    -- UPDATE public.stats SET total_revenue = total_revenue + amount_to_add;
END;
$$;


-- --- Habilitar Real-Time (si es necesario en el futuro) ---
-- alter publication supabase_realtime add table products, agreements, clients;

-- --- Políticas de Seguridad (RLS) ---
-- Habilitar RLS para todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;


-- Políticas para acceso PÚBLICO (lectura)
-- Cualquier persona puede leer los datos necesarios para una página de pedido.
CREATE POLICY "Public read access for order pages" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Public read access for order pages" ON public.products FOR SELECT USING (true);
CREATE POLICY "Public read access for order pages" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Public read access for order pages" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Public read access for order pages" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Public read access for order pages" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Public read access for order pages" ON public.clients FOR SELECT USING (true);

-- Políticas para que los usuarios (clientes) puedan crear pedidos y sus items
-- Se asume que no hay "usuarios logueados" en el sentido tradicional, así que es anónimo.
CREATE POLICY "Allow anonymous order creation" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous order item creation" ON public.order_items FOR INSERT WITH CHECK (true);

-- Políticas para acceso de ADMINISTRADORES (autenticados)
-- Solo los usuarios con el rol `authenticated` pueden realizar todas las operaciones.
CREATE POLICY "Allow admin full access" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated');

-- Los admins pueden leer y actualizar pedidos
CREATE POLICY "Allow admin read/update access to orders" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin read access to order items" ON public.order_items FOR SELECT USING (auth.role() = 'authenticated');
