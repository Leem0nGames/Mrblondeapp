import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';

export default async function HomePage() {
  const supabase = await createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  // Si hay una sesión activa, ir directamente al panel de administración.
  if (session) {
    redirect('/admin');
  }

  // Si no hay sesión, la página de login se encargará de determinar
  // si debe mostrar el formulario de login o el enlace de registro.
  redirect('/login');
}

// Página de inicio mejorada con contexto
export async function getServerSideProps() {
  const supabase = await createClient();
  const { data: { session } } = await supabase.auth.getSession();
  
  return {
    props: {
      hasSession: !!session,
      isNewUser: session ? await supabase.auth.hasUsers() : false
    }
  };
}

// Componente de página de inicio mejorada
export default function HomePageWithContext({ hasSession, isNewUser }) {
  if (hasSession) {
    redirect('/admin');
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      <div className="container mx-auto px-4 text-center">
        <div className="max-w-2xl mx-auto">
          <div className="mb-8">
            <Logo showText={true} />
          </div>
          
          <h1 className="text-4xl md:text-6xl font-bold text-white mb-6">
            Blonde Orders
          </h1>
          
          <p className="text-xl text-slate-300 mb-8">
            Sistema moderno de gestión de pedidos comerciales
          </p>
          
          <div className="space-y-4">
            <div className="bg-white/10 backdrop-blur-sm rounded-lg p-6 text-left">
              <h3 className="text-lg font-semibold text-white mb-3">
                ¿Eres nuevo?
              </h3>
              <p className="text-slate-300 mb-4">
                Este es un paso único para configurar el super-administrador del sistema.
              </p>
              <div className="flex gap-4">
                <Button asChild className="w-full">
                  <Link href="/signup">
                    Crear Cuenta de Administrador
                  </Link>
                </Button>
                <Button asChild variant="outline" className="w-full">
                  <Link href="/login">
                    Iniciar Sesión
                  </Link>
                </Button>
              </div>
            </div>
            
            <div className="bg-white/10 backdrop-blur-sm rounded-lg p-6 text-left">
              <h3 className="text-lg font-semibold text-white mb-3">
                ¿Ya tienes cuenta?
              </h3>
              <p className="text-slate-300 mb-4">
                Accede al panel de administración para gestionar tu negocio.
              </p>
              <Button asChild className="w-full">
                <Link href="/login">
                  Ir al Panel de Administración
                </Link>
              </Button>
            </div>
          </div>
          
          <div className="mt-12 pt-8 border-t border-white/10">
            <h4 className="text-sm font-medium text-slate-400 mb-2">
              Características principales
            </h4>
            <div className="grid grid-cols-2 gap-4">
              <div className="flex items-center gap-3 text-slate-300">
                <CheckCircle className="h-4 w-4" />
                <span>Gestión de clientes</span>
              </div>
              <div className="flex items-center gap-3 text-slate-300">
                <CheckCircle className="h-4 w-4" />
                <span>Control de productos</span>
              </div>
              <div className="flex items-center gap-3 text-slate-300">
                <CheckCircle className="h-4 w-4" />
                <span>Pedidos online</span>
              </div>
              <div className="flex items-center gap-3 text-slate-300">
                <CheckCircle className="h-4 w-4" />
                <span>Convenios comerciales</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Componentes adicionales para la página de inicio
import { Logo } from '@/app/logo';
import { Button } from '@/components/ui/button';
import { CheckCircle } from 'lucide-react';
import Link from 'next/link';

// Exportamos el componente original para compatibilidad
export { HomePage as default };