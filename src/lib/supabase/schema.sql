
-- Habilitar RLS para todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW_LEVEL_SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_stats ENABLE ROW LEVEL SECURITY;


-- Eliminar políticas existentes para evitar conflictos
DROP POLICY IF EXISTS "Enable read access for all users" ON public.products;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.products;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.agreements;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.agreements;

DROP POLICY IF EXISTS "Public can read promotions" ON public.promotions;
DROP POLICY IF EXISTS "Enable insert for authenticated users" on public.promotions;
DROP POLICY IF EXISTS "Enable update for authenticated users" on public.promotions;
DROP POLICY IF EXISTS "Enable delete for authenticated users" on public.promotions;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.agreement_products;
DROP POLICY IF EXISTS "Enable insert for authenticated users" on public.agreement_products;
DROP POLICY IF EXISTS "Enable delete for authenticated users" on public.agreement_products;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Enable insert for authenticated users" on public.agreement_promotions;
DROP POLICY IF EXISTS "Enable delete for authenticated users" on public.agreement_promotions;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.clients;
DROP POLICY IF EXISTS "Enable insert for authenticated users" on public.clients;
DROP POLICY IF EXISTS "Enable update for authenticated users" on public.clients;
DROP POLICY IF EXISTS "Enable delete for authenticated users" on public.clients;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.price_lists;
DROP POLICY IF EXISTS "Enable insert for authenticated users" on public.price_lists;
DROP POLICY IF EXISTS "Enable update for authenticated users" on public.price_lists;
DROP POLICY IF EXISTS "Enable delete for authenticated users" on public.price_lists;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.price_list_items;
DROP POLICY IF EXISTS "Enable insert for authenticated users" on public.price_list_items;
DROP POLICY IF EXISTS "Enable update for authenticated users" on public.price_list_items;
DROP POLICY IF EXISTS "Enable delete for authenticated users" on public.price_list_items;

DROP POLICY IF EXISTS "Enable insert for all users" ON public.orders;
DROP POLICY IF EXISTS "Enable read access for authenticated users" on public.orders;
DROP POLICY IF EXISTS "Enable update for authenticated users" on public.orders;

DROP POLICY IF EXISTS "Enable insert for all users" ON public.order_items;
DROP POLICY IF EXISTS "Enable read access for authenticated users" on public.order_items;

DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.dashboard_stats;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.dashboard_stats;

-- Crear nuevas políticas

-- Tabla: products
CREATE POLICY "Enable read access for all users" ON public.products FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON public.products FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON public.products FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users" ON public.products FOR DELETE TO authenticated USING (true);

-- Tabla: promotions
CREATE POLICY "Public can read promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" on public.promotions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" on public.promotions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users" on public.promotions FOR DELETE TO authenticated USING (true);

-- Tabla: agreements
CREATE POLICY "Enable read access for all users" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON public.agreements FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON public.agreements FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users" ON public.agreements FOR DELETE TO authenticated USING (true);

-- Tabla: agreement_products (relación)
CREATE POLICY "Enable read access for all users" ON public.agreement_products FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" on public.agreement_products FOR INSERT to authenticated with check (true);
CREATE POLICY "Enable delete for authenticated users" on public.agreement_products FOR DELETE to authenticated using (true);

-- Tabla: agreement_promotions (relación)
CREATE POLICY "Enable read access for all users" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" on public.agreement_promotions FOR INSERT to authenticated with check (true);
CREATE POLICY "Enable delete for authenticated users" on public.agreement_promotions FOR DELETE to authenticated using (true);

-- Tabla: clients
CREATE POLICY "Enable read access for all users" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" on public.clients FOR INSERT to authenticated with check (true);
CREATE POLICY "Enable update for authenticated users" on public.clients FOR UPDATE to authenticated using (true) with check (true);
CREATE POLICY "Enable delete for authenticated users" on public.clients FOR DELETE to authenticated using (true);

-- Tabla: price_lists
CREATE POLICY "Enable read access for all users" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON public.price_lists FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON public.price_lists FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users" ON public.price_lists FOR DELETE TO authenticated USING (true);

-- Tabla: price_list_items
CREATE POLICY "Enable read access for all users" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON public.price_list_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON public.price_list_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users" ON public.price_list_items FOR DELETE TO authenticated USING (true);

-- Tabla: orders
CREATE POLICY "Enable insert for all users" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable read access for authenticated users" ON public.orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Enable update for authenticated users" on public.orders FOR UPDATE to authenticated using (true) with check (true);


-- Tabla: order_items
CREATE POLICY "Enable insert for all users" ON public.order_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable read access for authenticated users" ON public.order_items FOR SELECT TO authenticated USING (true);

-- Tabla: dashboard_stats
CREATE POLICY "Enable read access for authenticated users" ON public.dashboard_stats FOR SELECT to authenticated using (true);
CREATE POLICY "Enable update for authenticated users" on public.dashboard_stats FOR UPDATE to authenticated using (true) with check (true);


-- Vistas
DROP VIEW IF EXISTS public.agreements_with_counts;
CREATE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    COALESCE(ap.promotion_count, 0) as promotion_count,
    pl.name as price_list_name
FROM agreements a
LEFT JOIN (
    SELECT 
        agreement_id,
        count(*) as promotion_count
    FROM agreement_promotions
    GROUP BY agreement_id
) ap ON a.id = ap.agreement_id
LEFT JOIN price_lists pl ON a.price_list_id = pl.id;
