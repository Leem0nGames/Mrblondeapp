
-- Versión: 2.0
-- Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura en cualquier momento.
-- Limpiará y reconfigurará la base de datos para que coincida con la aplicación.

-- 1. Desactivar la seguridad a nivel de fila temporalmente para poder eliminar
ALTER TABLE if exists public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE if exists public.promotions DISABLE ROW LEVEL SECURITY;
ALTER TABLE if exists public.agreements DISABLE ROW LEVEL SECURITY;
ALTER TABLE if exists public.clients DISABLE ROW LEVEL SECURITY;
ALTER TABLE if exists public.price_lists DISABLE ROW LEVEL SECURITY;

-- 2. Eliminar tablas existentes en el orden correcto de dependencia
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.dashboard_stats CASCADE;

-- 3. Eliminar vistas y funciones si existen
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP FUNCTION IF EXISTS public.get_client_stats(p_client_id uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(amount_to_add double precision);
DROP FUNCTION IF EXISTS public.update_dashboard_stats();


-- 4. Creación de Tablas

CREATE TABLE "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "base_price" numeric NOT NULL DEFAULT 0,
    "category" "text",
    "created_at" timestamptz DEFAULT "now"() NOT NULL
);
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX products_pkey ON public.products USING btree (id);
ALTER TABLE "public"."products" ADD CONSTRAINT "products_pkey" PRIMARY KEY USING INDEX "products_pkey";

CREATE TABLE "public"."promotions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "rules" "jsonb",
    "created_at" timestamptz DEFAULT "now"() NOT NULL
);
ALTER TABLE "public"."promotions" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX promotions_pkey ON public.promotions USING btree (id);
ALTER TABLE "public"."promotions" ADD CONSTRAINT "promotions_pkey" PRIMARY KEY USING INDEX "promotions_pkey";

