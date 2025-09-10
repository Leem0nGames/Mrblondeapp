-- 1. Tabla de Productos (base para todo)
create table if not exists products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  base_price numeric(10, 2) not null default 0,
  stock integer not null default 0,
  category text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table products enable row level security;
create policy "Allow public read-only access" on products for select using (true);
create policy "Allow admin full access" on products for all using (auth.role() = 'service_role');


-- 2. Tabla de Promociones (reglas de negocio)
create table if not exists promotions (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table promotions enable row level security;
create policy "Allow public read-only access" on promotions for select using (true);
create policy "Allow admin full access" on promotions for all using (auth.role() = 'service_role');


-- 3. Tabla de Convenios (agrupa clientes y reglas)
create table if not exists agreements (
  id uuid default gen_random_uuid() primary key,
  agreement_name text not null,
  client_type text not null default 'barberia',
  price_adjustment numeric(5,2) not null default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table agreements enable row level security;
create policy "Allow public read-only access" on agreements for select using (true);
create policy "Allow admin full access" on agreements for all using (auth.role() = 'service_role');


-- 4. Tabla intermedia: Productos en Convenios (precios personalizados)
create table if not exists agreement_products (
  agreement_id uuid references agreements(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  price numeric(10, 2) not null,
  primary key (agreement_id, product_id)
);
alter table agreement_products enable row level security;
create policy "Allow public read-only access" on agreement_products for select using (true);
create policy "Allow admin full access" on agreement_products for all using (auth.role() = 'service_role');


-- 5. Tabla intermedia: Promociones en Convenios
create table if not exists agreement_promotions (
    agreement_id uuid references agreements(id) on delete cascade,
    promotion_id uuid references promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
alter table agreement_promotions enable row level security;
create policy "Allow public read-only access" on agreement_promotions for select using (true);
create policy "Allow admin full access" on agreement_promotions for all using (auth.role() = 'service_role');


-- 6. Tabla de Tokens de Acceso (para links de pedido)
create table if not exists access_tokens (
    id uuid default gen_random_uuid() primary key,
    agreement_id uuid references agreements(id) on delete cascade,
    client_name text not null,
    token text not null unique,
    expires_at timestamp with time zone not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table access_tokens enable row level security;
create policy "Allow public read-only access" on access_tokens for select using (true);
create policy "Allow admin full access" on access_tokens for all using (auth.role() = 'service_role');

-- 7. Tabla de Logs de Pedidos (opcional, para registro)
create table if not exists order_logs (
    id uuid default gen_random_uuid() primary key,
    agreement_id uuid references agreements(id),
    order_data jsonb,
    sent_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table order_logs enable row level security;
create policy "Allow admin full access" on order_logs for all using (auth.role() = 'service_role');
