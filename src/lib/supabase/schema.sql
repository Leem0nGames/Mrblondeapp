
-- =================================================================
--  DROPS PARA REGENERACIÓN
--  Este bloque permite re-ejecutar el script de forma segura.
-- =================================================================
DROP TABLE IF EXISTS "public"."order_items" CASCADE;
DROP TABLE IF EXISTS "public"."orders" CASCADE;
DROP TABLE IF EXISTS "public"."agreement_promotions" CASCADE;
DROP TABLE IF EXISTS "public"."agreement_sales_conditions" CASCADE;
DROP TABLE IF EXISTS "public"."price_list_items" CASCADE;
DROP TABLE IF EXISTS "public"."clients" CASCADE;
DROP TABLE IF EXISTS "public"."agreements" CASCADE;
DROP TABLE IF EXISTS "public"."price_lists" CASCADE;
DROP TABLE IF EXISTS "public"."products" CASCADE;
DROP TABLE IF EXISTS "public"."promotions" CASCADE;
DROP TABLE IF EXISTS "public"."sales_conditions" CASCADE;
DROP TABLE IF EXISTS "public"."dashboard_stats" CASCADE;
DROP VIEW IF EXISTS "public"."agreements_with_counts";


-- =================================================================
--  TABLAS PRINCIPALES
-- =================================================================

-- Tabla de Productos
CREATE TABLE "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "base_price" "numeric" DEFAULT 0 NOT NULL,
    "category" "text",
    "created_at" "timestamp with time zone" DEFAULT "now"() NOT NULL,
    CONSTRAINT "products_name_check" CHECK (("char_length"("name") > 0))
);
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX products_pkey ON public.products USING btree (id);
ALTER TABLE "public"."products" ADD CONSTRAINT "products_pkey" PRIMARY KEY USING INDEX "products_pkey";


-- Tabla de Listas de Precios
CREATE TABLE "public"."price_lists" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "prices_include_vat" "bool" DEFAULT true NOT NULL,
    "created_at" "timestamp with time zone" DEFAULT "now"() NOT NULL
);
ALTER TABLE "public"."price_lists" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX price_lists_pkey ON public.price_lists USING btree (id);
CREATE UNIQUE INDEX price_lists_name_key ON public.price_lists USING btree (name);
ALTER TABLE "public"."price_lists" ADD CONSTRAINT "price_lists_pkey" PRIMARY KEY USING INDEX "price_lists_pkey";
ALTER TABLE "public"."price_lists" ADD CONSTRAINT "price_lists_name_key" UNIQUE USING INDEX "price_lists_name_key";


-- Tabla de Items de Listas de Precios (Tabla Pivote)
CREATE TABLE "public"."price_list_items" (
    "price_list_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "price" "numeric" NOT NULL,
    "volume_price" "numeric",
    "created_at" timestamp with time zone not null default now(),
    CONSTRAINT "price_list_items_price_check" CHECK ((price >= (0)::numeric))
);
ALTER TABLE "public"."price_list_items" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX price_list_items_pkey ON public.price_list_items USING btree (price_list_id, product_id);
ALTER TABLE "public"."price_list_items" ADD CONSTRAINT "price_list_items_pkey" PRIMARY KEY USING INDEX "price_list_items_pkey";
ALTER TABLE "public"."price_list_items" ADD CONSTRAINT "price_list_items_price_list_id_fkey" FOREIGN KEY (price_list_id) REFERENCES price_lists(id) ON DELETE CASCADE;
ALTER TABLE "public"."price_list_items" ADD CONSTRAINT "price_list_items_product_id_fkey" FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;


-- Tabla de Convenios
CREATE TABLE "public"."agreements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "agreement_name" "text" NOT NULL,
    "client_type" "text" NOT NULL,
    "created_at" "timestamp with time zone" DEFAULT "now"() NOT NULL,
    "price_list_id" "uuid"
);
ALTER TABLE "public"."agreements" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX agreements_pkey ON public.agreements USING btree (id);
CREATE UNIQUE INDEX agreements_agreement_name_key ON public.agreements USING btree (agreement_name);
ALTER TABLE "public"."agreements" ADD CONSTRAINT "agreements_pkey" PRIMARY KEY USING INDEX "agreements_pkey";
ALTER TABLE "public"."agreements" ADD CONSTRAINT "agreements_agreement_name_key" UNIQUE USING INDEX "agreements_agreement_name_key";
ALTER TABLE "public"."agreements" ADD CONSTRAINT "agreements_price_list_id_fkey" FOREIGN KEY (price_list_id) REFERENCES price_lists(id) ON DELETE SET NULL;


