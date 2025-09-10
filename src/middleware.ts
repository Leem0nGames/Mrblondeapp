import { type NextRequest, NextResponse } from 'next/server';
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { hasUsers } from '@/app/actions/user.actions';

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

  // --- Lógica de Registro vs Login ---
  
  // Si no hay usuarios en la DB, solo se puede acceder a /signup
  const usersExist = await hasUsers();

  if (!usersExist && pathname !== '/signup') {
    return NextResponse.redirect(new URL('/signup', request.url));
  }
  
  // Si ya existen usuarios, la página de signup se convierte en inaccesible
  if (usersExist && pathname === '/signup') {
    return NextResponse.redirect(new URL('/login', request.url));
  }


  // --- Lógica de Protección de Rutas ---

  // Si no hay sesión y se intenta acceder a una ruta protegida
  if (!session && pathname.startsWith('/admin')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Si hay sesión y se intenta acceder a login o signup
  if (session && (pathname === '/login' || pathname === '/signup')) {
    return NextResponse.redirect(new URL('/admin', request.url));
  }

  // Si no hay usuarios y se va a la raíz, redirigir a signup
  if (!usersExist && pathname === '/') {
     return NextResponse.redirect(new URL('/signup', request.url));
  }
  
  // Si hay usuarios y se va a la raíz, redirigir a login
  if (usersExist && !session && pathname === '/') {
     return NextResponse.redirect(new URL('/login', request.url));
  }
  
  // Si hay sesión y se va a la raíz, redirigir a admin
  if(session && pathname === '/') {
    return NextResponse.redirect(new URL('/admin', request.url));
  }


  return response;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|api/).*)',
  ],
};
