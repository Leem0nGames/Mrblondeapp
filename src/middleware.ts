
import { type NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/middleware';
import { hasUsers } from '@/app/actions/user.actions';

export async function middleware(request: NextRequest) {
  const { supabase, response } = await createClient(request);
  const { pathname } = request.nextUrl;

  // 1. PRIORIDAD ABSOLUTA: RUTAS PÚBLICAS DE CLIENTES
  // Estas rutas deben ser accesibles sin ninguna verificación de autenticación.
  const isOrderRoute = pathname.startsWith('/pedido');
  const isOnboardingRoute = pathname.startsWith('/onboarding');

  if (isOrderRoute || isOnboardingRoute) {
    return response;
  }

  // 2. LÓGICA DE ADMINISTRACIÓN Y AUTENTICACIÓN
  const publicAuthRoutes = ['/login', '/signup'];
  const isAuthPageRoute = publicAuthRoutes.includes(pathname);

  // A. Verificación de existencia de administradores (Setup inicial)
  const usersExist = await hasUsers();

  if (!usersExist) {
    if (pathname !== '/signup') {
      return NextResponse.redirect(new URL('/signup', request.url));
    }
    return response;
  }

  // B. Control de acceso para administradores
  const {
    data: { session },
  } = await supabase.auth.getSession();

  // Si ya existen usuarios, la página de registro ya no es accesible.
  if (pathname === '/signup') {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Si el usuario NO está autenticado y NO es una página de login, ir a login
  if (!session && !isAuthPageRoute) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  
  // Si el usuario SÍ está autenticado e intenta ir a login o a la raíz, ir al admin
  if (session && (isAuthPageRoute || pathname === '/')) {
    return NextResponse.redirect(new URL('/admin', request.url));
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
