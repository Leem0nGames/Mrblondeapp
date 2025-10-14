
"use client"

import { useCallback, useMemo, useEffect, useState } from "react";
import type { Client } from "@/types";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Archive, Copy, Edit, FilePen, Link as LinkIcon, MoreVertical } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import { useToast } from "@/hooks/use-toast";
import { AssignAgreementDialog } from "../../_components/assign-agreement-dialog";
import { OnboardingFormDialog } from "./onboarding-form-dialog";
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
import { useTransition } from "react";
import { deleteClient } from "@/app/actions/admin.actions";
import { ClientActionButtons } from "./client-action-buttons";


export function ClientHeader({ client }: { client: Client }) {
  const { toast } = useToast();
  const [isPending, startTransition] = useTransition();

  const [orderLink, setOrderLink] = useState<string | null>(null);
  const [onboardingLink, setOnboardingLink] = useState<string | null>(null);

  useEffect(() => {
    // These values depend on `window.location.origin`, which is only available on the client.
    // We set them in an effect to avoid hydration mismatches.
    if (client.agreement_id && client.status === 'active') {
      setOrderLink(`${window.location.origin}/pedido/${client.agreement_id}`);
    }
    if (client.onboarding_token) {
      setOnboardingLink(`${window.location.origin}/onboarding/${client.onboarding_token}`);
    }
  }, [client.agreement_id, client.status, client.onboarding_token]);


  const copyToClipboard = useCallback((textToCopy: string | null, toastMessage: string, errorMessage?: string) => {
    if (!textToCopy) {
      toast({ title: "No hay enlace para copiar", description: errorMessage || "El recurso no está disponible.", variant: "destructive"});
      return;
    }
    navigator.clipboard.writeText(textToCopy);
    toast({ title: toastMessage });
  }, [toast]);

  const handleArchive = () => {
    startTransition(async () => {
      const result = await deleteClient(client.id);
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: "Cliente archivado correctamente." });
      }
    });
  };

  return (
    <div className="w-full">
      <div className="relative flex flex-col items-center justify-center rounded-lg bg-card p-6 shadow-sm gap-4">
        <div className="absolute top-4 right-4">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon">
                <MoreVertical className="h-5 w-5" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent>
               <OnboardingFormDialog client={client}>
                    <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
                        <Edit className="mr-2 h-4 w-4" />
                        Editar Datos
                    </DropdownMenuItem>
                </OnboardingFormDialog>
                <AssignAgreementDialog client={client}>
                    <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
                        <FilePen className="mr-2 h-4 w-4" />
                        Asignar Convenio
                    </DropdownMenuItem>
                </AssignAgreementDialog>
                <DropdownMenuSeparator />
                <DropdownMenuItem 
                    onClick={() => copyToClipboard(orderLink, 'Enlace de pedido copiado!', 'El cliente debe estar activo para tener un enlace de pedido.')} 
                    disabled={!orderLink}>
                    <LinkIcon className="mr-2 h-4 w-4" />
                    Copiar Link Pedido
                </DropdownMenuItem>
                 <DropdownMenuItem 
                    onClick={() => copyToClipboard(onboardingLink, 'Enlace de alta copiado!', 'Este cliente ya completó el alta.')}
                    disabled={client.status !== 'pending_onboarding'}
                 >
                    <Copy className="mr-2 h-4 w-4" />
                    Copiar Link Alta
                </DropdownMenuItem>
                 <DropdownMenuSeparator />
                 <AlertDialog>
                    <AlertDialogTrigger asChild>
                        <DropdownMenuItem className="text-destructive" onSelect={(e) => e.preventDefault()}>
                            <Archive className="mr-2 h-4 w-4" />
                            Archivar Cliente
                        </DropdownMenuItem>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                        <AlertDialogHeader>
                            <AlertDialogTitle>¿Archivar Cliente?</AlertDialogTitle>
                            <AlertDialogDescription>
                                Esta acción ocultará al cliente de la lista principal, pero no borrará sus pedidos asociados.
                            </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                            <AlertDialogCancel>Cancelar</AlertDialogCancel>
                            <AlertDialogAction onClick={handleArchive} disabled={isPending} className="bg-destructive hover:bg-destructive/90">
                                {isPending ? "Archivando..." : "Confirmar Archivo"}
                            </AlertDialogAction>
                        </AlertDialogFooter>
                    </AlertDialogContent>
                 </AlertDialog>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <Avatar className="w-24 h-24">
          <AvatarFallback className="text-4xl">
            {client.contact_name?.charAt(0).toUpperCase() ?? 'C'}
          </AvatarFallback>
        </Avatar>
        <div className="text-center">
            <h1 className="text-3xl font-bold tracking-tight">{client.contact_name}</h1>
            <p className="text-muted-foreground">{client.cuit ?? 'CUIT no disponible'}</p>
            <p className="text-muted-foreground text-sm">{client.email ?? 'Email no disponible'}</p>
        </div>
        <div className="w-full pt-4">
             <ClientActionButtons 
                client={client}
                onArchive={handleArchive}
                isArchiving={isPending}
                onCopyLink={copyToClipboard}
                orderLink={orderLink}
            />
        </div>
      </div>
    </div>
  );
}
