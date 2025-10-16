
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

type ClientActionButtonsProps = {
    onArchive: () => void;
    isArchiving: boolean;
    onCopyLink: (link: string, message: string) => void;
    orderLink: string | null;
    editDialog: React.ReactNode;
    agreementDialog: React.ReactNode;
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

export function ClientActionButtons({ onArchive, isArchiving, onCopyLink, orderLink, editDialog, agreementDialog }: ClientActionButtonsProps) {
    return (
        <div className="grid grid-cols-4 gap-2">
            {editDialog}
            
            {agreementDialog}

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

const ActionButtonWrapper = ({ children }: { children: React.ReactNode }) => (
     <ActionButton>
        {children}
    </ActionButton>
);

export { ActionButtonWrapper, ActionButton };
