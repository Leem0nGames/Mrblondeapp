
-- Habilitar la extensión pgcrypto para gen_random_uuid() si no está habilitada
create extension if not exists "pgcrypto" with schema "public";

-- Tabla de Productos
create table if not exists "public"."products" (
    "id" uuid not null default gen_random_uuid(),
    "name" character varying not null,
    "description" text,
    "base_price" numeric not null default 0,
    "stock" integer not null default 0,
    "category" character varying,
    "created_at" timestamp with time zone not null default now(),
    constraint "products_pkey" primary key (id)
);

-- Tabla de Promociones
create table if not exists "public"."promotions" (
    "id" uuid not null default gen_random_uuid(),
    "name" character varying not null,
    "description" text,
    "rules" jsonb not null,
    "created_at" timestamp with time zone not null default now(),
    constraint "promotions_pkey" primary key (id)
);

-- Tabla de Convenios
create table if not exists "public"."agreements" (
    "id" uuid not null default gen_random_uuid(),
    "agreement_name" character varying not null,
    "client_type" character varying not null default 'barberia'::character varying,
    "price_adjustment" numeric not null default 0,
    "created_at" timestamp with time zone not null default now(),
    constraint "agreements_pkey" primary key (id)
);

-- Tabla de Unión: Convenios y Productos (con precio personalizado)
create table if not exists "public"."agreement_products" (
    "agreement_id" uuid not null,
    "product_id" uuid not null,
    "price" numeric not null,
    constraint "agreement_products_pkey" primary key (agreement_id, product_id),
    constraint "agreement_products_agreement_id_fkey" foreign key (agreement_id) references public.agreements (id) on delete cascade,
    constraint "agreement_products_product_id_fkey" foreign key (product_id) references public.products (id) on delete cascade
);

-- Tabla de Unión: Convenios y Promociones
create table if not exists "public"."agreement_promotions" (
    "agreement_id" uuid not null,
    "promotion_id" uuid not null,
    constraint "agreement_promotions_pkey" primary key (agreement_id, promotion_id),
    constraint "agreement_promotions_agreement_id_fkey" foreign key (agreement_id) references public.agreements (id) on delete cascade,
    constraint "agreement_promotions_promotion_id_fkey" foreign key (promotion_id) references public.promotions (id) on delete cascade
);

-- Tabla de Tokens de Acceso para los enlaces de pedido
create table if not exists "public"."access_tokens" (
    "id" uuid not null default gen_random_uuid(),
    "agreement_id" uuid not null,
    "client_name" character varying not null,
    "token" character varying not null,
    "expires_at" timestamp with time zone not null,
    "created_at" timestamp with time zone not null default now(),
    constraint "access_tokens_pkey" primary key (id),
    constraint "access_tokens_token_key" unique (token),
    constraint "access_tokens_agreement_id_fkey" foreign key (agreement_id) references public.agreements (id) on delete cascade
);

-- Tabla de Registro de Pedidos (Opcional, para futura referencia)
create table if not exists "public"."order_logs" (
    "id" uuid not null default gen_random_uuid(),
    "access_token_id" uuid not null,
    "order_details" jsonb not null,
    "total_price" numeric not null,
    "created_at" timestamp with time zone not null default now(),
    constraint "order_logs_pkey" primary key (id),
    constraint "order_logs_access_token_id_fkey" foreign key (access_token_id) references public.access_tokens (id) on delete cascade
);

-- Crear usuario administrador si no existe (usar variables de entorno en producción)
-- NOTA: Este es un workaround para desarrollo. En producción, gestiona los usuarios de forma segura.
do $$
begin
  if not exists (select 1 from auth.users where email = 'admin@blonde.com') then
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_token, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token_encrypted)
    values (
      '00000000-0000-0000-0000-000000000000',
      uuid_generate_v4(),
      'authenticated',
      'authenticated',
      'admin@blonde.com',
      crypt('admin1234', gen_salt('bf')), -- Contraseña 'admin1234'
      now(),
      '',
      null,
      null,
      '{"provider":"email","providers":["email"]}',
      '{}',
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  end if;
end $$;
