
import { type NextRequest, NextResponse } from 'next/server';
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { supabaseAdmin } from './lib/supabase/admin';

// Helper function to check if users exist in the database.
// This uses the admin client, so it should be used carefully.
async function hasUsers(): Promise<boolean> {
  const { data, error } = await supabaseAdmin.auth.admin.listUsers();
  if (error) {
    console.error('Middleware: Error checking for users:', error.message);
    // In case of an error (e.g., service key not configured),
    // it's safer to assume users exist to prevent multiple sign-ups.
    return true; 
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

  // It's crucial to refresh the session in the middleware
  const { data: { session } } = await supabase.auth.getSession();
  
  const { pathname } = request.nextUrl;

  const usersExist = await hasUsers();
  const isAuthRoute = pathname === '/login' || pathname === '/signup';
  const isAdminRoute = pathname.startsWith('/admin');
  const isOrderRoute = pathname.startsWith('/pedido');

  // --- 1. Handle First-Time Setup ---
  if (!usersExist) {
    // If no users exist, the only allowed page is the signup page.
    if (pathname !== '/signup') {
      return NextResponse.redirect(new URL('/signup', request.url));
    }
    // Allow the request to proceed to the signup page.
    return response;
  }

  // --- 2. Handle App After Setup ---

  // If users exist, the signup page is no longer accessible.
  if (pathname === '/signup') {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Allow public access to order pages
  if (isOrderRoute) {
    return response;
  }
  
  // If the user is NOT authenticated
  if (!session) {
    // If they try to access a protected admin route, redirect to login.
    if (isAdminRoute || pathname === '/') {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  // If the user IS authenticated
  if (session) {
    // If they try to access an auth page (login), redirect to the admin dashboard.
    if (isAuthRoute || pathname === '/') {
      return NextResponse.redirect(new URL('/admin', request.url));
    }
  }
  
  // For all other cases, allow the request.
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
