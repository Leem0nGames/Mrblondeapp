
-- Habilitar la extensión pgcrypto si no está habilitada
create extension if not exists "pgcrypto" with schema "public";

-- Habilitar la extensión uuid-ossp si no está habilitada
create extension if not exists "uuid-ossp" with schema "public";

-- Tabla de Productos
create table "public"."products" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "base_price" numeric not null default 0,
    "stock" integer not null default 0,
    "category" text,
    "created_at" timestamp with time zone not null default now(),
    constraint "products_pkey" primary key ("id")
);

-- Tabla de Promociones
create table "public"."promotions" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "rules" jsonb,
    "created_at" timestamp with time zone not null default now(),
    constraint "promotions_pkey" primary key ("id")
);

-- Tabla de Convenios
create table "public"."agreements" (
    "id" uuid not null default gen_random_uuid(),
    "agreement_name" text not null,
    "client_type" text not null default 'barberia'::text,
    "price_adjustment" numeric not null default 0,
    "created_at" timestamp with time zone not null default now(),
    constraint "agreements_pkey" primary key ("id")
);

-- Tabla de Tokens de Acceso
create table "public"."access_tokens" (
    "id" uuid not null default gen_random_uuid(),
    "agreement_id" uuid not null,
    "client_name" text not null,
    "token" text not null,
    "expires_at" timestamp with time zone not null,
    "created_at" timestamp with time zone not null default now(),
    constraint "access_tokens_pkey" primary key ("id"),
    constraint "access_tokens_token_key" unique ("token"),
    constraint "access_tokens_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete cascade
);

-- Tabla de Unión: Convenios y Productos
create table "public"."agreement_products" (
    "agreement_id" uuid not null,
    "product_id" uuid not null,
    "price" numeric not null,
    constraint "agreement_products_pkey" primary key ("agreement_id", "product_id"),
    constraint "agreement_products_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint "agreement_products_product_id_fkey" foreign key (product_id) references products (id) on delete cascade
);

-- Tabla de Unión: Convenios y Promociones
create table "public"."agreement_promotions" (
    "agreement_id" uuid not null,
    "promotion_id" uuid not null,
    constraint "agreement_promotions_pkey" primary key ("agreement_id", "promotion_id"),
    constraint "agreement_promotions_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint "agreement_promotions_promotion_id_fkey" foreign key (promotion_id) references promotions (id) on delete cascade
);

-- Tabla de Log de Pedidos (Opcional, para futuro)
create table "public"."order_logs" (
    "id" uuid not null default gen_random_uuid(),
    "access_token_id" uuid not null,
    "order_details" jsonb not null,
    "total_price" numeric not null,
    "created_at" timestamp with time zone not null default now(),
    constraint "order_logs_pkey" primary key ("id"),
    constraint "order_logs_access_token_id_fkey" foreign key (access_token_id) references access_tokens (id) on delete set null
);
