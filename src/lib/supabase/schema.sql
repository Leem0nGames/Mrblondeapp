-- =================================================================
-- ==                                                           ==
-- ==                 ¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡                ==
-- ==                 !      ¡ADVERTENCIA!      !                ==
-- ==                 ¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡¡                ==
-- ==                                                           ==
-- == Este script BORRA Y RECREA las tablas. Ejecutarlo          ==
-- == eliminará TODOS los datos existentes en las tablas        ==
-- == afectadas. Úsalo solo si estás seguro de que quieres      ==
-- == empezar desde un esquema limpio.                           ==
-- ==                                                           ==
-- =================================================================

-- Desactiva las notificaciones para no saturar la salida
SET client_min_messages TO WARNING;

-- Elimina las tablas existentes si ya existen para evitar errores
-- El uso de CASCADE elimina también cualquier objeto que dependa de ellas (vistas, etc.)
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.revenue CASCADE;

-- Elimina los tipos personalizados si existen
DROP TYPE IF EXISTS public.client_status;


-- ===============================
-- ==          TIPOS          ==
-- ===============================

-- Define el tipo ENUM para el estado del cliente
CREATE TYPE public.client_status AS ENUM (
    'pending_onboarding', -- El cliente fue creado por el admin, pero aún no completó sus datos
    'pending_agreement',  -- El cliente completó sus datos, pero no tiene un convenio asignado
    'active',             -- El cliente está activo y puede hacer pedidos
    'archived'            -- El cliente fue archivado y no aparecerá en las listas principales
);


-- ===============================
-- ==          TABLAS           ==
-- ===============================

-- Tabla de Productos
-- Almacena el catálogo de todos los productos disponibles.
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    category character varying,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Catálogo de todos los productos disponibles.';

-- Tabla de Listas de Precios
-- Almacena diferentes listas de precios que se pueden asignar a los convenios.
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Define listas de precios reutilizables.';

-- Tabla de Items en Listas de Precios
-- Tabla pivote que conecta productos a listas de precios con un precio específico.
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10,2) NOT NULL,
    volume_price numeric(10,2),
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Define el precio de un producto dentro de una lista de precios.';

-- Tabla de Promociones
-- Define las promociones disponibles, como "compre X, lleve Y gratis".
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Define promociones y sus reglas.';

-- Tabla de Condiciones de Venta
-- Define condiciones comerciales como plazos de pago, descuentos, etc.
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Define condiciones comerciales (plazos, descuentos).';

-- Tabla de Convenios
-- El núcleo del sistema. Un convenio vincula un tipo de cliente, una lista de precios y promociones.
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name character varying NOT NULL UNIQUE,
    client_type character varying NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.agreements IS 'Vincula un tipo de cliente, una lista de precios y promociones.';

-- Tabla de Clientes
-- Almacena la información de los clientes (barberías, distribuidores).
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    cuit character varying UNIQUE,
    contact_name character varying,
    contact_dni character varying,
    address text,
    delivery_window text,
    email character varying UNIQUE,
    instagram character varying,
    fiscal_status character varying,
    latitude double precision,
    longitude double precision,
    status public.client_status DEFAULT 'pending_onboarding' NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.clients IS 'Información de los clientes y su estado.';

-- Asignar el agreement_id a la tabla de clientes después de que ambas tablas existan
ALTER TABLE public.clients ADD CONSTRAINT fk_agreement
    FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL;


-- Tabla Pivote: Convenios y Promociones
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Asigna promociones a los convenios.';

-- Tabla Pivote: Convenios y Condiciones de Venta
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Asigna condiciones de venta a los convenios.';


-- Tabla de Pedidos
-- Almacena los pedidos realizados por los clientes.
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    client_name_cache character varying NOT NULL,
    notes text
);
COMMENT ON TABLE public.orders IS 'Almacena los pedidos realizados por los clientes.';


-- Tabla de Items de Pedido
-- Almacena los productos específicos y las cantidades para cada pedido.
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.order_items IS 'Detalle de productos en cada pedido.';


-- Tabla de Ingresos (para estadísticas)
CREATE TABLE public.revenue (
    id integer PRIMARY KEY,
    total_revenue numeric(15, 2) DEFAULT 0 NOT NULL
);
COMMENT ON TABLE public.revenue IS 'Almacena métricas de ingresos para el dashboard.';

-- Inserta una única fila para el seguimiento de los ingresos totales
INSERT INTO public.revenue (id, total_revenue) VALUES (1, 0)
ON CONFLICT (id) DO NOTHING;


