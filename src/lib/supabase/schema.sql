
-- =================================================================
--  Blonde Orders - Supabase Schema
--  Idempotent Script: Puedes ejecutarlo de forma segura en cualquier
--  momento para resetear la DB a este estado.
-- =================================================================


-- --- Drop existing objects ---
-- Dropa todas las tablas en el orden correcto para evitar errores de FK.
DROP TABLE IF EXISTS "public"."order_items" CASCADE;
DROP TABLE IF EXISTS "public"."orders" CASCADE;
DROP TABLE IF EXISTS "public"."agreement_promotions" CASCADE;
DROP TABLE IF EXISTS "public"."agreement_sales_conditions" CASCADE;
DROP TABLE IF EXISTS "public"."clients" CASCADE;
DROP TABLE IF EXISTS "public"."agreements" CASCADE;
DROP TABLE IF EXISTS "public"."price_list_items" CASCADE;
DROP TABLE IF EXISTS "public"."price_lists" CASCADE;
DROP TABLE IF EXISTS "public"."promotions" CASCADE;
DROP TABLE IF EXISTS "public"."sales_conditions" CASCADE;
DROP TABLE IF EXISTS "public"."products" CASCADE;
DROP VIEW IF EXISTS "public"."agreements_with_counts";
DROP VIEW IF EXISTS "public"."dashboard_stats";
DROP FUNCTION IF EXISTS "public"."get_client_stats";
DROP FUNCTION IF EXISTS "public"."increment_total_revenue";


-- --- Tables ---

