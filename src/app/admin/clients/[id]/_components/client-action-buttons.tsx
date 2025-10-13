
"use client"

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
import { Button } from "@/components/ui/button";
import type { Client } from "@/types";
import { Archive, Edit, FilePen, Link as LinkIcon } from "lucide-react";
import { AssignAgreementDialog } from "../../_components/assign-agreement-dialog";
import { OnboardingFormDialog } from "./onboarding-form-dialog";

type ClientActionButtonsProps = {
    client: Client;
    onArchive: () => void;
    isArchiving: boolean;
    onCopyLink: (link: string, message: string) => void;
    orderLink: string | null;
}

const ActionButton = ({ children, ...props }: React.ComponentProps<typeof Button>) => (
    <Button
        variant="outline"
        className="flex flex-col items-center justify-center h-20 w-full gap-1 p-2 text-center text-xs sm:text-sm bg-background hover:bg-secondary/50"
        {...props}
    >
        {children}
    </Button>
);

export function ClientActionButtons({ client, onArchive, isArchiving, onCopyLink, orderLink }: ClientActionButtonsProps) {
    return (
        <div className="grid grid-cols-4 gap-2">
            <OnboardingFormDialog client={client}>
                <ActionButton>
                    <Edit className="h-6 w-6" />
                    <span>Editar Datos</span>
                </ActionButton>
            </OnboardingFormDialog>
            
            <AssignAgreementDialog client={client}>
                 <ActionButton>
                    <FilePen className="h-6 w-6" />
                    <span>Convenio</span>
                </ActionButton>
            </AssignAgreementDialog>

            <ActionButton disabled={!orderLink} onClick={() => onCopyLink(orderLink!, 'Enlace de pedido copiado!')}>
                <LinkIcon className="h-6 w-6" />
                <span>Link Pedido</span>
            </ActionButton>

            <AlertDialog>
                <AlertDialogTrigger asChild>
                     <ActionButton variant="destructive">
                        <Archive className="h-6 w-6" />
                        <span>Archivar</span>
                    </ActionButton>
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
        </div>
    )
}
