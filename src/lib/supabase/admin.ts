import { createClient } from '@supabase/supabase-js';

// Este cliente de Supabase utiliza la SERVICE_ROLE_KEY, que le otorga
// acceso completo a tu base de datos, saltándose cualquier política de RLS.
// DEBE usarse únicamente en el lado del servidor y NUNCA exponerse al cliente.
// Lo usaremos para tareas administrativas como contar el total de usuarios.

// Nos aseguramos de que las variables de entorno existan.
if (!process.env.NEXT_PUBLIC_SUPABASE_URL) {
  throw new Error('Missing env.NEXT_PUBLIC_SUPABASE_URL');
}
if (!process.env.SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('Missing env.SUPABASE_SERVICE_ROLE_KEY');
}

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);
