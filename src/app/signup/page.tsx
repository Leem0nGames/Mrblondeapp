
import { hasUsers } from '@/app/actions/user.actions';
import { Logo } from '@/components/logo';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { SignupForm } from './_components/signup-form';
import { redirect } from 'next/navigation';

// Esta página es un Server Component.
// Realiza una comprobación de seguridad crítica en el servidor antes de renderizar.
export default async function SignupPage() {
  // Comprobamos si ya existe algún usuario en el sistema.
  // Si ya existe, redirigimos inmediatamente al login para que no se pueda ver esta página.
  const usersExist = await hasUsers();
  if (usersExist) {
    redirect('/login');
  }

  return (
    <div className="flex items-center justify-center min-h-screen bg-muted/40">
      <Card className="w-full max-w-sm">
        <CardHeader className="text-center">
          <div className="mb-4 flex justify-center">
            <Logo showText={true} />
          </div>
          <CardTitle className="text-2xl">Crear Cuenta de Administrador</CardTitle>
          <CardDescription>
            Este es un paso único para configurar el super-administrador del sistema.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <SignupForm />
        </CardContent>
      </Card>
    </div>
  );
}