-- Tabla de Clientes
CREATE TABLE "public"."clients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cuit" "text",
    "contact_name" "text",
    "contact_dni" "text",
    "address" "text",
    "delivery_window" "text",
    "email" "text",
    "instagram" "text",
    "status" "text" DEFAULT 'pending_onboarding'::text NOT NULL,
    "onboarding_token" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "agreement_id" "uuid",
    "created_at" "timestamp with time zone" DEFAULT "now"() NOT NULL
);
ALTER TABLE "public"."clients" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX clients_pkey ON public.clients USING btree (id);
CREATE UNIQUE INDEX clients_onboarding_token_key ON public.clients USING btree (onboarding_token);
CREATE UNIQUE INDEX clients_cuit_key ON public.clients USING btree (cuit) WHERE (status <> 'archived');
CREATE UNIQUE INDEX clients_email_key ON public.clients USING btree (email) WHERE (status <> 'archived');
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_pkey" PRIMARY KEY USING INDEX "clients_pkey";
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_onboarding_token_key" UNIQUE USING INDEX "clients_onboarding_token_key";
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_cuit_key" UNIQUE USING INDEX "clients_cuit_key";
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_email_key" UNIQUE USING INDEX "clients_email_key";
ALTER TABLE "public"."clients" ADD CONSTRAINT "clients_agreement_id_fkey" FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE SET NULL;


-- Tabla de Promociones
CREATE TABLE "public"."promotions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "rules" "jsonb",
    "created_at" "timestamp with time zone" DEFAULT "now"() NOT NULL
);
ALTER TABLE "public"."promotions" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX promotions_pkey ON public.promotions USING btree (id);
ALTER TABLE "public"."promotions" ADD CONSTRAINT "promotions_pkey" PRIMARY KEY USING INDEX "promotions_pkey";


-- Tabla de Condiciones de Venta
CREATE TABLE "public"."sales_conditions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "rules" "jsonb",
    "created_at" "timestamp with time zone" DEFAULT "now"() NOT NULL
);
ALTER TABLE "public"."sales_conditions" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX sales_conditions_pkey ON public.sales_conditions USING btree (id);
ALTER TABLE "public"."sales_conditions" ADD CONSTRAINT "sales_conditions_pkey" PRIMARY KEY USING INDEX "sales_conditions_pkey";


-- Tabla Pivote Convenio-Promoción
CREATE TABLE "public"."agreement_promotions" (
    "agreement_id" "uuid" NOT NULL,
    "promotion_id" "uuid" NOT NULL
);
ALTER TABLE "public"."agreement_promotions" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX agreement_promotions_pkey ON public.agreement_promotions USING btree (agreement_id, promotion_id);
ALTER TABLE "public"."agreement_promotions" ADD CONSTRAINT "agreement_promotions_pkey" PRIMARY KEY USING INDEX "agreement_promotions_pkey";
ALTER TABLE "public"."agreement_promotions" ADD CONSTRAINT "agreement_promotions_agreement_id_fkey" FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE CASCADE;
ALTER TABLE "public"."agreement_promotions" ADD CONSTRAINT "agreement_promotions_promotion_id_fkey" FOREIGN KEY (promotion_id) REFERENCES promotions(id) ON DELETE CASCADE;


-- Tabla Pivote Convenio-Condición de Venta
CREATE TABLE "public"."agreement_sales_conditions" (
    "agreement_id" "uuid" NOT NULL,
    "sales_condition_id" "uuid" NOT NULL
);
ALTER TABLE "public"."agreement_sales_conditions" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX agreement_sales_conditions_pkey ON public.agreement_sales_conditions USING btree (agreement_id, sales_condition_id);
ALTER TABLE "public"."agreement_sales_conditions" ADD CONSTRAINT "agreement_sales_conditions_pkey" PRIMARY KEY USING INDEX "agreement_sales_conditions_pkey";
ALTER TABLE "public"."agreement_sales_conditions" ADD CONSTRAINT "agreement_sales_conditions_agreement_id_fkey" FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE CASCADE;
ALTER TABLE "public"."agreement_sales_conditions" ADD CONSTRAINT "agreement_sales_conditions_sales_condition_id_fkey" FOREIGN KEY (sales_condition_id) REFERENCES sales_conditions(id) ON DELETE CASCADE;