CREATE TABLE "public"."sales_conditions" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE "public"."sales_conditions" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."price_lists" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL UNIQUE,
    "prices_include_vat" boolean NOT NULL DEFAULT true,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE "public"."price_lists" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."agreements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "agreement_name" "text" NOT NULL,
    "client_type" "text" NOT NULL,
    "created_at" timestamptz DEFAULT "now"() NOT NULL,
    "price_list_id" uuid,
    CONSTRAINT "agreements_agreement_name_key" UNIQUE ("agreement_name"),
    CONSTRAINT "agreements_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "agreements_price_list_id_fkey" FOREIGN KEY (price_list_id) REFERENCES price_lists(id) ON DELETE SET NULL
);
ALTER TABLE "public"."agreements" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."clients" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "cuit" text UNIQUE,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text UNIQUE,
    "instagram" text,
    "status" text DEFAULT 'pending_onboarding'::text NOT NULL,
    "onboarding_token" uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    "agreement_id" uuid,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT "clients_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "clients_agreement_id_fkey" FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE SET NULL
);
ALTER TABLE "public"."clients" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."price_list_items" (
    "price_list_id" uuid NOT NULL REFERENCES price_lists(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    "price" numeric NOT NULL,
    "volume_price" numeric,
    PRIMARY KEY (price_list_id, product_id)
);
ALTER TABLE "public"."price_list_items" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."agreement_promotions" (
    "agreement_id" "uuid" NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    "promotion_id" "uuid" NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
ALTER TABLE "public"."agreement_promotions" ENABLE ROW LEVEL SECURITY;


CREATE TABLE "public"."agreement_sales_conditions" (
    "agreement_id" uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    "sales_condition_id" uuid NOT NULL REFERENCES sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
ALTER TABLE "public"."agreement_sales_conditions" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."orders" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "client_id" uuid NOT NULL REFERENCES clients(id),
    "agreement_id" uuid NOT NULL REFERENCES agreements(id),
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "total_amount" numeric NOT NULL,
    "status" text DEFAULT 'pending'::text NOT NULL,
    "client_name_cache" text
);
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."order_items" (
    "id" bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    "order_id" uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES products(id),
    "quantity" integer NOT NULL,
    "price_per_unit" numeric NOT NULL
);
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."dashboard_stats" (
    "id" integer PRIMARY KEY DEFAULT 1,
    "total_revenue" numeric DEFAULT 0,
    "month_revenue" numeric DEFAULT 0,
    "active_clients" integer DEFAULT 0,
    CONSTRAINT dashboard_stats_id_check CHECK (id = 1)
);

-- 5. Creación de Políticas de Seguridad (RLS)

-- Los usuarios autenticados pueden leer todo
CREATE POLICY "Enable read access for authenticated users" ON "public"."products"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."promotions"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."agreements"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."clients"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."price_lists"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."price_list_items"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."agreement_promotions"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."sales_conditions"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."agreement_sales_conditions"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

-- Cualquiera puede leer los datos de un convenio para la página de pedido
CREATE POLICY "Enable public read access for order page" ON "public"."agreements"
AS PERMISSIVE FOR SELECT
TO public
USING (true);

-- Los usuarios autenticados pueden modificar todo
CREATE POLICY "Enable insert for authenticated users" ON "public"."products" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON "public"."products" FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Enable delete for authenticated users" ON "public"."products" FOR DELETE TO authenticated USING (true);

CREATE POLICY "Enable insert for authenticated users" ON "public"."promotions" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON "public"."promotions" FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Enable delete for authenticated users" ON "public"."promotions" FOR DELETE TO authenticated USING (true);

CREATE POLICY "Enable all actions for authenticated users on sales_conditions" ON "public"."sales_conditions"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Enable all actions for authenticated users on price_lists" ON "public"."price_lists"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Enable all actions for authenticated users on price_list_items" ON "public"."price_list_items"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Enable insert for authenticated users" ON "public"."agreements" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON "public"."agreements" FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Enable delete for authenticated users" ON "public"."agreements" FOR DELETE TO authenticated USING (true);

CREATE POLICY "Enable all actions for authenticated users on agreement_promotions" ON "public"."agreement_promotions"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Enable all actions for auth users on agreement_sales_conditions" ON "public"."agreement_sales_conditions"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Políticas para Clientes y Pedidos
CREATE POLICY "Enable insert for authenticated users on clients" ON "public"."clients" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users on clients" ON "public"."clients" FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Enable delete for authenticated users on clients" ON "public"."clients" FOR DELETE TO authenticated USING (true);
CREATE POLICY "Allow public read for onboarding" ON "public"."clients" FOR SELECT TO public USING (true);
CREATE POLICY "Allow public update for onboarding" ON "public"."clients" FOR UPDATE TO public USING (true);

CREATE POLICY "Allow all for authenticated users on orders" ON "public"."orders"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users on order_items" ON "public"."order_items"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);


-- 6. Funciones de Base de Datos (RPC)

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value,
        COUNT(o.id) AS total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id
        AND o.status = 'completed';
END;
$$;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- This ensures the dashboard_stats table has a row to update.
  INSERT INTO dashboard_stats (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
  
  UPDATE dashboard_stats
  SET total_revenue = total_revenue + amount_to_add
  WHERE id = 1;
END;
$$;


-- 7. Vista para contar promociones y condiciones por convenio
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
  a.id,
  a.agreement_name,
  a.client_type,
  a.created_at,
  a.price_list_id,
  (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
  (SELECT count(*) FROM public.agreement_sales_conditions asc_count WHERE asc_count.agreement_id = a.id) AS sales_condition_count
FROM
  public.agreements a;

-- 8. Inserts iniciales (si es necesario, por ejemplo para stats)
INSERT INTO public.dashboard_stats(id, total_revenue, month_revenue, active_clients)
VALUES (1, 0, 0, 0)
ON CONFLICT (id) DO NOTHING;
