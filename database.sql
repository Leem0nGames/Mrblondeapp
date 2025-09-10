-- Crear la tabla de productos
create table products (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  base_price numeric not null default 0,
  stock integer not null default 0,
  category text,
  created_at timestamptz not null default now()
);

-- Crear la tabla de promociones
create table promotions (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  rules jsonb,
  created_at timestamptz not null default now()
);

-- Crear la tabla de convenios
create table agreements (
  id uuid primary key default uuid_generate_v4(),
  agreement_name text not null,
  client_type text not null check (client_type in ('barberia', 'distribuidor', 'especial')),
  price_adjustment numeric not null default 0,
  created_at timestamptz not null default now()
);

-- Crear la tabla de tokens de acceso
create table access_tokens (
  id uuid primary key default uuid_generate_v4(),
  agreement_id uuid not null references agreements(id) on delete cascade,
  client_name text not null,
  token text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- Crear la tabla intermedia para productos y convenios
create table agreement_products (
  agreement_id uuid not null references agreements(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  price numeric not null,
  primary key (agreement_id, product_id)
);

-- Crear la tabla intermedia para promociones y convenios
create table agreement_promotions (
  agreement_id uuid not null references agreements(id) on delete cascade,
  promotion_id uuid not null references promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);

-- Habilitar RLS (Row Level Security) para las tablas
alter table products enable row level security;
alter table promotions enable row level security;
alter table agreements enable row level security;
alter table access_tokens enable row level security;
alter table agreement_products enable row level security;
alter table agreement_promotions enable row level security;

-- Políticas de acceso público de solo lectura para datos de pedidos
create policy "Public access to products" on products for select using (true);
create policy "Public access to promotions" on promotions for select using (true);
create policy "Public access to agreements" on agreements for select using (true);
create policy "Public access to access_tokens" on access_tokens for select using (true);
create policy "Public access to agreement_products" on agreement_products for select using (true);
create policy "Public access to agreement_promotions" on agreement_promotions for select using (true);


-- Políticas de acceso para administradores autenticados
create policy "Admin full access" on products for all
using ( auth.role() = 'authenticated' )
with check ( auth.role() = 'authenticated' );

create policy "Admin full access" on promotions for all
using ( auth.role() = 'authenticated' )
with check ( auth.role() = 'authenticated' );

create policy "Admin full access" on agreements for all
using ( auth.role() = 'authenticated' )
with check ( auth.role() = 'authenticated' );

create policy "Admin full access" on access_tokens for all
using ( auth.role() = 'authenticated' )
with check ( auth.role() = 'authenticated' );

create policy "Admin full access" on agreement_products for all
using ( auth.role() = 'authenticated' )
with check ( auth.role() = 'authenticated' );

create policy "Admin full access" on agreement_promotions for all
using ( auth.role() = 'authenticated' )
with check ( auth.role() = 'authenticated' );
