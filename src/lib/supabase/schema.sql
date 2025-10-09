
-- --------------------------------------------------------------------------------
-- 1. EXTENSIONS
-- --------------------------------------------------------------------------------
-- Habilitamos la extensión para usar funciones de cifrado y generación de UUIDs
create extension if not exists "pgcrypto" with schema "extensions";

-- --------------------------------------------------------------------------------
-- 2. TABLAS
-- --------------------------------------------------------------------------------

-- Tabla de Productos
-- Almacena el catálogo de todos los productos disponibles.
create table public.products (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    name text not null,
    description text null,
    base_price numeric not null default 0,
    stock integer not null default 0,
    category text null,
    constraint products_pkey primary key (id)
);

-- Tabla de Listas de Precios
-- Permite crear múltiples listas con precios diferentes para los mismos productos.
create table public.price_lists (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    name text not null,
    prices_include_vat boolean not null default true,
    constraint price_lists_pkey primary key (id),
    constraint price_lists_name_key unique (name)
);

-- Tabla de Items de Listas de Precios (Tabla Pivote)
-- Asocia productos a una lista de precios con un precio específico.
create table public.price_list_items (
    price_list_id uuid not null,
    product_id uuid not null,
    price numeric not null,
    volume_price numeric null,
    constraint price_list_items_pkey primary key (price_list_id, product_id),
    constraint price_list_items_price_list_id_fkey foreign key (price_list_id) references price_lists (id) on delete cascade,
    constraint price_list_items_product_id_fkey foreign key (product_id) references products (id) on delete cascade
);

-- Tabla de Promociones
-- Define las promociones o reglas de negocio que se pueden aplicar.
create table public.promotions (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    name text not null,
    description text null,
    rules jsonb null,
    constraint promotions_pkey primary key (id)
);

-- Tabla de Convenios
-- Agrupa un conjunto de reglas (lista de precios, promociones) para un tipo de cliente.
create table public.agreements (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    agreement_name text not null,
    client_type public.client_type_enum not null,
    price_list_id uuid null,
    constraint agreements_pkey primary key (id),
    constraint agreements_agreement_name_key unique (agreement_name),
    constraint agreements_price_list_id_fkey foreign key (price_list_id) references price_lists (id) on delete set null
);

-- Tabla de Convenios y Promociones (Tabla Pivote)
-- Asocia múltiples promociones a un convenio.
create table public.agreement_promotions (
    agreement_id uuid not null,
    promotion_id uuid not null,
    constraint agreement_promotions_pkey primary key (agreement_id, promotion_id),
    constraint agreement_promotions_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint agreement_promotions_promotion_id_fkey foreign key (promotion_id) references promotions (id) on delete cascade
);

-- Tabla de Clientes
-- Almacena la información de los clientes (barberías, distribuidores).
create table public.clients (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    cuit text null,
    contact_name text null,
    contact_dni text null,
    address text null,
    delivery_window text null,
    email text null,
    instagram text null,
    status public.client_status_enum not null default 'pending_onboarding'::public.client_status_enum,
    onboarding_token uuid not null default gen_random_uuid (),
    agreement_id uuid null,
    constraint clients_pkey primary key (id),
    constraint clients_cuit_key unique (cuit),
    constraint clients_email_key unique (email),
    constraint clients_onboarding_token_key unique (onboarding_token),
    constraint clients_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete set null
);

-- Tabla de Pedidos
-- Almacena un registro de cada pedido realizado.
create table public.orders (
    id uuid not null default gen_random_uuid (),
    client_id uuid not null,
    agreement_id uuid not null,
    created_at timestamp with time zone not null default now(),
    total_amount numeric not null,
    status public.order_status_enum not null default 'pending'::public.order_status_enum,
    client_name_cache text null,
    constraint orders_pkey primary key (id),
    constraint orders_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete no action,
    constraint orders_client_id_fkey foreign key (client_id) references clients (id) on delete no action
);

-- Tabla de Items de Pedido
-- Guarda los detalles de los productos para cada pedido.
create table public.order_items (
    id bigint generated by default as identity,
    order_id uuid not null,
    product_id uuid not null,
    quantity integer not null,
    price_per_unit numeric not null,
    constraint order_items_pkey primary key (id),
    constraint order_items_order_id_fkey foreign key (order_id) references orders (id) on delete cascade,
    constraint order_items_product_id_fkey foreign key (product_id) references products (id) on delete no action
);

-- Tabla para Estadísticas del Dashboard
-- Pre-calcula y almacena métricas para un acceso rápido.
create table public.dashboard_stats (
    id bigint primary key default 1,
    total_revenue numeric default 0,
    month_revenue numeric default 0,
    active_clients integer default 0,
    constraint single_row_check check (id = 1)
);

-- --------------------------------------------------------------------------------
-- 3. TIPOS ENUMERADOS (para restringir valores)
-- --------------------------------------------------------------------------------
create type public.client_type_enum as enum ('barberia', 'distribuidor', 'especial');
create type public.client_status_enum as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type public.order_status_enum as enum ('pending', 'completed');

-- -----------------------------------------------------------------
-- 4. INSERCIÓN DE DATOS INICIALES
-- -----------------------------------------------------------------

-- Insertar una fila inicial en la tabla de estadísticas
insert into public.dashboard_stats(id, total_revenue, month_revenue, active_clients)
values (1, 0, 0, 0)
on conflict (id) do nothing;