-- 1. products
-- Almacena el catálogo de productos base.
CREATE TABLE products (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "base_price" numeric NOT NULL,
    "category" text,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;

-- 2. price_lists
-- Contiene diferentes listas de precios que se pueden asignar a los convenios.
CREATE TABLE price_lists (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL UNIQUE,
    "prices_include_vat" boolean DEFAULT true NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE "public"."price_lists" ENABLE ROW LEVEL SECURITY;


-- 3. price_list_items
-- Tabla pivote que define el precio de un producto para una lista de precios específica.
CREATE TABLE price_list_items (
    "price_list_id" uuid NOT NULL REFERENCES price_lists(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    "price" numeric NOT NULL,
    "volume_price" numeric,
    PRIMARY KEY (price_list_id, product_id)
);
ALTER TABLE "public"."price_list_items" ENABLE ROW LEVEL SECURITY;


-- 4. promotions
-- Define las promociones disponibles, como "compre X, lleve Y gratis".
CREATE TABLE promotions (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL UNIQUE,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE "public"."promotions" ENABLE ROW LEVEL SECURITY;

-- 5. sales_conditions
-- Define condiciones comerciales como plazos de pago, descuentos, etc.
CREATE TABLE sales_conditions (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL UNIQUE,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE "public"."sales_conditions" ENABLE ROW LEVEL SECURITY;


-- 6. agreements
-- Define un convenio que agrupa un tipo de cliente, una lista de precios y promociones.
CREATE TABLE agreements (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "agreement_name" text NOT NULL UNIQUE,
    "client_type" text NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    "price_list_id" uuid REFERENCES price_lists(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE "public"."agreements" ENABLE ROW LEVEL SECURITY;


-- 7. agreement_promotions
-- Tabla pivote para asignar N promociones a N convenios.
CREATE TABLE agreement_promotions (
    "agreement_id" uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    "promotion_id" uuid NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
ALTER TABLE "public"."agreement_promotions" ENABLE ROW LEVEL SECURITY;


-- 8. agreement_sales_conditions
-- Tabla pivote para asignar N condiciones de venta a N convenios.
CREATE TABLE agreement_sales_conditions (
    "agreement_id" uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    "sales_condition_id" uuid NOT NULL REFERENCES sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
ALTER TABLE "public"."agreement_sales_conditions" ENABLE ROW LEVEL SECURITY;


-- 9. clients
-- Almacena la información de los clientes.
CREATE TABLE clients (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "cuit" text UNIQUE,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text UNIQUE,
    "instagram" text,
    "status" text DEFAULT 'pending_onboarding' NOT NULL CHECK (status IN ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    "onboarding_token" uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    "agreement_id" uuid REFERENCES agreements(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE "public"."clients" ENABLE ROW LEVEL SECURITY;

-- 10. orders
-- Guarda un registro de los pedidos realizados.
CREATE TABLE orders (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "client_id" uuid NOT NULL REFERENCES clients(id),
    "agreement_id" uuid NOT NULL REFERENCES agreements(id),
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "total_amount" numeric NOT NULL,
    "status" text DEFAULT 'pending'::text NOT NULL,
    "client_name_cache" text
);
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;

-- 11. order_items
-- Guarda los productos específicos de cada pedido.
CREATE TABLE order_items (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "order_id" uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES products(id),
    "quantity" integer NOT NULL,
    "price_per_unit" numeric NOT NULL
);
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


-- --- Views ---

-- 1. agreements_with_counts
-- Una vista que facilita obtener los convenios con el conteo de sus promociones y condiciones.
CREATE VIEW agreements_with_counts AS
SELECT 
    a.*,
    (SELECT COUNT(*) FROM agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT COUNT(*) FROM agreement_sales_conditions asc WHERE asc.agreement_id = a.id) as sales_condition_count
FROM agreements a;

-- 2. dashboard_stats
-- Una vista simplificada para las estadísticas del dashboard.
CREATE VIEW dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT COUNT(*) FROM clients WHERE status = 'active') as active_clients;

-- --- Functions ---

-- 1. get_client_stats
-- Función para obtener las estadísticas de un cliente específico.
CREATE OR REPLACE FUNCTION get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COUNT(o.id) AS total_orders,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value
    FROM
        orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$;


-- 2. increment_total_revenue
-- Función para manejar el incremento de ingresos de forma atómica.
-- (Actualmente no se usa porque la vista `dashboard_stats` lo calcula,
-- pero es una buena práctica tenerla para futuras optimizaciones).
CREATE OR REPLACE FUNCTION increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- This function would be more complex in a real-world scenario,
    -- likely updating a dedicated stats table.
    -- For now, it does nothing as the view handles the calculation.
END;
$$;

-- --- SEED DATA ---

-- Insertar Productos
INSERT INTO products (name, description, base_price, category) VALUES
('Cera Polvo "Styling Dust"', 'Cera en polvo para un peinado con volumen y textura mate.', 2500.00, 'Ceras'),
('Cera "Matte Clay"', 'Cera de arcilla para un acabado mate y fijación fuerte.', 2800.00, 'Ceras'),
('Shampoo "Tea Tree"', 'Shampoo refrescante con aceite de árbol de té.', 3500.00, 'Cuidado Capilar'),
('Acondicionador "Mint"', 'Acondicionador con extracto de menta para una sensación fresca.', 3500.00, 'Cuidado Capilar'),
('Aceite para Barba "Woodsman"', 'Aceite nutritivo para barba con aroma amaderado.', 2200.00, 'Cuidado de Barba'),
('Bálsamo para Barba "Citrus"', 'Bálsamo para modelar la barba con notas cítricas.', 2300.00, 'Cuidado de Barba');

-- Insertar Listas de Precios
INSERT INTO price_lists (id, name, prices_include_vat) VALUES
('8a1b5cb1-4435-43a0-b5e1-5a3d7d4e3a21', 'Precios Barberías 2024', true),
('f2c6d4a9-848a-48a1-9f9e-3d7a8e7b9e3a', 'Precios Distribuidores 2024', false);

-- Insertar Promociones
INSERT INTO promotions (name, description, rules) VALUES
('Promo 8+2', 'Llevando 8 unidades de cualquier producto, te regalamos 2.', '{"buy": 8, "get": 2, "type": "buy_x_get_y_free"}'),
('Envío Gratis CABA', 'Envío sin cargo para pedidos de 12 o más unidades a CABA.', '{"min_units": 12, "locations": ["CABA"], "type": "free_shipping"}');

-- Insertar Condiciones de Venta
INSERT INTO sales_conditions (name, description, rules) VALUES
('Pago a 30 Días', 'Plazo de pago de 30 días desde la fecha de factura.', '{"days": 30, "type": "net_days"}'),
('Descuento 5% Contado', '5% de descuento por pago al contado.', '{"percentage": 5, "type": "discount"}');


-- --- RLS Policies ---
-- Deshabilitadas por defecto para simplicidad del MVP.
-- En una aplicación real, se habilitarían políticas estrictas.
-- Ejemplo:
-- CREATE POLICY "Allow read access to all users" ON "public"."products"
-- AS PERMISSIVE FOR SELECT
-- TO public
-- USING (true);
ra de 30 volúmenes para aclaraciones más potentes.', 5500, 300, 'Coloración'),
('Tijera de Corte 5.5"', 'Tijera de acero japonés para corte de precisión. Filo navaja.', 45000, 40, 'Herramientas'),
('Navaja de Afeitar Clásica', 'Navaja de barbero con hojas intercambiables. Mango de madera.', 35000, 60, 'Herramientas'),
('Capa de Corte Premium', 'Capa de corte de tela impermeable y antiestática. Cierre ajustable.', 18000, 70, 'Accesorios');
