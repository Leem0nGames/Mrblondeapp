

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
  DialogClose,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";
import type { Agreement, Client } from "@/types";
import { Copy, Check, FilePen } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { AssignAgreementDialog } from "./assign-agreement-dialog";
import { useRouter } from "next/navigation";


export function CreateClientDialog({ children, open, onOpenChange }: { children: React.ReactNode, open: boolean, onOpenChange: (open: boolean) => void }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  
  const [invitation, setInvitation] = useState<{link: string, client: Pick<Client, 'id' | 'agreement_id' | 'onboarding_token'>} | null>(null);
  const [hasCopied, setHasCopied] = useState(false);

  const handleInvite = () => {
      startTransition(async () => {
          const result = await createClientForInvitation();
          if (result.error || !result.data) {
              toast({ title: "Error", description: result.error?.message || 'No se pudo crear la invitación para el cliente.', variant: "destructive" });
          } else {
              const link = `${window.location.origin}/onboarding/${result.data.onboarding_token}`;
              setInvitation({ link, client: result.data });
          }
      });
  };

  const handleCopyToClipboard = () => {
    if (!invitation) return;
    navigator.clipboard.writeText(invitation.link);
    setHasCopied(true);
    toast({ title: "Enlace copiado al portapapeles" });
    setTimeout(() => setHasCopied(false), 2000);
  };

  const handleDialogChange = (isOpen: boolean) => {
      onOpenChange(isOpen);
      if (!isOpen) {
          setTimeout(() => {
            setInvitation(null);
            setHasCopied(false);
          }, 300);
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
                 <div className="text-center py-6">
                    <Button onClick={handleInvite} disabled={isPending} className="w-full sm:w-auto">
                        {isPending ? "Generando..." : "Generar Enlace de Invitación"}
                    </Button>
                 </div>
            )}
        </div>
        
        <DialogFooter>
           <DialogClose asChild>
                <Button variant="outline">
                    {invitation ? "Listo" : "Cancelar"}
                </Button>
           </DialogClose>
            {invitation && (
                 <Button onClick={handleInvite} disabled={isPending} variant="ghost">
                    {isPending ? "Generando..." : "Generar Otro Enlace"}
                </Button>
            )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