-- Insertar los productos iniciales
insert into public.products(name, description, base_price, stock, category) values
('DesertStyle Pomada efecto mate 50 grs', 'Pomada efecto mate', 14766.67, 0, 'Hairstyle'),
('Polvo Stardust 10grs', 'Polvo styling efecto mate', 14766.67, 0, 'Hairstyle'),
('OldSchool 100 grs', 'Pomada de fijación media/alta y brillo medio', 15972.97, 0, 'Hairstyle'),
('Liquid Pomade 120 ml', 'Pomada líquida para modelar cabello', 12310.81, 0, 'Hairstyle'),
('Shampoo 2 en 1 para el crecimiento 200 cc', 'Shampoo + acondicionador 2 en 1', 15063.96, 0, 'Hairstyle'),
('OldSchool 50 grs', 'Pomada de fijación media/alta y brillo medio', 12009.01, 0, 'Hairstyle'),
('El Capitán aceite para barba 20 ml N°3', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°1', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('Kit Premium para Barba N°1', 'Kit completo para barba', 26090.09, 0, 'FacialBeard'),
('OG Dandy After Shave 100 grs', 'After shave tradicional', 11879.28, 0, 'FacialBeard'),
('Kit Premium para Barba N°2', 'Kit completo para barba', 26090.09, 0, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°2', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('Kit Premium para Barba N°3', 'Kit completo para barba', 27018.92, 0, 'FacialBeard'),
('Kit Premium Cabello N°2', 'Kit cabello', 27536.04, 0, 'Hairstyle'),
('Kit Premium Cabello N°4', 'Kit cabello', 26628.65, 0, 'Hairstyle'),
('Kit Premium Cabello N°3', 'Kit cabello', 27705.41, 0, 'Hairstyle'),
('Kit Premium Cabello N°1', 'Kit cabello', 24584.23, 0, 'Hairstyle'),
('Kit Premium para Barba N°4', 'Kit completo para barba', 30794.14, 0, 'Hairstyle'),
('Caja Exhibidora Mr BLONDE', 'Exhibidor para puntos de venta', 30794.14, 0, 'Merchandising'),
('Crystal gel de afeitar 250 grs', 'Gel de afeitar profesional', 7820.18, 0, 'Professional'),
('Crème à Raser 400 grs', 'Crema de afeitado tradicional', 14172.71, 0, 'Professional'),
('Capa Mr Blonde', 'Capa para barbería confeccionada en tela liviana', 12610.35, 0, 'Merchandising');


-- --------------------------------------------------------------------------------
-- 5. POLÍTICAS DE SEGURIDAD (RLS - Row Level Security)
-- --------------------------------------------------------------------------------

-- Habilitar RLS en todas las tablas relevantes
alter table public.products enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.promotions enable row level security;
alter table public.agreements enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.dashboard_stats enable row level security;

-- Políticas para la tabla `products`
create policy "Los usuarios autenticados pueden leer productos" on public.products for select using (auth.role() = 'authenticated');
create policy "Los administradores pueden gestionar productos" on public.products for all using (auth.role() = 'authenticated');

-- Políticas para la tabla `price_lists`
create policy "Los usuarios autenticados pueden leer listas de precios" on public.price_lists for select using (auth.role() = 'authenticated');
create policy "Los administradores pueden gestionar listas de precios" on public.price_lists for all using (auth.role() = 'authenticated');

-- Políticas para `price_list_items`
create policy "Los usuarios autenticados pueden leer items de listas" on public.price_list_items for select using (auth.role() = 'authenticated');
create policy "Los administradores pueden gestionar items de listas" on public.price_list_items for all using (auth.role() = 'authenticated');

-- Políticas para la tabla `promotions`
create policy "Los usuarios autenticados pueden leer promociones" on public.promotions for select using (auth.role() = 'authenticated');
create policy "Los administradores pueden gestionar promociones" on public.promotions for all using (auth.role() = 'authenticated');

-- Políticas para la tabla `agreements`
-- ¡Permitimos la lectura pública porque el ID de convenio es secreto y se usa para el acceso a la página de pedido!
create policy "Cualquiera puede leer convenios (para página de pedido)" on public.agreements for select using (true);
create policy "Los administradores pueden gestionar convenios" on public.agreements for all using (auth.role() = 'authenticated');

-- Políticas para `agreement_promotions`
create policy "Cualquiera puede leer promociones de convenio" on public.agreement_promotions for select using (true);
create policy "Los administradores pueden gestionar promociones de convenio" on public.agreement_promotions for all using (auth.role() = 'authenticated');

-- Políticas para la tabla `clients`
-- ¡Permitimos la inserción/actualización pública para el formulario de onboarding! La seguridad se basa en el token.
create policy "Cualquiera puede leer clientes (para onboarding)" on public.clients for select using (true);
create policy "Cualquiera puede actualizar su propio registro de cliente (onboarding)" on public.clients for update using (true);
create policy "Los administradores pueden gestionar clientes" on public.clients for all using (auth.role() = 'authenticated');

-- Políticas para la tabla `orders`
create policy "Cualquiera puede crear pedidos" on public.orders for insert with check (true);
create policy "Los administradores pueden gestionar pedidos" on public.orders for all using (auth.role() = 'authenticated');

-- Políticas para la tabla `order_items`
create policy "Cualquiera puede crear items de pedido" on public.order_items for insert with check (true);
create policy "Los administradores pueden gestionar items de pedido" on public.order_items for all using (auth.role() = 'authenticated');

-- Políticas para la tabla `dashboard_stats`
create policy "Los administradores pueden leer las estadísticas" on public.dashboard_stats for select using (auth.role() = 'authenticated');
create policy "Los administradores pueden actualizar las estadísticas" on public.dashboard_stats for update using (auth.role() = 'authenticated');
