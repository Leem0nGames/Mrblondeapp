'use client';

import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { login, type AuthState } from '@/app/actions/user.actions';

const initialState: AuthState = {
  error: null,
};

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <Button type="submit" className="w-full" disabled={pending}>
      {pending ? 'Accediendo...' : 'Acceder'}
    </Button>
  );
}

export function LoginForm() {
  const [state, formAction] = useActionState(login, initialState);

  return (
    <form action={formAction} className="grid gap-4">
      <div className="grid gap-2">
        <Label htmlFor="pin">PIN de Administrador</Label>
        <Input 
            id="pin" 
            type="password" 
            name="pin" 
            required 
            maxLength={4}
            className="text-center text-lg tracking-[1em]"
        />
        {state?.error?.message && (
          <p className="text-sm text-destructive">{state.error.message}</p>
        )}
      </div>
      <SubmitButton />
    </form>
  );
}
