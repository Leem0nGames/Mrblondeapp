
import { redirect } from 'next/navigation';

export default function AdminRootPage() {
  // Por defecto, la página principal del admin redirige a la gestión de convenios.
  redirect('/admin/agreements');
}
