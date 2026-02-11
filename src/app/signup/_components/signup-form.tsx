'use client';

import { useFormState, useFormStatus } from 'react-dom';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { signupSuperAdmin } from '@/app/actions/user.actions';
import type { AuthState } from '@/types';
import { Check, X } from 'lucide-react';

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

const passwordRequirements = [
  { label: 'Al menos 8 caracteres', test: (p: string) => p.length >= 8 },
  { label: 'Una letra mayúscula', test: (p: string) => /[A-Z]/.test(p) },
  { label: 'Una letra minúscula', test: (p: string) => /[a-z]/.test(p) },
  { label: 'Un número', test: (p: string) => /\d/.test(p) },
  { label: 'Un carácter especial (!@#$%^&*)', test: (p: string) => /[!@#$%^&*]/.test(p) },
];

export function SignupForm() {
  const [state, formAction] = useFormState(signupSuperAdmin, initialState);
  const [password, setPassword] = useState('');

  return (
    <form action={formAction} className="grid gap-4">
      <div className="grid gap-2">
        <Label htmlFor="email">Email de Administrador</Label>
        <Input
          id="email"
          type="email"
          name="email"
          placeholder="admin@ejemplo.com"
          required
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="password">Contraseña de Administrador</Label>
        <Input
          id="password"
          type="password"
          name="password"
          required
          placeholder="••••••••"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <div className="space-y-2 pt-2">
          {passwordRequirements.map((req, index) => {
            const isValid = req.test(password);
            return (
              <div key={index} className="flex items-center gap-2 text-xs">
                {isValid ? (
                  <Check className="h-3 w-3 text-green-500" />
                ) : (
                  <X className="h-3 w-3 text-muted-foreground" />
                )}
                <span className={isValid ? 'text-green-600' : 'text-muted-foreground'}>
                  {req.label}
                </span>
              </div>
            );
          })}
        </div>
        {state?.error?.message && (
          <p className="text-sm text-destructive">{state.error.message}</p>
        )}
      </div>
      <SubmitButton />
    </form>
  );
}
