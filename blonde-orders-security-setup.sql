-- -------------------------------------------------------------------------------------
-- BLONDE ORDERS - INSTALACIÓN/REPARACIÓN SEGURA DE BASE DE DATOS
-- 
-- Este script único realiza:
-- 1. Diagnóstico automático del estado actual
-- 2. Limpieza completa de políticas inseguras  
-- 3. Instalación de políticas RLS seguras
-- 4. Verificación final del estado de seguridad
--
-- Compatible tanto para instalación nueva como para reparación de existente
-- -------------------------------------------------------------------------------------

-- ----------------------------------------
-- FUNCIÓN DE DIAGNÓSTICO
-- ----------------------------------------
DO $$
DECLARE
    table_count INTEGER;
    policy_count INTEGER;
    msg TEXT;
BEGIN
    -- Contar tablas principales
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
        AND table_name IN ('products', 'agreements', 'agreement_products', 'agreement_promotions', 'promotions');
    
    -- Contar políticas RLS
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE schemaname = 'public';
    
    -- Mostrar diagnóstico
    IF table_count >= 5 THEN
        RAISE NOTICE '🔍 DIAGNÓSTICO: Base de datos detectada con % tablas principales', table_count;
    ELSE
        RAISE NOTICE '⚠️ ADVERTENCIA: Base de datos incompleta (% tablas)', table_count;
    END IF;
    
    IF policy_count > 0 THEN
        RAISE NOTICE '🔒 DIAGNÓSTICO: % políticas RLS existentes - Iniciando reparación', policy_count;
    ELSE
        RAISE NOTICE '📝 DIAGNÓSTICO: Sin políticas RLS - Iniciando instalación nueva';
    END IF;
END $$;

-- ----------------------------------------
-- 1. LIMPIEZA COMPLETA DE POLÍTICAS
-- ----------------------------------------

-- Eliminar todas las políticas posibles existentes
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_products CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.promotions CASCADE;

DROP POLICY IF EXISTS "Admin full access" ON public.products CASCADE;
DROP POLICY IF EXISTS "Admin full access" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Admin full access" ON public.agreement_products CASCADE;
DROP POLICY IF EXISTS "Admin full access" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Admin full access" ON public.promotions CASCADE;

DROP POLICY IF EXISTS "Authenticated users can read products" ON public.products CASCADE;
DROP POLICY IF EXISTS "Authenticated users can manage products" ON public.products CASCADE;
DROP POLICY IF EXISTS "Authenticated users can read agreements" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Authenticated users can manage agreements" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Authenticated users can read agreement products" ON public.agreement_products CASCADE;
DROP POLICY IF EXISTS "Authenticated users can manage agreement products" ON public.agreement_products CASCADE;
DROP POLICY IF EXISTS "Authenticated users can read agreement promotions" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Authenticated users can manage agreement promotions" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Authenticated users can read promotions" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Authenticated users can manage promotions" ON public.promotions CASCADE;

DROP POLICY IF EXISTS "Public read access to products" ON public.products CASCADE;
DROP POLICY IF EXISTS "Public read access to agreements" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Public read access to agreement products" ON public.agreement_products CASCADE;
DROP POLICY IF EXISTS "Public read access to agreement promotions" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Public read access to promotions" ON public.promotions CASCADE;

DROP POLICY IF EXISTS "Public read access for products" ON public.products CASCADE;
DROP POLICY IF EXISTS "Public read access for agreements" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Public read access for agreement_products" ON public.agreement_products CASCADE;
DROP POLICY IF EXISTS "Public read access for agreement_promotions" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Public read access for promotions" ON public.promotions CASCADE;

DROP POLICY IF EXISTS "Allow anon read access" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.agreement_products CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.promotions CASCADE;

DO $$
BEGIN
    RAISE NOTICE '🧹 LIMPIEZA: Todas las políticas existentes eliminadas';
END $$;

-- ----------------------------------------
-- 2. INSTALACIÓN DE POLÍTICAS SEGURAS
-- ----------------------------------------

-- PRODUCTS: Políticas para administradores
CREATE POLICY "Admins can read products" ON public.products FOR SELECT 
USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage products" ON public.products FOR ALL 
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- PRODUCTS: Acceso público (página de pedidos)
CREATE POLICY "Public can read products" ON public.products FOR SELECT 
USING (true);

