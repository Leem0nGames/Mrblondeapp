
"use client";

import { useTransition, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { MoreHorizontal, Archive, FilePen, Link as LinkIcon } from "lucide-react";
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
import { Card, CardContent, CardFooter, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { deleteClient } from "@/app/admin/actions/clients.actions";
import type { Client } from "@/types";
import { AssignAgreementDialog } from "./assign-agreement-dialog";

const statusMap: Record<Client['status'], { label: string; variant: "default" | "secondary" | "destructive" | "outline" }> = {
    pending_onboarding: { label: "Pendiente de Alta", variant: "secondary" },
    pending_agreement: { label: "Pendiente de Convenio", variant: "destructive" },
    active: { label: "Activo", variant: "default" },
    archived: { label: "Archivado", variant: "outline" },
};

interface ClientsTableProps {
    clients: Client[];
    emptyState: React.ReactNode;
}

export function ClientsTable({ clients, emptyState }: ClientsTableProps) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  const [isClient, setIsClient] = useState(false);

  useEffect(() => {
    setIsClient(true);
  }, []);

  const handleArchive = (clientId: string) => {
    startTransition(async () => {
      const result = await deleteClient(clientId);
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: "Cliente archivado correctamente." });
      }
    });
  };

  const copyToClipboard = useCallback((textToCopy: string | null, toastMessage: string, errorMessage?: string) => {
    if (!textToCopy) {
      toast({ title: "No hay nada para copiar", description: errorMessage || "El recurso no está disponible.", variant: "destructive"});
      return;
    }
    navigator.clipboard.writeText(textToCopy);
    toast({ title: toastMessage });
  }, [toast]);
  
  if (clients.length === 0) {
    return <>{emptyState}</>;
  }

  return (
    <>
      <div className="grid gap-4 sm:hidden">
        {clients.map((client) => (
          <Card key={client.id}>
             <Link href={`/admin/clients/${client.id}`}>
                <CardContent className="pt-6">
                    <div className="flex justify-between items-start mb-2">
                        <div>
                          <CardTitle className="text-lg">{client.contact_name || "Cliente pendiente"}</CardTitle>
                          {client.email && <p className="text-sm text-muted-foreground">{client.email}</p>}
                        </div>
                        <Badge variant={statusMap[client.status]?.variant || 'outline'}>
                            {statusMap[client.status]?.label || client.status}
                        </Badge>
                    </div>
                    <p className="text-sm font-medium">Convenio: <span className="text-muted-foreground">{client.agreements?.agreement_name || "Sin asignar"}</span></p>
                </CardContent>
            </Link>
            <CardFooter className="flex flex-col gap-2 items-stretch">
                 <AssignAgreementDialog client={client}>
                    <Button variant="outline" size="sm" className="w-full">
                      <FilePen className="mr-2 h-4 w-4" />
                       {client.agreement_id ? "Cambiar Convenio" : "Asignar Convenio"}
                    </Button>
                </AssignAgreementDialog>
                 <AlertDialog>
                    <AlertDialogTrigger asChild>
                       <Button variant="destructive" size="sm">
                            <Archive className="mr-2 h-4 w-4" /> Archivar
                        </Button>
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
                        <AlertDialogAction
                            onClick={() => handleArchive(client.id)}
                            disabled={isPending}
                            className="bg-destructive hover:bg-destructive/90"
                        >
                            {isPending ? "Archivando..." : "Confirmar"}
                        </AlertDialogAction>
                    </AlertDialogFooter>
                    </AlertDialogContent>
                </AlertDialog>
            </CardFooter>
          </Card>
        ))}
      </div>

      <Card className="hidden sm:block">
        <CardContent className="p-0">
          <div className="relative w-full overflow-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nombre</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Convenio</TableHead>
                  <TableHead>Estado</TableHead>
                  <TableHead className="text-right">
                    <span className="sr-only">Acciones</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {clients.map((client) => {
                  const orderLink = isClient && client.agreement_id && client.status === 'active' ? `${window.location.origin}/pedido/${client.agreement_id}` : null;
                  return (
                  <TableRow key={client.id}>
                    <TableCell className="font-medium">
                      <Link href={`/admin/clients/${client.id}`} className="hover:underline">
                        {client.contact_name || "Cliente pendiente..."}
                      </Link>
                    </TableCell>
                    <TableCell className="text-muted-foreground">{client.email?.includes('@blonde.orders') ? 'N/A' : client.email}</TableCell>
                    <TableCell className="text-muted-foreground">
                        {client.agreements?.agreement_name || "Sin asignar"}
                    </TableCell>
                    <TableCell>
                      <Badge variant={statusMap[client.status]?.variant || 'outline'} className="capitalize">
                      {statusMap[client.status]?.label || client.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                          <Button aria-haspopup="true" size="icon" variant="ghost">
                              <MoreHorizontal className="h-4 w-4" />
                              <span className="sr-only">Menú</span>
                          </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Acciones</DropdownMenuLabel>
                          <DropdownMenuItem asChild>
                             <Link href={`/admin/clients/${client.id}`}>Ver Detalles</Link>
                          </DropdownMenuItem>
                          <AssignAgreementDialog client={client}>
                              <DropdownMenuItem onSelect={(e) => e.preventDefault()}>Asignar Convenio</DropdownMenuItem>
                          </AssignAgreementDialog>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem 
                              onClick={() => copyToClipboard(orderLink, 'Enlace de pedido copiado!', 'El cliente debe estar activo para tener un enlace de pedido.')}
                              disabled={!orderLink}
                          >
                              <LinkIcon className="mr-2 h-4 w-4" />
                              Copiar Link Pedido
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
                                      Esta acción ocultará al cliente de la lista principal.
                                  </AlertDialogDescription>
                              </AlertDialogHeader>
                              <AlertDialogFooter>
                                  <AlertDialogCancel>Cancelar</AlertDialogCancel>
                                  <AlertDialogAction
                                      onClick={() => handleArchive(client.id)}
                                      disabled={isPending}
                                      className="bg-destructive hover:bg-destructive/90"
                                  >
                                      {isPending ? "Archivando..." : "Confirmar"}
                                  </AlertDialogAction>
                              </AlertDialogFooter>
                              </AlertDialogContent>
                          </AlertDialog>
                          </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                )})}
              </TableBody>
            </Table>
          </div>
        </CardContent>
          <CardFooter>
            <div className="text-xs text-muted-foreground">
                Mostrando <strong>{clients.length}</strong> clientes.
              </div>
          </CardFooter>
      </Card>
    </>
  );
}
