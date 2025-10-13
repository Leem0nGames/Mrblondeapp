-- ----------------------------
-- Habilita la extensión pgcrypto si no está habilitada
-- ----------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "public";


-- ----------------------------
-- Tabla: products
-- ----------------------------
DROP TABLE IF EXISTS "public"."products";
CREATE TABLE "public"."products" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" text NOT NULL,
  "description" text,
  "base_price" numeric(10,2) NOT NULL DEFAULT 0,
  "category" text,
  "created_at" timestamptz (6) NOT NULL DEFAULT now()
)
;
ALTER TABLE "public"."products" OWNER TO "postgres";
ALTER TABLE "public"."products" ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");


-- ----------------------------
-- Tabla: promotions
-- ----------------------------
DROP TABLE IF EXISTS "public"."promotions";
CREATE TABLE "public"."promotions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" text NOT NULL,
  "description" text,
  "rules" jsonb,
  "created_at" timestamptz (6) NOT NULL DEFAULT now()
)
;
ALTER TABLE "public"."promotions" OWNER TO "postgres";
ALTER TABLE "public"."promotions" ADD CONSTRAINT "promotions_pkey" PRIMARY KEY ("id");


-- ----------------------------
-- Tabla: sales_conditions
-- ----------------------------
DROP TABLE IF EXISTS "public"."sales_conditions";
CREATE TABLE "public"."sales_conditions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" text NOT NULL,
  "description" text,
  "rules" jsonb,
  "created_at" timestamptz (6) NOT NULL DEFAULT now()
)
;
ALTER TABLE "public"."sales_conditions" OWNER TO "postgres";
ALTER TABLE "public"."sales_conditions" ADD CONSTRAINT "sales_conditions_pkey" PRIMARY KEY ("id");


-- ----------------------------
-- Tabla: price_lists
-- ----------------------------
DROP TABLE IF EXISTS "public"."price_lists";
CREATE TABLE "public"."price_lists" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" text NOT NULL,
  "prices_include_vat" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz (6) NOT NULL DEFAULT now()
)
;
ALTER TABLE "public"."price_lists" OWNER TO "postgres";
ALTER TABLE "public"."price_lists" ADD CONSTRAINT "price_lists_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."price_lists" ADD CONSTRAINT "price_lists_name_key" UNIQUE ("name");


-- ----------------------------
-- Tabla: price_list_items
-- ----------------------------
DROP TABLE IF EXISTS "public"."price_list_items";
CREATE TABLE "public"."price_list_items" (
  "price_list_id" uuid NOT NULL,
  "product_id" uuid NOT NULL,
  "price" numeric(10,2) NOT NULL,
  "volume_price" numeric(10,2),
  "created_at" timestamptz (6) NOT NULL DEFAULT now()
)
;
ALTER TABLE "public"."price_list_items" OWNER TO "postgres";
ALTER TABLE "public"."price_list_items" ADD CONSTRAINT "price_list_items_pkey" PRIMARY KEY ("price_list_id", "product_id");
ALTER TABLE "public"."price_list_items" ADD CONSTRAINT "price_list_items_price_list_id_fkey" FOREIGN KEY ("price_list_id") REFERENCES "public"."price_lists" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "public"."price_list_items" ADD CONSTRAINT "price_list_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;


-- ----------------------------
-- Tabla: agreements
-- ----------------------------
DROP TABLE IF EXISTS "public"."agreements";
CREATE TABLE "public"."agreements" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "agreement_name" text NOT NULL,
  "client_type" text NOT NULL,
  "created_at" timestamptz (6) NOT NULL DEFAULT now(),
  "price_list_id" uuid
)
;
ALTER TABLE "public"."agreements" OWNER TO "postgres";
ALTER TABLE "public"."agreements" ADD CONSTRAINT "agreements_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."agreements" ADD CONSTRAINT "agreements_price_list_id_fkey" FOREIGN KEY ("price_list_id") REFERENCES "public"."price_lists" ("id") ON DELETE SET NULL ON UPDATE NO ACTION;
ALTER TABLE "public"."agreements" ADD CONSTRAINT "agreements_agreement_name_key" UNIQUE ("agreement_name");


