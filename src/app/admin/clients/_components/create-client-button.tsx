
"use client";

import { useTransition, useCallback, cloneElement } from "react";
import { useToast } from "@/hooks/use-toast";
import { createClientOnboardingLink } from "@/app/actions/admin.actions";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";

export function CreateClientButton({ children }: { children: React.ReactElement }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleCreateAndCopy = () => {
    startTransition(async () => {
      const result = await createClientOnboardingLink();
      if (result.error) {
        toast({ title: "Error al crear enlace", description: result.error.message, variant: "destructive" });
      } else {
        const token = result.data?.onboarding_token;
        if (token) {
          const link = `${window.location.origin}/onboarding/${token}`;
          navigator.clipboard.writeText(link);
          toast({ 
              title: "¡Enlace de invitación creado y copiado!",
              description: "Puedes enviarle este enlace a tu nuevo cliente.",
          });
        }
      }
    });
  };

  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        {cloneElement(children, { disabled: isPending })}
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Generar Enlace de Invitación</AlertDialogTitle>
          <AlertDialogDescription>
            Se generará un enlace único para que un nuevo cliente complete sus datos. 
            Este enlace se copiará automáticamente a tu portapapeles.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <AlertDialogAction
            onClick={handleCreateAndCopy}
            disabled={isPending}
          >
            {isPending ? "Generando..." : "Generar y Copiar"}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
