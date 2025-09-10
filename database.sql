
-- Roles and Policies have been removed for simplicity in this MVP.
-- In a production environment, you should implement Row Level Security.

-- Drop existing tables in reverse order of dependency to avoid conflicts.
DROP TABLE IF EXISTS "public"."agreement_products";
DROP TABLE IF EXISTS "public"."agreement_promotions";
DROP TABLE IF EXISTS "public"."access_tokens"; -- This table is no longer needed.
DROP TABLE IF EXISTS "public"."agreements";
DROP TABLE IF EXISTS "public"."products";
DROP TABLE IF EXISTS "public"."promotions";


-- Create products table
CREATE TABLE "public"."products" (
    "id" UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "name" CHARACTER VARYING NOT NULL,
    "description" TEXT,
    "base_price" NUMERIC NOT NULL,
    "stock" INTEGER NOT NULL DEFAULT 0,
    "category" CHARACTER VARYING,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create promotions table
CREATE TABLE "public"."promotions" (
    "id" UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "name" CHARACTER VARYING NOT NULL,
    "description" TEXT,
    "rules" JSONB NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create agreements table with the new permanent link_token
CREATE TABLE "public"."agreements" (
    "id" UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "agreement_name" CHARACTER VARYING NOT NULL,
    "client_type" CHARACTER VARYING NOT NULL,
    "price_adjustment" NUMERIC NOT NULL DEFAULT 0,
    "link_token" UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE, -- The permanent, unique link token
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create agreement_products junction table
CREATE TABLE "public"."agreement_products" (
    "agreement_id" UUID NOT NULL REFERENCES "public"."agreements"(id) ON DELETE CASCADE,
    "product_id" UUID NOT NULL REFERENCES "public"."products"(id) ON DELETE CASCADE,
    "price" NUMERIC NOT NULL,
    PRIMARY KEY (agreement_id, product_id)
);

-- Create agreement_promotions junction table
CREATE TABLE "public"."agreement_promotions" (
    "agreement_id" UUID NOT NULL REFERENCES "public"."agreements"(id) ON DELETE CASCADE,
    "promotion_id" UUID NOT NULL REFERENCES "public"."promotions"(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Dummy Data for initial setup

-- Products
INSERT INTO "public"."products" (name, description, base_price, stock, category) VALUES
('Cera Modeladora "Matte Rock"', 'Fijación fuerte con acabado matte. Ideal para estilos definidos y con textura.', 12500, 50, 'Ceras'),
('Shampoo "Silver Blonde"', 'Neutraliza tonos amarillentos en cabellos rubios y grises. Limpieza profunda.', 15000, 30, 'Shampoos'),
('Aceite para Barba "Luxe Oil"', 'Hidrata y suaviza la barba y la piel. Mezcla de aceites de argán y jojoba.', 11000, 40, 'Barbería');

-- Promotions
INSERT INTO "public"."promotions" (name, description, rules) VALUES
('Promo Barberías 6+1', 'Comprando 6 unidades de cualquier producto, llevas 1 de regalo.', '{"type": "buy_x_get_y_free", "buy": 6, "get": 1, "scope": "any_product"}'),
('Descuento por Volumen (10+)', '10% de descuento en el total de la compra superando las 10 unidades.', '{"type": "total_discount_by_units", "min_units": 10, "discount_percentage": 10}'),
('Kit Silver', 'Llevando 1 Shampoo Silver y 1 Cera Matte, obtienes un 15% de descuento en ambos.', '{"type": "kit_discount", "products": ["Shampoo \"Silver Blonde\"", "Cera Modeladora \"Matte Rock\""], "discount_percentage": 15}');

-- Agreements
INSERT INTO "public"."agreements" (agreement_name, client_type, price_adjustment, link_token) VALUES
('Barberías CABA', 'barberia', -5, 'f47ac10b-58cc-4372-a567-0e02b2c3d479'),
('Distribuidores Premium', 'distribuidor', -15, '747ac10b-58cc-4372-a567-0e02b2c3d480');

-- Assign products and promotions to agreements
-- Barberías CABA
INSERT INTO "public"."agreement_products" (agreement_id, product_id, price)
SELECT a.id, p.id, p.base_price * 0.95
FROM agreements a, products p
WHERE a.agreement_name = 'Barberías CABA';

INSERT INTO "public"."agreement_promotions" (agreement_id, promotion_id)
SELECT a.id, promo.id
FROM agreements a, promotions promo
WHERE a.agreement_name = 'Barberías CABA' AND promo.name IN ('Promo Barberías 6+1', 'Descuento por Volumen (10+)');

-- Distribuidores Premium
INSERT INTO "public"."agreement_products" (agreement_id, product_id, price)
SELECT a.id, p.id, p.base_price * 0.85
FROM agreements a, products p
WHERE a.agreement_name = 'Distribuidores Premium';

INSERT INTO "public"."agreement_promotions" (agreement_id, promotion_id)
SELECT a.id, promo.id
FROM agreements a, promotions promo
WHERE a.agreement_name = 'Distribuidores Premium';

