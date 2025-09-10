
import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import { hasUsers } from './actions/user.actions';

export default async function HomePage() {
  const usersExist = await hasUsers();

  // If no users exist in the database, the middleware should have already
  // redirected to /signup. This is a server-side safeguard.
  if (!usersExist) {
    redirect('/signup');
  }

  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  // If users exist but there is no active session, redirect to the login page.
  if (!session) {
    redirect('/login');
  }

  // If users exist and there is an active session, redirect to the admin panel.
  redirect('/admin');
}
