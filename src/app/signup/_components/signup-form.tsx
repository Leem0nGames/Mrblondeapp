'use client';

import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { signupSuperAdmin, type AuthState } from '@/app/actions/user.actions';

const initialState: AuthState = {
  error: null,
};

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <Button type="submit" className="w-full" disabled={pending}>
      {pending ? 'Creando cuenta...' : 'Crear Cuenta de Administrador'}
    </Button>
  );
}

export function SignupForm() {
  const [state, formAction] = useActionState(signupSuperAdmin, initialState);

  return (
    <form action={formAction} className="grid gap-4">
      <div className="grid gap-2">
        <Label htmlFor="email">Email de Administrador</Label>
        <Input
          id="email"
          type="email"
          name="email"
          placeholder="admin@blonde.com"
          required
          defaultValue="admin@blonde.com"
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="password">Contraseña de Administrador</Label>
        <Input 
          id="password" 
          type="password" 
          name="password" 
          required 
          defaultValue="admin1234"
        />
        <p className="text-xs text-muted-foreground">
          Por seguridad, el email debe ser 'admin@blonde.com' y la contraseña 'admin1234'.
        </p>
        {state?.error?.message && (
          <p className="text-sm text-destructive">{state.error.message}</p>
        )}
      </div>
      <SubmitButton />
    </form>
  );
}
