
-- Habilita la extensión pgcrypto si aún no está habilitada
create extension if not exists "pgrst" with schema "public" version '0.1.0';
create extension if not exists "uuid-ossp" with schema "extensions";

-- Creación de la tabla de productos
create table if not exists "public"."products" (
    "id" uuid default extensions.uuid_generate_v4() not null,
    "name" character varying not null,
    "description" text,
    "base_price" numeric(10,2) not null default 0.00,
    "stock" integer not null default 0,
    "category" character varying,
    "created_at" timestamp with time zone not null default now()
);
alter table "public"."products" enable row level security;
alter table "public"."products" add constraint "products_pkey" PRIMARY KEY using index ("id");
grant delete on table "public"."products" to "anon";
grant insert on table "public"."products" to "anon";
grant select on table "public"."products" to "anon";
grant update on table "public"."products" to "anon";
grant delete on table "public"."products" to "authenticated";
grant insert on table "public"."products" to "authenticated";
grant select on table "public"."products" to "authenticated";
grant update on table "public"."products" to "authenticated";
grant delete on table "public"."products" to "service_role";
grant insert on table "public"."products" to "service_role";
grant select on table "public"."products" to "service_role";
grant update on table "public"."products" to "service_role";


-- Creación de la tabla de promociones
create table if not exists "public"."promotions" (
    "id" uuid default extensions.uuid_generate_v4() not null,
    "name" character varying not null,
    "description" text,
    "rules" jsonb not null,
    "created_at" timestamp with time zone not null default now()
);
alter table "public"."promotions" enable row level security;
alter table "public"."promotions" add constraint "promotions_pkey" PRIMARY KEY using index ("id");
grant delete on table "public"."promotions" to "anon";
grant insert on table "public"."promotions" to "anon";
grant select on table "public"."promotions" to "anon";
grant update on table "public"."promotions" to "anon";
grant delete on table "public"."promotions" to "authenticated";
grant insert on table "public"."promotions" to "authenticated";
grant select on table "public"."promotions" to "authenticated";
grant update on table "public"."promotions" to "authenticated";
grant delete on table "public"."promotions" to "service_role";
grant insert on table "public"."promotions" to "service_role";
grant select on table "public"."promotions" to "service_role";
grant update on table "public"."promotions" to "service_role";


-- Creación de la tabla de convenios
create table if not exists "public"."agreements" (
    "id" uuid default extensions.uuid_generate_v4() not null,
    "agreement_name" character varying not null,
    "client_type" character varying not null,
    "price_adjustment" numeric(5,2) not null default 0.00,
    "created_at" timestamp with time zone not null default now()
);
alter table "public"."agreements" enable row level security;
alter table "public"."agreements" add constraint "agreements_pkey" PRIMARY KEY using index ("id");
grant delete on table "public"."agreements" to "anon";
grant insert on table "public"."agreements" to "anon";
grant select on table "public"."agreements" to "anon";
grant update on table "public"."agreements" to "anon";
grant delete on table "public"."agreements" to "authenticated";
grant insert on table "public"."agreements" to "authenticated";
grant select on table "public"."agreements" to "authenticated";
grant update on table "public"."agreements" to "authenticated";
grant delete on table "public"."agreements" to "service_role";
grant insert on table "public"."agreements" to "service_role";
grant select on table "public"."agreements" to "service_role";
grant update on table "public"."agreements" to "service_role";


-- Tabla intermedia para convenios y productos
create table if not exists "public"."agreement_products" (
    "agreement_id" uuid not null,
    "product_id" uuid not null,
    "price" numeric(10,2) not null
);
alter table "public"."agreement_products" enable row level security;
alter table "public"."agreement_products" add constraint "agreement_products_pkey" PRIMARY KEY using index ("agreement_id", "product_id");
alter table "public"."agreement_products" add constraint "agreement_products_agreement_id_fkey" FOREIGN KEY ("agreement_id") REFERENCES "public"."agreements"("id") ON DELETE CASCADE;
alter table "public"."agreement_products" add constraint "agreement_products_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;
grant delete on table "public"."agreement_products" to "anon";
grant insert on table "public"."agreement_products" to "anon";
grant select on table "public"."agreement_products" to "anon";
grant update on table "public"."agreement_products" to "anon";
grant delete on table "public"."agreement_products" to "authenticated";
grant insert on table "public"."agreement_products" to "authenticated";
grant select on table "public"."agreement_products" to "authenticated";
grant update on table "public"."agreement_products" to "authenticated";
grant delete on table "public"."agreement_products" to "service_role";
grant insert on table "public"."agreement_products" to "service_role";
grant select on table "public"."agreement_products" to "service_role";
grant update on table "public"."agreement_products" to "service_role";


