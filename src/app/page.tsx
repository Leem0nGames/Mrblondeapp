
import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import { hasUsers } from './actions/user.actions';

export default async function HomePage() {
  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  // Si el usuario tiene una sesión activa, lo llevamos al panel de admin
  if (session) {
    redirect('/admin');
  }

  // Si no hay sesión, comprobamos si ya se creó el usuario admin
  const usersExist = await hasUsers();

  // Si no hay usuarios, lo llevamos a la página de registro
  if (!usersExist) {
    redirect('/signup');
  }
  
  // Si ya hay usuarios pero no hay sesión, lo llevamos al login
  redirect('/login');
}
