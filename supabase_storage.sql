-- CONFIGURACIÓN DE STORAGE PARA BLONDE ORDERS
-- Ejecutar en el editor SQL de Supabase

-- -------------------------------------------------
-- CREAR BUCKET: product_images
-- -------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public;

-- -------------------------------------------------
-- POLÍTICAS RLS PARA product_images
-- -------------------------------------------------

-- Permitir lectura pública de imágenes
CREATE POLICY "Public access to product images" ON storage.objects
FOR SELECT
USING (bucket_id = 'product_images');

-- Permitir upload autenticado
CREATE POLICY "Authenticated users can upload" ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');

-- Permitir actualización autenticada (sobrescribir)
CREATE POLICY "Authenticated users can update" ON storage.objects
FOR UPDATE
USING (bucket_id = 'product_images' AND auth.role() = 'authenticated');

-- -------------------------------------------------
-- OPCIONAL: BUCKET PARA ASSETS DE LA APP
-- -------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('app_assets', 'app_assets', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public;

CREATE POLICY "Public access to app assets" ON storage.objects
FOR SELECT
USING (bucket_id = 'app_assets');

CREATE POLICY "Authenticated users can upload app assets" ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update app assets" ON storage.objects
FOR UPDATE
USING (bucket_id = 'app_assets' AND auth.role() = 'authenticated');