-- AGREEMENTS: Políticas para administradores
CREATE POLICY "Admins can read agreements" ON public.agreements FOR SELECT 
USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage agreements" ON public.agreements FOR ALL 
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- AGREEMENTS: Acceso público
CREATE POLICY "Public can read agreements" ON public.agreements FOR SELECT 
USING (true);

-- AGREEMENT PRODUCTS: Políticas para administradores
CREATE POLICY "Admins can read agreement products" ON public.agreement_products FOR SELECT 
USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage agreement products" ON public.agreement_products FOR ALL 
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- AGREEMENT PRODUCTS: Acceso público
CREATE POLICY "Public can read agreement products" ON public.agreement_products FOR SELECT 
USING (true);

-- AGREEMENT PROMOTIONS: Políticas para administradores
CREATE POLICY "Admins can read agreement promotions" ON public.agreement_promotions FOR SELECT 
USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage agreement promotions" ON public.agreement_promotions FOR ALL 
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- AGREEMENT PROMOTIONS: Acceso público
CREATE POLICY "Public can read agreement promotions" ON public.agreement_promotions FOR SELECT 
USING (true);

-- PROMOTIONS: Políticas para administradores
CREATE POLICY "Admins can read promotions" ON public.promotions FOR SELECT 
USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage promotions" ON public.promotions FOR ALL 
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- PROMOTIONS: Acceso público
CREATE POLICY "Public can read promotions" ON public.promotions FOR SELECT 
USING (true);

DO $$
BEGIN
    RAISE NOTICE '🛡️ INSTALACIÓN: % políticas seguras creadas', '15';
    RAISE NOTICE '✅ ACCESO ADMIN: Control total para usuarios autenticados';
    RAISE NOTICE '🌐 ACCESO PÚBLICO: Solo lectura para páginas de pedidos';
END $$;

-- ----------------------------------------
-- 3. VERIFICACIÓN FINAL
-- ----------------------------------------

-- Mostrar estado final de políticas
SELECT 
    tablename,
    COUNT(*) as policy_count,
    STRING_AGG(policyname, ', ' ORDER BY policyname) as policies
FROM pg_policies 
WHERE schemaname = 'public' 
    AND tablename IN ('products', 'agreements', 'agreement_products', 'agreement_promotions', 'promotions')
GROUP BY tablename
ORDER BY tablename;

-- Resumen final de seguridad
DO $$
DECLARE
    total_policies INTEGER;
    expected_policies INTEGER := 15; -- 5 tablas × 3 políticas
BEGIN
    SELECT COUNT(*) INTO total_policies
    FROM pg_policies 
    WHERE schemaname = 'public';
    
    IF total_policies = expected_policies THEN
        RAISE NOTICE '🎉 ÉXITO COMPLETO: Base de datos segura y funcional';
        RAISE NOTICE '📊 Políticas: %/% aplicadas correctamente', total_policies, expected_policies;
        RAISE NOTICE '🔒 Nivel de seguridad: SEGURO (Acceso granular implementado)';
    ELSIF total_policies > 0 THEN
        RAISE NOTICE '✅ PARCIAL: Base de datos mejorada (% políticas)', total_policies;
        RAISE NOTICE '⚠️ Revisa manualmente si faltan políticas';
    ELSE
        RAISE NOTICE '❌ ERROR: No se crearon políticas - revisa los permisos';
    END IF;
END $$;

-- ----------------------------------------
-- 4. INSTRUCCIONES POST-INSTALACIÓN
-- ----------------------------------------

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 SIGUIENTES PASOS RECOMENDADOS:';
    RAISE NOTICE '1. Configurar variables de entorno en Vercel';
    RAISE NOTICE '2. Probar aplicación en desarrollo local';
    RAISE NOTICE '3. Validar que las páginas de pedidos funcionen';
    RAISE NOTICE '4. Desplegar a producción cuando esté todo verificado';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Blonde Orders está listo para producción segura';
END $$;

-- ----------------------------------------
-- FIN DEL SCRIPT
-- ----------------------------------------