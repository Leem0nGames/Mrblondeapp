
import { type NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/middleware';
import { hasUsers } from '@/app/actions/user.actions';

// Define las rutas públicas fijas
const publicRoutes = ['/login', '/signup'];

export async function middleware(request: NextRequest) {
  const { supabase, response } = await createClient(request);
  const { pathname } = request.nextUrl;

  // -------------------------------------------------------------------------
  // 1. RUTAS PÚBLICAS CRÍTICAS (CLIENTES)
  // Estas rutas NUNCA deben requerir autenticación ni chequeos de setup.
  // -------------------------------------------------------------------------
  const isOrderRoute = pathname.startsWith('/pedido');
  const isOnboardingRoute = pathname.startsWith('/onboarding');

  if (isOrderRoute || isOnboardingRoute) {
    return response;
  }

  // -------------------------------------------------------------------------
  // 2. LÓGICA DE ADMINISTRACIÓN (SETUP Y AUTH)
  // -------------------------------------------------------------------------
  
  // Refrescamos la sesión para rutas que no son de clientes
  const {
    data: { session },
  } = await supabase.auth.getSession();

  const isAuthPageRoute = publicRoutes.includes(pathname);

  // A. Verificación de Primer Arranque (¿Hay algún admin creado?)
  const usersExist = await hasUsers();

  if (!usersExist) {
    // Si no hay usuarios, forzamos el registro del primer admin.
    if (pathname !== '/signup') {
      return NextResponse.redirect(new URL('/signup', request.url));
    }
    return response;
  }

  // B. Protección de Acceso
  
  // Si ya existen usuarios, la página de registro ya no es accesible.
  if (pathname === '/signup') {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Redirección por falta de sesión: Si no está logueado y no es una página de auth (login)
  if (!session && !isAuthPageRoute) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  
  // Redirección por sesión activa: Si ya está logueado e intenta ir a login o a la raíz
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
