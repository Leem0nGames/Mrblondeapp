import { createClient } from '@supabase/supabase-js';

// Este cliente de Supabase utiliza la SERVICE_ROLE_KEY, que le otorga
// acceso completo a tu base de datos, saltándose cualquier política de RLS.
// DEBE usarse únicamente en el lado del servidor y NUNCA exponerse al cliente.
// Lo usaremos para tareas administrativas como contar el total de usuarios.

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

let supabaseAdminSingleton: ReturnType<typeof createClient> | null = null;

function getSupabaseAdmin() {
    if (supabaseAdminSingleton) {
        return supabaseAdminSingleton;
    }

    if (!supabaseUrl || !serviceRoleKey) {
        // This unified error handling prevents the server from crashing on startup
        // if environment variables are missing in any environment.
        console.error(`
        *************************************************************************
        * ERROR CRÍTICO: Cliente Admin de Supabase no configurado.
        *
        * Faltan las variables de entorno 'NEXT_PUBLIC_SUPABASE_URL' o
        * 'SUPABASE_SERVICE_ROLE_KEY'.
        *
        * Las funciones que dependen de este cliente (ej: páginas públicas) fallarán.
        *
        * QUÉ HACER:
        * 1. Asegúrate de que tu archivo '.env.local' exista y esté correcto.
        * 2. Si despliegas en Vercel, confirma que estas variables están
        *    configuradas en el panel de tu proyecto.
        *************************************************************************
        `);
        return null;
    }

    supabaseAdminSingleton = createClient(supabaseUrl, serviceRoleKey, {
        auth: {
            autoRefreshToken: false,
            persistSession: false,
        },
    });
    
    return supabaseAdminSingleton;
}

export const supabaseAdmin = getSupabaseAdmin();
