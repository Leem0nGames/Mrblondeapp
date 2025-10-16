
"use client"

import { useCallback, useEffect, useState } from "react";
import type { Client } from "@/types";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Archive, Copy, Edit, FilePen, Link as LinkIcon, MoreVertical, Check } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
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
import { ClientActionButtons } from "./client-action-buttons";


const CopyableField = ({ label, value, onCopy }: { label: string; value: string | null; onCopy: (text: string, message: string) => void; }) => {
    const [hasCopied, setHasCopied] = useState(false);

    const handleCopy = (e: React.MouseEvent) => {
        e.stopPropagation();
        if (!value) return;
        onCopy(value, `${label} copiado`);
        setHasCopied(true);
        setTimeout(() => setHasCopied(false), 2000);
    };

    return (
        <div className="group relative flex items-center gap-2">
            <span className="text-muted-foreground text-sm">{value || 'No disponible'}</span>
             {value && (
                <Button variant="ghost" size="icon" className="h-6 w-6 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity" onClick={handleCopy}>
                    {hasCopied ? <Check className="h-4 w-4 text-green-500" /> : <Copy className="h-4 w-4" />}
                    <span className="sr-only">Copiar {label}</span>
                </Button>
            )}
        </div>
    );
};


export function ClientHeader({ 
    client, 
    onArchive, 
    isArchiving, 
    onCopyLink, 
    orderLink,
    editDialog,
    agreementDialog,
}: { 
    client: Client;
    onArchive: () => void;
    isArchiving: boolean;
    onCopyLink: (link: string | null, message: string, errorMessage?: string) => void;
    orderLink: string | null;
    editDialog: React.ReactNode;
    agreementDialog: React.ReactNode;
 }) {
  const [onboardingLink, setOnboardingLink] = useState<string | null>(null);

  useEffect(() => {
    if (client.onboarding_token) {
      setOnboardingLink(`${window.location.origin}/onboarding/${client.onboarding_token}`);
    }
  }, [client.onboarding_token]);


  return (
    <div className="w-full">
      <div className="relative flex flex-col items-center justify-center rounded-lg bg-card p-6 shadow-sm gap-2">
        <div className="absolute top-4 right-4">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon">
                <MoreVertical className="h-5 w-5" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent>
               <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
                  {editDialog}
               </DropdownMenuItem>
               <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
                  {agreementDialog}
               </DropdownMenuItem>

                <DropdownMenuSeparator />
                <DropdownMenuItem 
                    onClick={() => onCopyLink(orderLink, 'Enlace de pedido copiado!', 'El cliente debe estar activo para tener un enlace de pedido.')} 
                    disabled={!orderLink}>
                    <LinkIcon className="mr-2 h-4 w-4" />
                    Copiar Link Pedido
                </DropdownMenuItem>
                 <DropdownMenuItem 
                    onClick={() => onCopyLink(onboardingLink, 'Enlace de alta copiado!', 'Este cliente ya completó el alta.')}
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
                            <AlertDialogAction onClick={onArchive} disabled={isArchiving} className="bg-destructive hover:bg-destructive/90">
                                {isArchiving ? "Archivando..." : "Confirmar Archivo"}
                            </AlertDialogAction>
                        </AlertDialogFooter>
                    </AlertDialogContent>
                 </AlertDialog>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <Avatar className="w-24 h-24 mb-2">
          <AvatarFallback className="text-4xl">
            {client.contact_name?.charAt(0).toUpperCase() ?? 'C'}
          </AvatarFallback>
        </Avatar>
        <div className="text-center">
            <CopyableField label="Nombre" value={client.contact_name} onCopy={onCopyLink} />
            <CopyableField label="Email" value={client.email} onCopy={onCopyLink} />
            <CopyableField label="CUIT" value={client.cuit} onCopy={onCopyLink} />
        </div>
        <div className="w-full pt-4">
             <ClientActionButtons 
                onArchive={onArchive}
                isArchiving={isArchiving}
                onCopyLink={onCopyLink}
                orderLink={orderLink}
                editDialog={editDialog}
                agreementDialog={agreementDialog}
            />
        </div>
      </div>
    </div>
  );
}
