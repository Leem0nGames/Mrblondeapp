

"use client";

import { useState, useTransition, useEffect, useCallback } from "react";
import { z } from "zod";
import { useForm, FormProvider } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/actions/admin.actions";
import type { Agreement, Client } from "@/types";
import { Copy, Check, FilePen } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { AssignAgreementDialog } from "./assign-agreement-dialog";


export function CreateClientDialog({ children, open, onOpenChange }: { children: React.ReactNode, open: boolean, onOpenChange: (open: boolean) => void }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  
  const [invitation, setInvitation] = useState<{link: string, client: Pick<Client, 'id' | 'agreement_id'>} | null>(null);
  const [hasCopied, setHasCopied] = useState(false);

  const handleInvite = () => {
      startTransition(async () => {
          const result = await createClientForInvitation();
          if (result.error || !result.data) {
              toast({ title: "Error", description: result.error?.message || 'No se pudo crear la invitación', variant: "destructive" });
          } else {
              const link = `${window.location.origin}/onboarding/${result.data.onboarding_token}`;
              setInvitation({ link, client: result.data });
              toast({ title: "Invitación Creada", description: "Copia el enlace y compártelo con tu cliente." });
          }
      });
  };

  const handleCopyToClipboard = () => {
    if (!invitation) return;
    navigator.clipboard.writeText(invitation.link);
    setHasCopied(true);
    setTimeout(() => setHasCopied(false), 2000);
  };

  const handleDialogChange = (isOpen: boolean) => {
      onOpenChange(isOpen);
      if (!isOpen) {
          setInvitation(null);
      }
  }

  return (
    <Dialog open={open} onOpenChange={handleDialogChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Agregar Nuevo Cliente por Invitación</DialogTitle>
          <DialogDescription>
            Genera un enlace único para que el cliente complete sus datos. Puedes pre-asignar un convenio antes de enviar el enlace.
          </DialogDescription>
        </DialogHeader>

        <div className="py-4 space-y-6">
            {invitation ? (
                <div className="space-y-4">
                    <Alert>
                        <AlertTitle>¡Enlace Generado!</AlertTitle>
                        <AlertDescription className="break-all">
                            {invitation.link}
                        </AlertDescription>
                    </Alert>
                    <div className="flex flex-col sm:flex-row gap-2">
                        <Button onClick={handleCopyToClipboard} className="w-full">
                            {hasCopied ? <Check className="mr-2 h-4 w-4" /> : <Copy className="mr-2 h-4 w-4" />}
                            {hasCopied ? "Copiado" : "Copiar Enlace"}
                        </Button>
                        <AssignAgreementDialog client={invitation.client as Client}>
                            <Button variant="secondary" className="w-full">
                                <FilePen className="mr-2 h-4 w-4" />
                                {invitation.client.agreement_id ? 'Cambiar Convenio' : 'Asignar Convenio'}
                            </Button>
                        </AssignAgreementDialog>
                    </div>
                </div>
            ) : (
                <p className="text-sm text-muted-foreground text-center">
                    Haz clic en el botón para generar un nuevo enlace de invitación.
                </p>
            )}
        </div>
        
        <DialogFooter>
            <Button onClick={handleInvite} disabled={isPending} className="w-full" variant={invitation ? "outline" : "default"}>
                {isPending ? "Generando..." : invitation ? "Generar Otro Enlace" : "Generar Enlace de Invitación"}
            </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
