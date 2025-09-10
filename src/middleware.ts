import { type NextRequest, NextResponse } from 'next/server';
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { supabaseAdmin } from './lib/supabase/admin';

async function hasUsers(): Promise<boolean> {
  const { data, error } = await supabaseAdmin.auth.admin.listUsers();
  if (error) {
    console.error('Middleware: Error checking for users:', error.message);
    return true; // Safe default
  }
  return data.users.length > 0;
}

export async function middleware(request: NextRequest) {
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
          request.cookies.set({ name, value, ...options });
          response = NextResponse.next({
            request: {
              headers: request.headers,
            },
          });
          response.cookies.set({ name, value, ...options });
        },
        remove(name: string, options: CookieOptions) {
          request.cookies.set({ name, value: '', ...options });
          response = NextResponse.next({
            request: {
              headers: request.headers,
            },
          });
          response.cookies.set({ name, value: '', ...options });
        },
      },
    }
  );

  const {
    data: { session },
  } = await supabase.auth.getSession();
  
  const { pathname } = request.nextUrl;

  const usersExist = await hasUsers();
  const isAuthRoute = pathname === '/login' || pathname === '/signup';
  const isAdminRoute = pathname.startsWith('/admin');

  // --- Caso 1: No hay usuarios en la base de datos ---
  if (!usersExist) {
    // Solo se puede acceder a la página de registro
    if (pathname !== '/signup') {
      return NextResponse.redirect(new URL('/signup', request.url));
    }
    return response;
  }

  // --- Caso 2: Ya existen usuarios ---
  // La página de registro ya no es accesible
  if (pathname === '/signup') {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Si el usuario NO está autenticado
  if (!session) {
    // Si intenta acceder a una ruta de admin, redirigir a login
    if (isAdminRoute) {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  // Si el usuario SÍ está autenticado
  if (session) {
    // Si intenta acceder a login o signup, redirigir al panel de admin
    if (isAuthRoute) {
      return NextResponse.redirect(new URL('/admin', request.url));
    }
  }
  
  return response;
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - api (API routes)
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     */
    '/((?!api|_next/static|_next/image|favicon.ico).*)',
  ],
};
