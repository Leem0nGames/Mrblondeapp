import { createClient } from '@supabase/supabase-js';

// Este cliente de Supabase utiliza la SERVICE_ROLE_KEY, que le otorga
// acceso completo a tu base de datos, saltándose cualquier política de RLS.
// DEBE usarse únicamente en el lado del servidor y NUNCA exponerse al cliente.
// Lo usaremos para tareas administrativas como contar el total de usuarios.

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Creamos el cliente, pero no lanzamos un error si las variables no están.
// La lógica que lo usa (hasUsers) se encargará de manejar el caso de que no esté configurado.
export const supabaseAdmin =
  supabaseUrl && serviceRoleKey
    ? createClient(supabaseUrl, serviceRoleKey, {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      })
    : null;