-- ----------------------------
-- Tabla: agreement_promotions
-- ----------------------------
DROP TABLE IF EXISTS "public"."agreement_promotions";
CREATE TABLE "public"."agreement_promotions" (
  "agreement_id" uuid NOT NULL,
  "promotion_id" uuid NOT NULL,
  "created_at" timestamptz (6) NOT NULL DEFAULT now()
)
;
ALTER TABLE "public"."agreement_promotions" OWNER TO "postgres";
ALTER TABLE "public"."agreement_promotions" ADD CONSTRAINT "agreement_promotions_pkey" PRIMARY KEY ("agreement_id", "promotion_id");
ALTER TABLE "public"."agreement_promotions" ADD CONSTRAINT "agreement_promotions_agreement_id_fkey" FOREIGN KEY ("agreement_id") REFERENCES "public"."agreements" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "public"."agreement_promotions" ADD CONSTRAINT "agreement_promotions_promotion_id_fkey" FOREIGN KEY ("promotion_id") REFERENCES "public"."promotions" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;


-- ----------------------------
-- Tabla: agreement_sales_conditions
-- ----------------------------
DROP TABLE IF EXISTS "public"."agreement_sales_conditions";
CREATE TABLE "public"."agreement_sales_conditions" (
  "agreement_id" uuid NOT NULL,
  "sales_condition_id" uuid NOT NULL,
  "created_at" timestamptz (6) NOT NULL DEFAULT now()
)
;
ALTER TABLE "public"."agreement_sales_conditions" OWNER TO "postgres";
ALTER TABLE "public"."agreement_sales_conditions" ADD CONSTRAINT "agreement_sales_conditions_pkey" PRIMARY KEY ("agreement_id", "sales_condition_id");
ALTER TABLE "public"."agreement_sales_conditions" ADD CONSTRAINT "agreement_sales_conditions_agreement_id_fkey" FOREIGN KEY ("agreement_id") REFERENCES "public"."agreements" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "public"."agreement_sales_conditions" ADD CONSTRAINT "agreement_sales_conditions_sales_condition_id_fkey" FOREIGN KEY ("sales_condition_id") REFERENCES "public"."sales_conditions" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;


-- ----------------------------
-- Tabla: clients
-- ----------------------------
DROP TABLE IF EXISTS "public"."clients";
CREATE TABLE "public"."clients" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "cuit" text,
  "contact_name" text,
  "contact_dni" text,
  "address" text,
  "delivery_window" text,
  "email" text,
  "instagram" text,
  "status" text NOT NULL DEFAULT 'pending_onboarding'::text,
  "onboarding_token" uuid NOT NULL DEFAULT gen_random_uuid(),
  "agreement_id" uuid,
  "created_at" timestamptz (6) NOT NULL DEFAULT now()
)
;
ALTER TABLE "public"."clients" OWNER TO "postgres";
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_agreement_id_fkey" FOREIGN KEY ("agreement_id") REFERENCES "public"."agreements" ("id") ON DELETE SET NULL ON UPDATE NO ACTION;
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_onboarding_token_key" UNIQUE ("onboarding_token");
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_cuit_key" UNIQUE ("cuit");
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_email_key" UNIQUE ("email");


-- ----------------------------
-- Tabla: orders
-- ----------------------------
DROP TABLE IF EXISTS "public"."orders";
CREATE TABLE "public"."orders" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "client_id" uuid NOT NULL,
  "agreement_id" uuid NOT NULL,
  "created_at" timestamptz (6) NOT NULL DEFAULT now(),
  "total_amount" numeric(10,2) NOT NULL,
  "status" text NOT NULL DEFAULT 'pending'::text,
  "client_name_cache" text NOT NULL
)
;
ALTER TABLE "public"."orders" OWNER TO "postgres";
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_agreement_id_fkey" FOREIGN KEY ("agreement_id") REFERENCES "public"."agreements" ("id") ON DELETE RESTRICT ON UPDATE NO ACTION;
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients" ("id") ON DELETE RESTRICT ON UPDATE NO ACTION;


-- ----------------------------
-- Tabla: order_items
-- ----------------------------
DROP TABLE IF EXISTS "public"."order_items";
CREATE TABLE "public"."order_items" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "order_id" uuid NOT NULL,
  "product_id" uuid NOT NULL,
  "quantity" int4 NOT NULL,
  "price_per_unit" numeric(10,2) NOT NULL
)
;
ALTER TABLE "public"."order_items" OWNER TO "postgres";
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES