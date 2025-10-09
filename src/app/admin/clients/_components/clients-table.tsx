
"use client";

import { useTransition, useCallback } from "react";
import { MoreHorizontal, Trash2, Copy, Link as LinkIcon, Archive } from "lucide-react";
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
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Card, CardContent, CardFooter } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { deleteClient } from "@/app/actions/admin.actions";
import type { Client } from "@/types";
import { AssignAgreementDialog } from "./assign-agreement-dialog";
import { cn } from "@/lib/utils";

const statusMap: Record<Client['status'], { label: string; variant: "default" | "secondary" | "destructive" }> = {
    pending_onboarding: { label: "Pendiente de Alta", variant: "secondary" },
    pending_agreement: { label: "Pendiente de Convenio", variant: "destructive" },
    active: { label: "Activo", variant: "default" },
    archived: { label: "Archivado", variant: "secondary" },
};

export function ClientsTable({ clients }: { clients: Client[] }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleArchive = (clientId: string) => {
    startTransition(async () => {
      const result = await deleteClient(clientId); // This action now archives the client
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: "Cliente archivado correctamente." });
      }
    });
  };

  const copyToClipboard = useCallback((textToCopy: string, toastMessage: string) => {
    navigator.clipboard.writeText(textToCopy);
    toast({ title: toastMessage });
  }, [toast]);
  
  const getOrderLink = useCallback((agreementId: string | null) => {
      if (!agreementId) return null;
      const host = window.location.host;
      const protocol = window.location.protocol;
      return `${protocol}//${host}/pedido/${agreementId}`;
  }, []);

  return (
    <Card>
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nombre</TableHead>
              <TableHead className="hidden sm:table-cell">Email</TableHead>
              <TableHead className="hidden md:table-cell">Convenio</TableHead>
              <TableHead>Estado</TableHead>
              <TableHead>
                <span className="sr-only">Acciones</span>
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {clients.map((client) => (
              <TableRow key={client.id}>
                <TableCell className="font-medium">{client.contact_name || "Cliente pendiente..."}</TableCell>
                <TableCell className="hidden sm:table-cell">{client.email}</TableCell>
                <TableCell className="hidden md:table-cell">
                    {client.agreements?.agreement_name || <span className="text-muted-foreground">Sin asignar</span>}
                </TableCell>
                <TableCell>
                  <Badge variant={statusMap[client.status].variant}>
                    {statusMap[client.status].label}
                  </Badge>
                </TableCell>
                <TableCell className="text-right">
                    <div className="flex items-center justify-end gap-2">
                         {client.status === 'active' && client.agreement_id && (
                             <Button variant="outline" size="sm" onClick={() => copyToClipboard(getOrderLink(client.agreement_id)!, 'Enlace de pedido copiado!')}>
                                <LinkIcon className="mr-2 h-4 w-4" />
                                Copiar Link Pedido
                            </Button>
                         )}
                        <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                            <Button aria-haspopup="true" size="icon" variant="ghost">
                                <MoreHorizontal className="h-4 w-4" />
                                <span className="sr-only">Menú</span>
                            </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                            <DropdownMenuLabel>Acciones</DropdownMenuLabel>
                             <AssignAgreementDialog client={client}>
                                <DropdownMenuItem onSelect={(e) => e.preventDefault()}>Asignar Convenio</DropdownMenuItem>
                             </AssignAgreementDialog>
                            <DropdownMenuItem 
                                onSelect={() => copyToClipboard(`${window.location.origin}/onboarding/${client.onboarding_token}`, 'Enlace de alta copiado!')}
                                disabled={client.status !== 'pending_onboarding'}
                            >
                                <Copy className="mr-2 h-4 w-4" />
                                Copiar Link de Alta
                            </DropdownMenuItem>
                            <DropdownMenuSeparator />
                            <AlertDialog>
                                <AlertDialogTrigger asChild>
                                <DropdownMenuItem
                                    className="text-destructive"
                                    onSelect={(e) => e.preventDefault()}
                                >
                                    <Archive className="mr-2 h-4 w-4" />
                                    Archivar
                                </DropdownMenuItem>
                                </AlertDialogTrigger>
                                <AlertDialogContent>
                                <AlertDialogHeader>
                                    <AlertDialogTitle>¿Archivar Cliente?</AlertDialogTitle>
                                    <AlertDialogDescription>
                                        Esta acción ocultará al cliente de la lista principal, pero no borrará sus pedidos asociados. Podrás verlo en un futuro desde una sección de archivados.
                                    </AlertDialogDescription>
                                </AlertDialogHeader>
                                <AlertDialogFooter>
                                    <AlertDialogCancel>Cancelar</AlertDialogCancel>
                                    <AlertDialogAction
                                        onClick={() => handleArchive(client.id)}
                                        disabled={isPending}
                                        className="bg-destructive hover:bg-destructive/90"
                                    >
                                        {isPending ? "Archivando..." : "Confirmar Archivo"}
                                    </AlertDialogAction>
                                </AlertDialogFooter>
                                </AlertDialogContent>
                            </AlertDialog>
                            </DropdownMenuContent>
                        </DropdownMenu>
                   </div>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
      <CardFooter>
         <div className="text-xs text-muted-foreground">
            Mostrando <strong>{clients.length}</strong> de <strong>{clients.length}</strong> clientes.
          </div>
      </CardFooter>
    </Card>
  );
}
