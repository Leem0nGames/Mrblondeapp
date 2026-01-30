-- =====================================================
-- ESQUEMA COMPLETO DE BASE DE DATOS - BLONDE ORDERS
-- Ejecutar en el editor SQL de Supabase
-- =====================================================

-- -------------------------------------------------
-- EXTENSIONES
-- -------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -------------------------------------------------
-- TABLA: products
-- -------------------------------------------------
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------
-- TABLA: price_lists
-- -------------------------------------------------
CREATE TABLE price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    base_price_list_id UUID REFERENCES price_lists(id) ON DELETE SET NULL,
    discount_percentage DECIMAL(5,2) DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------
-- TABLA: price_list_items
-- -------------------------------------------------
CREATE TABLE price_list_items (
    price_list_id UUID NOT NULL REFERENCES price_lists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    volume_price DECIMAL(10,2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

-- -------------------------------------------------
-- TABLA: agreements
-- -------------------------------------------------
CREATE TABLE agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name VARCHAR(100) NOT NULL UNIQUE,
    client_type VARCHAR(20) NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    price_list_id UUID REFERENCES price_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------
-- TABLA: promotions
-- -------------------------------------------------
CREATE TABLE promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    rules JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------
-- TABLA: sales_conditions
-- -------------------------------------------------
CREATE TABLE sales_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    rules JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------
-- TABLA: agreement_promotions
-- -------------------------------------------------
CREATE TABLE agreement_promotions (
    agreement_id UUID NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- -------------------------------------------------
-- TABLA: agreement_sales_conditions
-- -------------------------------------------------
CREATE TABLE agreement_sales_conditions (
    agreement_id UUID NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    sales_condition_id UUID NOT NULL REFERENCES sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- -------------------------------------------------
-- TABLA: clients
-- -------------------------------------------------
CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    cuit VARCHAR(20) UNIQUE,
    contact_name VARCHAR(200),
    contact_dni VARCHAR(20),
    email VARCHAR(255) UNIQUE,
    instagram VARCHAR(100),
    address VARCHAR(500),
    delivery_window VARCHAR(200),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    status VARCHAR(30) NOT NULL DEFAULT 'pending_onboarding' CHECK (status IN ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    onboarding_token UUID UNIQUE DEFAULT gen_random_uuid(),
    agreement_id UUID REFERENCES agreements(id) ON DELETE SET NULL,
    fiscal_status VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------
-- TABLA: orders
-- -------------------------------------------------
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    agreement_id UUID NOT NULL REFERENCES agreements(id) ON DELETE RESTRICT,
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    client_name_cache VARCHAR(200) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------
-- TABLA: order_items
-- -------------------------------------------------
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity >= 1),
    price_per_unit DECIMAL(10,2) NOT NULL CHECK (price_per_unit >= 0)
);

-- -------------------------------------------------
-- TABLA: app_settings
-- -------------------------------------------------
CREATE TABLE app_settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL
);

-- -------------------------------------------------
-- VISTAS
-- -------------------------------------------------
CREATE VIEW agreements_with_counts AS
SELECT 
    a.*,
    COALESCE(promos.promotion_count, 0) as promotion_count,
    COALESCE(conds.sales_condition_count, 0) as sales_condition_count,
    pl.name as price_lists_name
FROM agreements a
LEFT JOIN (
    SELECT agreement_id, COUNT(*) as promotion_count
    FROM agreement_promotions
    GROUP BY agreement_id
) promos ON a.id = promos.agreement_id
LEFT JOIN (
    SELECT agreement_id, COUNT(*) as sales_condition_count
    FROM agreement_sales_conditions
    GROUP BY agreement_id
) conds ON a.id = conds.agreement_id
LEFT JOIN price_lists pl ON a.price_list_id = pl.id;

-- -------------------------------------------------
-- VISTA: dashboard_stats
-- -------------------------------------------------
CREATE VIEW dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT COUNT(*) FROM clients WHERE status = 'active') as active_clients,
    (SELECT COUNT(*) FROM clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) as total_clients,
    (SELECT COUNT(*) FROM price_lists) as total_pricelists,
    (SELECT COUNT(*) FROM promotions) as total_promotions,
    (SELECT COUNT(*) FROM sales_conditions) as total_sales_conditions;

-- -------------------------------------------------
-- FUNCIONES RPC
-- -------------------------------------------------
CREATE OR REPLACE FUNCTION get_client_stats(p_client_id UUID)
RETURNS TABLE (
    total_spent DECIMAL,
    average_order_value DECIMAL,
    total_orders BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(o.total_amount), 0) as total_spent,
        COALESCE(AVG(o.total_amount), 0) as average_order_value,
        COUNT(*)::BIGINT as total_orders
    FROM orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$;

CREATE OR REPLACE FUNCTION get_notification_counts()
RETURNS TABLE (
    pending_orders_count BIGINT,
    pending_clients_count BIGINT,
    overdue_orders_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM orders WHERE status = 'pending')::BIGINT as pending_orders_count,
        (SELECT COUNT(*) FROM clients WHERE status = 'pending_agreement')::BIGINT as pending_clients_count,
        (SELECT COUNT(*) FROM orders WHERE status = 'pending' AND created_at < now() - INTERVAL '30 days')::BIGINT as overdue_orders_count;
END;
$$;

CREATE OR REPLACE FUNCTION increment_total_revenue(amount_to_add DECIMAL)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    NULL;
END;
$$;

-- -------------------------------------------------
-- POLITICAS RLS
-- -------------------------------------------------
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated all operations" ON products FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON price_lists FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON price_list_items FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON agreements FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON promotions FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON sales_conditions FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON agreement_promotions FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON agreement_sales_conditions FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON clients FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON orders FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON order_items FOR ALL TO authenticated USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated all operations" ON app_settings FOR ALL TO authenticated USING (auth.role() = 'authenticated');

-- -------------------------------------------------
-- DATOS INICIALES (SEED)
-- -------------------------------------------------
INSERT INTO app_settings (key, value) VALUES
    ('whatsapp_number', '"5491144276120"'),
    ('vat_percentage', '21'),
    ('logo_url', 'null')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- -------------------------------------------------
-- INDICES PARA MEJORAR RENDIMIENTO
-- -------------------------------------------------
CREATE INDEX idx_orders_client_id ON orders(client_id);
CREATE INDEX idx_orders_agreement_id ON orders(agreement_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_price_list_items_price_list_id ON price_list_items(price_list_id);
CREATE INDEX idx_price_list_items_product_id ON price_list_items(product_id);
CREATE INDEX idx_clients_agreement_id ON clients(agreement_id);
CREATE INDEX idx_clients_status ON clients(status);
CREATE INDEX idx_products_category ON products(category);

-- =====================================================
-- FIN DEL ESQUEMA
-- =====================================================