-- Tabla de Pedidos
CREATE TABLE "public"."orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "uuid" NOT NULL,
    "agreement_id" "uuid" NOT NULL,
    "created_at" "timestamp with time zone" DEFAULT "now"() NOT NULL,
    "total_amount" "numeric" NOT NULL,
    "status" "text" DEFAULT 'pending'::text NOT NULL,
    "client_name_cache" "text" NOT NULL
);
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX orders_pkey ON public.orders USING btree (id);
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_pkey" PRIMARY KEY USING INDEX "orders_pkey";
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_agreement_id_fkey" FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE RESTRICT;
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_client_id_fkey" FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT;


-- Tabla de Ítems del Pedido
CREATE TABLE "public"."order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity" "int4" NOT NULL,
    "price_per_unit" "numeric" NOT NULL
);
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX order_items_pkey ON public.order_items USING btree (id);
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_pkey" PRIMARY KEY USING INDEX "order_items_pkey";
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT;


-- Tabla de Estadísticas del Dashboard
CREATE TABLE "public"."dashboard_stats" (
    "id" "int4" PRIMARY KEY DEFAULT 1,
    "total_revenue" "numeric" DEFAULT 0 NOT NULL,
    "month_revenue" "numeric" DEFAULT 0 NOT NULL,
    "active_clients" "int4" DEFAULT 0 NOT NULL,
    CONSTRAINT "dashboard_stats_id_check" CHECK ((id = 1))
);
ALTER TABLE "public"."dashboard_stats" ENABLE ROW LEVEL SECURITY;
-- Insertar la fila única para las estadísticas
INSERT INTO "public"."dashboard_stats" (id, total_revenue, month_revenue, active_clients) VALUES (1, 0, 0, 0)
ON CONFLICT (id) DO NOTHING;


-- =================================================================
--  VISTAS
-- =================================================================

-- Vista para Convenios con contadores de promos y condiciones
CREATE OR REPLACE VIEW "public"."agreements_with_counts" AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    COALESCE(pc.count, 0) AS promotion_count,
    COALESCE(scc.count, 0) AS sales_condition_count
FROM
    agreements a
LEFT JOIN (
    SELECT
        agreement_id,
        count(*) AS count
    FROM
        agreement_promotions
    GROUP BY
        agreement_id
) pc ON a.id = pc.agreement_id
LEFT JOIN (
    SELECT
        agreement_id,
        count(*) AS count
    FROM
        agreement_sales_conditions
    GROUP BY
        agreement_id
) scc ON a.id = scc.agreement_id;


-- =================================================================
--  FUNCIONES (RPC)
-- =================================================================

-- Función para incrementar los ingresos totales en dashboard_stats
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE public.dashboard_stats
  SET total_revenue = total_revenue + amount_to_add
  WHERE id = 1;
$$;


-- Función para obtener estadísticas de un cliente
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
    o.client_id = p_client_id AND o.status = 'completed';
END;
$$;


-- =================================================================
--  POLÍTICAS DE SEGURIDAD (RLS)
-- =================================================================
-- Habilitar RLS para todas las tablas por defecto (denegar todo)
-- Las políticas específicas permitirán el acceso.

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_stats ENABLE ROW LEVEL SECURITY;


-- Políticas para administradores autenticados
CREATE POLICY "Allow admin full access on products" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on agreements" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on promotions" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on orders" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access on order_items" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin read access on dashboard_stats" ON public.dashboard_stats FOR SELECT USING (auth.role() = 'authenticated');


-- Políticas para acceso público/anónimo
-- Los usuarios anónimos (clientes con enlace) solo necesitan leer datos específicos.
-- El acceso de escritura se gestiona a través de Server Actions que usan el rol 'service_role'.
CREATE POLICY "Allow public read on agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read on price_lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read on price_list_items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read on products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read on promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read on agreement_promotions" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read on clients for onboarding" ON public.clients FOR SELECT USING (true);


-- Políticas de inserción para Server Actions (que se ejecutan con anon key)
CREATE POLICY "Allow anon insert on orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon insert on order_items" ON public.order_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon update on clients for onboarding" ON public.clients FOR UPDATE USING (true) WITH CHECK (true);