-- Tabla intermedia para convenios y promociones
create table if not exists "public"."agreement_promotions" (
    "agreement_id" uuid not null,
    "promotion_id" uuid not null
);
alter table "public"."agreement_promotions" enable row level security;
alter table "public"."agreement_promotions" add constraint "agreement_promotions_pkey" PRIMARY KEY using index ("agreement_id", "promotion_id");
alter table "public"."agreement_promotions" add constraint "agreement_promotions_agreement_id_fkey" FOREIGN KEY ("agreement_id") REFERENCES "public"."agreements"("id") ON DELETE CASCADE;
alter table "public"."agreement_promotions" add constraint "agreement_promotions_promotion_id_fkey" FOREIGN KEY ("promotion_id") REFERENCES "public"."promotions"("id") ON DELETE CASCADE;
grant delete on table "public"."agreement_promotions" to "anon";
grant insert on table "public"."agreement_promotions" to "anon";
grant select on table "public"."agreement_promotions" to "anon";
grant update on table "public"."agreement_promotions" to "anon";
grant delete on table "public"."agreement_promotions" to "authenticated";
grant insert on table "public"."agreement_promotions" to "authenticated";
grant select on table "public"."agreement_promotions" to "authenticated";
grant update on table "public"."agreement_promotions" to "authenticated";
grant delete on table "public"."agreement_promotions" to "service_role";
grant insert on table "public"."agreement_promotions" to "service_role";
grant select on table "public"."agreement_promotions" to "service_role";
grant update on table "public"."agreement_promotions" to "service_role";


-- Creación de la tabla de tokens de acceso
create table if not exists "public"."access_tokens" (
    "id" uuid default extensions.uuid_generate_v4() not null,
    "agreement_id" uuid not null,
    "client_name" character varying not null,
    "token" text not null,
    "expires_at" timestamp with time zone not null,
    "created_at" timestamp with time zone not null default now()
);
alter table "public"."access_tokens" enable row level security;
alter table "public"."access_tokens" add constraint "access_tokens_pkey" PRIMARY KEY using index ("id");
alter table "public"."access_tokens" add constraint "access_tokens_token_key" UNIQUE using index ("token");
alter table "public"."access_tokens" add constraint "access_tokens_agreement_id_fkey" FOREIGN KEY ("agreement_id") REFERENCES "public"."agreements"("id") ON DELETE CASCADE;
grant delete on table "public"."access_tokens" to "anon";
grant insert on table "public"."access_tokens" to "anon";
grant select on table "public"."access_tokens" to "anon";
grant update on table "public"."access_tokens" to "anon";
grant delete on table "public"."access_tokens" to "authenticated";
grant insert on table "public"."access_tokens" to "authenticated";
grant select on table "public"."access_tokens" to "authenticated";
grant update on table "public"."access_tokens" to "authenticated";
grant delete on table "public"."access_tokens" to "service_role";
grant insert on table "public"."access_tokens" to "service_role";
grant select on table "public"."access_tokens" to "service_role";
grant update on table "public"."access_tokens" to "service_role";


-- Creación de la tabla de registro de pedidos
create table if not exists "public"."order_logs" (
    "id" uuid default extensions.uuid_generate_v4() not null,
    "access_token_id" uuid not null,
    "order_details" jsonb not null,
    "total_price" numeric(10,2) not null,
    "created_at" timestamp with time zone not null default now()
);
alter table "public"."order_logs" enable row level security;
alter table "public"."order_logs" add constraint "order_logs_pkey" PRIMARY KEY using index ("id");
alter table "public"."order_logs" add constraint "order_logs_access_token_id_fkey" FOREIGN KEY ("access_token_id") REFERENCES "public"."access_tokens"("id") ON DELETE RESTRICT;
grant delete on table "public"."order_logs" to "anon";
grant insert on table "public"."order_logs" to "anon";
grant select on table "public"."order_logs" to "anon";
grant update on table "public"."order_logs" to "anon";
grant delete on table "public"."order_logs" to "authenticated";
grant insert on table "public"."order_logs" to "authenticated";
grant select on table "public"."order_logs" to "authenticated";
grant update on table "public"."order_logs" to "authenticated";
grant delete on table "public"."order_logs" to "service_role";
grant insert on table "public"."order_logs" to "service_role";
grant select on table "public"."order_logs" to "service_role";
grant update on table "public"."order_logs" to "service_role";


-- Crear la cuenta de administrador si no existe
-- Esta es una solución simple para el MVP. En una aplicación real, se usaría un sistema más seguro.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@blonde.com') THEN
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_token, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, phone, phone_confirmed_at, email_change, email_change_sent_at)
    VALUES (
      '00000000-0000-0000-0000-000000000000',
      extensions.uuid_generate_v4(),
      'authenticated',
      'authenticated',
      'admin@blonde.com',
      crypt('blondeadmin', gen_salt('bf')),
      NOW(),
      '',
      NULL,
      NULL,
      '{"provider": "email", "providers": ["email"]}',
      '{}',
      NOW(),
      NOW(),
      NULL,
      NULL,
      '',
      NULL
    );
  END IF;
END $$;
