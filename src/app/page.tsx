
import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import { hasUsers } from './actions/user.actions';

export default async function HomePage() {
  const usersExist = await hasUsers();

  if (!usersExist) {
    redirect('/signup');
  }

  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    redirect('/login');
  }

  redirect('/admin');
}
