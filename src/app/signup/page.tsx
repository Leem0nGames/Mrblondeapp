import { hasUsers, signupSuperAdmin, type AuthState } from '@/app/actions/user.actions';
import { Logo } from '@/components/logo';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { SignupForm } from './_components/signup-form';

// Esta página es un Server Component.
// Realiza una comprobación de seguridad crítica en el servidor antes de renderizar.
export default async function SignupPage() {
  // Comprobamos si ya existe algún usuario en el sistema.
  const usersExist = await hasUsers();

  return (
    <div className="flex items-center justify-center min-h-screen bg-muted/40">
      <Card className="w-full max-w-sm">
        <CardHeader className="text-center">
          <div className="mb-4 flex justify-center">
            <Logo showText={true} />
          </div>
          <CardTitle className="text-2xl">Crear Cuenta de Administrador</CardTitle>
          <CardDescription>
            {usersExist
              ? 'El registro de nuevas cuentas no está disponible.'
              : 'Esta será la única cuenta de administrador del sistema.'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {/* Si ya existen usuarios, no mostramos el formulario. */}
          {/* Esta es una doble capa de seguridad (UI + Server Action). */}
          {!usersExist ? (
            <SignupForm />
          ) : (
            <p className="text-center text-sm text-muted-foreground">
              Ya se ha configurado una cuenta de administrador.
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
