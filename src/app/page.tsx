import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';

export default async function HomePage() {
  const supabase = await createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  // The middleware already handles redirection logic based on session and user existence.
  // This page component acts as a final fallback.
  // If there's a session, go to the admin dashboard.
  if (session) {
    redirect('/admin');
  }

  // If there's no session, the middleware will have already redirected to /login or /signup.
  // This redirect is a safety net.
  redirect('/login');
}
