'use client';

import { useActionState, useFormStatus } from 'react-dom';
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
      {pending ? 'Creando cuenta...' : 'Crear Cuenta'}
    </Button>
  );
}

export function SignupForm() {
  const [state, formAction] = useActionState(signupSuperAdmin, initialState);

  return (
    <form action={formAction} className="grid gap-4">
      <div className="grid gap-2">
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          type="email"
          name="email"
          placeholder="admin@ejemplo.com"
          required
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="password">Contraseña</Label>
        <Input id="password" type="password" name="password" required />
        {state.error?.message && (
          <p className="text-sm text-red-500">{state.error.message}</p>
        )}
      </div>
      <SubmitButton />
    </form>
  );
}
