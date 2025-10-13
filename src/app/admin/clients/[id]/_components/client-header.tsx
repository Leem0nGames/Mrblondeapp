
"use client"

import { useCallback } from "react";
import type { Client } from "@/types";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Archive, Copy, Edit, Link as LinkIcon, MoreVertical } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useToast } from "@/hooks/use-toast";
import { AssignAgreementDialog } from "../../_components/assign-agreement-dialog";
import { OnboardingFormDialog } from "./onboarding-form-dialog";

export function ClientHeader({ client }: { client: Client }) {
  const { toast } = useToast();

  const getOrderLink = useCallback((agreementId: string | null) => {
    if (!agreementId) return null;
    const host = window.location.host;
    const protocol = window.location.protocol;
    return `${protocol}//${host}/pedido/${agreementId}`;
  }, []);

  const copyToClipboard = useCallback((textToCopy: string, toastMessage: string) => {
    if (!textToCopy) {
      toast({ title: "No hay enlace para copiar", variant: "destructive"});
      return;
    }
    navigator.clipboard.writeText(textToCopy);
    toast({ title: toastMessage });
  }, [toast]);

  return (
    <div className="w-full">
      <div className="relative flex flex-col items-center justify-center rounded-lg bg-card p-8 shadow-sm">
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
                        <Edit className="mr-2 h-4 w-4" />
                        Asignar Convenio
                    </DropdownMenuItem>
                </AssignAgreementDialog>
                <DropdownMenuItem onClick={() => copyToClipboard(getOrderLink(client.agreement_id)!, 'Enlace de pedido copiado!')}>
                    <LinkIcon className="mr-2 h-4 w-4" />
                    Copiar Link Pedido
                </DropdownMenuItem>
                 <DropdownMenuItem onClick={() => copyToClipboard(`${window.location.origin}/onboarding/${client.onboarding_token}`, 'Enlace de alta copiado!')}>
                    <Copy className="mr-2 h-4 w-4" />
                    Copiar Link Alta
                </DropdownMenuItem>
                <DropdownMenuItem className="text-destructive">
                    <Archive className="mr-2 h-4 w-4" />
                    Archivar Cliente
                </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <Avatar className="w-24 h-24 mb-4">
          <AvatarFallback className="text-4xl">
            {client.contact_name?.charAt(0).toUpperCase() ?? 'C'}
          </AvatarFallback>
        </Avatar>
        <h1 className="text-3xl font-bold tracking-tight">{client.contact_name}</h1>
        <p className="text-muted-foreground">{client.cuit ?? 'CUIT no disponible'}</p>
        <p className="text-muted-foreground">{client.email ?? 'Email no disponible'}</p>
      </div>
    </div>
  );
}
