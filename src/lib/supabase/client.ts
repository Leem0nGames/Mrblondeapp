import { createBrowserClient } from '@supabase/ssr'

// Define a function to create a Supabase client for client-side operations.
// This function initializes a new client on every call, which is the recommended
// pattern for client components. It can also be used in Server Actions that
// need to run with anonymous privileges.
export function createClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('CRITICAL: Missing Supabase environment variables on the client. The application will not work correctly. Check your .env.local file and ensure variables are prefixed with NEXT_PUBLIC_');
    // We return a dummy client to prevent an immediate crash on the client-side.
    // Supabase-dependent functionality will fail, but the app won't hard-crash.
    return createBrowserClient('http://localhost:54321', 'dummy-anon-key');
  }
  
  return createBrowserClient(
    supabaseUrl,
    supabaseAnonKey
  )
}
