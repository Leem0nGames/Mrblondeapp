
import { hasUsers } from '@/app/actions/user.actions';
import { getPublicLogoUrl } from '@/app/admin/actions/settings.actions';
import { Logo } from '@/app/logo';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { LoginForm } from './_components/login-form';
import Link from 'next/link';
import { Button } from '@/components/ui/button';

export default async function LoginPage() {
  const usersExist = await hasUsers();
  const logo_url = await getPublicLogoUrl();

  return (
    <div className="flex items-center justify-center min-h-screen bg-muted/40">
      <Card className="w-full max-w-sm">
        <CardHeader className="text-center">
          <div className="mb-4 flex justify-center">
            <Logo showText={true} logoUrl={logo_url} />
          </div>
          <CardTitle className="text-2xl">Admin Login</CardTitle>
          <CardDescription>
            {usersExist
              ? 'Ingresa tus credenciales para acceder al panel.'
              : 'No hay cuentas de administrador configuradas.'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {usersExist ? (
            <LoginForm />
          ) : (
            <div className="text-center">
              <p className="text-sm text-muted-foreground mb-4">
                Crea la primera cuenta para empezar a usar el sistema.
              </p>
              <Button asChild className="w-full">
                <Link href="/signup">Ir a la página de registro</Link>
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
