import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { type NextRequest, NextResponse } from 'next/server';

// Esta función `createClient` está diseñada específicamente para ser usada
// en el Middleware de Next.js.
// Utiliza un enfoque diferente para manejar las cookies para evitar
// problemas con el renderizado estático y asegurar que la sesión
// del usuario se refresque correctamente.
export const createClient = (request: NextRequest) => {
  // Creamos una respuesta 'NextResponse' que se usará para leer y escribir cookies.
  let response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return request.cookies.get(name)?.value;
        },
        set(name: string, value: string, options: CookieOptions) {
          // Si `set` es llamado, actualizamos las cookies en la petición y la respuesta.
          request.cookies.set({
            name,
            value,
            ...options,
          });
          response = NextResponse.next({
            request: {
              headers: request.headers,
            },
          });
          response.cookies.set({
            name,
            value,
            ...options,
          });
        },
        remove(name: string, options: CookieOptions) {
          // Si `remove` es llamado, actualizamos las cookies en la petición y la respuesta.
          request.cookies.set({
            name,
            value: '',
            ...options,
          });
          response = NextResponse.next({
            request: {
              headers: request.headers,
            },
          });
          response.cookies.set({
            name,
            value: '',
            ...options,
          });
        },
      },
    }
  );

  return { supabase, response };
};