-- ===============================
-- ==           VISTAS          ==
-- ===============================

-- Vista para obtener convenios con el conteo de promociones y condiciones de venta
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;


-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT total_revenue FROM public.revenue WHERE id = 1) AS total_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT sum(total_amount) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue;


-- ===============================
-- ==   FUNCIONES Y TRIGGERS    ==
-- ===============================

-- Función para incrementar los ingresos totales
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.revenue
    SET total_revenue = total_revenue + amount_to_add
    WHERE id = 1;
END;
$$;
COMMENT ON FUNCTION public.increment_total_revenue IS 'Actualiza el contador de ingresos totales.';


-- Función para obtener las estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric)
LANGUAGE sql
STABLE
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COALESCE(COUNT(id), 0) AS total_orders,
        COALESCE(AVG(total_amount), 0) AS average_order_value
    FROM
        public.orders
    WHERE
        client_id = p_client_id AND status = 'completed';
$$;
COMMENT ON FUNCTION public.get_client_stats IS 'Calcula las estadísticas clave para un cliente específico.';

-- Función para obtener pedidos vencidos (basado en la condición de venta 'net_days')
CREATE OR REPLACE FUNCTION public.get_overdue_orders()
RETURNS SETOF public.orders
LANGUAGE sql
STABLE
AS $$
    SELECT o.*
    FROM public.orders o
    JOIN public.agreement_sales_conditions asc_join ON o.agreement_id = asc_join.agreement_id
    JOIN public.sales_conditions sc ON asc_join.sales_condition_id = sc.id
    WHERE o.status = 'completed'
      AND sc.rules ->> 'type' = 'net_days'
      AND o.created_at < (NOW() - CAST(sc.rules ->> 'days' AS INTEGER) * INTERVAL '1 day');
$$;
COMMENT ON FUNCTION public.get_overdue_orders IS 'Obtiene los pedidos cuyo plazo de pago ha vencido.';


-- ===============================
-- ==           SEGURIDAD         ==
-- ===============================

-- Activa RLS para todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue ENABLE ROW LEVEL SECURITY;

-- Políticas para permitir la lectura pública en algunas tablas (si es necesario)
-- Por defecto, se deniega el acceso. Las políticas específicas se definen a continuación.

-- Permite a CUALQUIERA leer la información necesaria para la página de pedido
CREATE POLICY "Allow public read access for order page"
ON public.agreements
FOR SELECT USING (true);

CREATE POLICY "Allow public read access for order page"
ON public.price_lists
FOR SELECT USING (true);

CREATE POLICY "Allow public read access for order page"
ON public.price_list_items
FOR SELECT USING (true);

CREATE POLICY "Allow public read access for order page"
ON public.products
FOR SELECT USING (true);

CREATE POLICY "Allow public read access for order page"
ON public.promotions
FOR SELECT USING (true);

CREATE POLICY "Allow public read access for order page"
ON public.agreement_promotions
FOR SELECT USING (true);

CREATE POLICY "Allow public read for client identification"
ON public.clients
FOR SELECT USING (true);

-- Permite la creación de pedidos (submitOrder) a cualquier usuario
CREATE POLICY "Allow anyone to insert an order"
ON public.orders
FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anyone to insert order items"
ON public.order_items
FOR INSERT WITH CHECK (true);


-- Permite a los usuarios autenticados (administradores) realizar cualquier operación
CREATE POLICY "Allow all operations for authenticated users"
ON public.products
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all operations for authenticated users"
ON public.price_lists
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all operations for authenticated users"
ON public.price_list_items
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all operations for authenticated users"
ON public.promotions
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all operations for authenticated users"
ON public.sales_conditions
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all operations for authenticated users"
ON public.agreements
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all operations for authenticated users"
ON public.agreement_promotions
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all operations for authenticated users"
ON public.agreement_sales_conditions
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users"
ON public.clients
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all ops for authenticated users"
ON public.orders
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow all ops for authenticated users"
ON public.order_items
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow read access to revenue for authenticated users"
ON public.revenue
FOR SELECT
USING (auth.role() = 'authenticated');


-- Políticas para el almacenamiento (product_images)
-- Asume que el bucket se llama 'product_images'

-- Permite la visualización pública de imágenes
CREATE POLICY "Public read access for product images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

-- Permite a los usuarios autenticados (administradores) subir, modificar y eliminar imágenes
CREATE POLICY "Allow authenticated users to manage product images"
ON storage.objects FOR ALL
USING ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

-- Reactiva las notificaciones
SET client_min_messages TO NOTICE;
