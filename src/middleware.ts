
import { type NextRequest, NextResponse } from 'next/server';
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { hasUsers } from './app/actions/user.actions';

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

  // Es crucial refrescar la sesión en el middleware
  const { data: { session } } = await supabase.auth.getSession();
  
  const { pathname } = request.nextUrl;

  const usersExist = await hasUsers();
  const isAuthRoute = pathname === '/login' || pathname === '/signup';
  const isAdminRoute = pathname.startsWith('/admin');
  const isOrderRoute = pathname.startsWith('/pedido');

  // --- 1. Flujo de Primera Vez (Setup) ---
  if (!usersExist) {
    // Si no hay usuarios, la única página permitida es la de registro.
    if (pathname !== '/signup') {
      return NextResponse.redirect(new URL('/signup', request.url));
    }
    // Permite el acceso a la página de registro.
    return response;
  }

  // --- 2. Flujo Normal de la Aplicación (Después del Setup) ---

  // Si ya existen usuarios, la página de registro ya no es accesible.
  if (pathname === '/signup') {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Las páginas de pedido son siempre públicas.
  if (isOrderRoute) {
    return response;
  }
  
  // Si el usuario NO está autenticado
  if (!session) {
    // Si intentan acceder a una ruta protegida (admin) o a la raíz, redirigir a login.
    if (isAdminRoute || pathname === '/') {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  // Si el usuario SÍ está autenticado
  if (session) {
    // Si intentan acceder a una página de autenticación (login) o a la raíz, redirigir al panel de admin.
    if (isAuthRoute || pathname === '/') {
      return NextResponse.redirect(new URL('/admin', request.url));
    }
  }
  
  // Para todos los demás casos, permitir la petición.
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
