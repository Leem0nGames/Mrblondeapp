
"use client";

import { useTransition, useCallback } from "react";
import { MoreHorizontal, Trash2, Copy, Link as LinkIcon, Archive, Edit } from "lucide-react";
import Link from "next/link";
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
import { Card, CardContent, CardFooter, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { deleteClient } from "@/app/actions/admin.actions";
import type { Client } from "@/types";
import { AssignAgreementDialog } from "./assign-agreement-dialog";
import { cn } from "@/lib/utils";

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

  const copyToClipboard = useCallback((textToCopy: string, toastMessage: string) => {
    navigator.clipboard.writeText(textToCopy);
    toast({ title: toastMessage });
  }, [toast]);
  
  if (clients.length === 0) {
    return <>{emptyState}</>;
  }

  return (
    <>
      {/* Mobile View: Cards */}
      <div className="grid gap-4 sm:hidden">
        {clients.map((client) => (
          <Card key={client.id}>
             <Link href={`/admin/clients/${client.id}`}>
                <CardHeader>
                  <div className="flex justify-between items-start">
                      <div>
                        <CardTitle>{client.contact_name || "Cliente pendiente"}</CardTitle>
                        {client.email && <CardDescription>{client.email}</CardDescription>}
                      </div>
                      <Badge variant={statusMap[client.status].variant}>
                        {statusMap[client.status].label}
                      </Badge>
                  </div>
                </CardHeader>
                <CardContent>
                    <p className="text-sm font-medium">Convenio</p>
                    <p className="text-sm text-muted-foreground">{client.agreements?.agreement_name || "Sin asignar"}</p>
                </CardContent>
            </Link>
            <CardFooter className="flex flex-col gap-2 items-stretch">
                <AssignAgreementDialog client={client}>
                    <Button variant="default" size="sm">
                       <Edit className="mr-2 h-4 w-4"/> Asignar Convenio
                    </Button>
                </AssignAgreementDialog>
                <Button 
                    variant="secondary"
                    size="sm"
                    onClick={() => copyToClipboard(`${window.location.origin}/onboarding/${client.onboarding_token}`, 'Enlace de alta copiado!')}
                    disabled={client.status !== 'pending_onboarding'}
                >
                    <Copy className="mr-2 h-4 w-4" />
                    Copiar Link de Alta
                </Button>
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
            </CardFooter>
          </Card>
        ))}
      </div>

      {/* Desktop View: Table */}
      <Card className="hidden sm:block">
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Nombre</TableHead>
                <TableHead>Email</TableHead>
                <TableHead>Convenio</TableHead>
                <TableHead>Estado</TableHead>
                <TableHead>
                  <span className="sr-only">Acciones</span>
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {clients.map((client) => (
                <TableRow key={client.id} className="cursor-pointer" onClick={() => window.location.href = `/admin/clients/${client.id}`}>
                  <TableCell className="font-medium">{client.contact_name || "Cliente pendiente..."}</TableCell>
                  <TableCell>{client.email}</TableCell>
                  <TableCell>
                      {client.agreements?.agreement_name || <span className="text-muted-foreground">Sin asignar</span>}
                  </TableCell>
                  <TableCell>
                    <Badge variant={statusMap[client.status].variant}>
                      {statusMap[client.status].label}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right" onClick={(e) => e.stopPropagation()}>
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                        <Button aria-haspopup="true" size="icon" variant="ghost">
                            <MoreHorizontal className="h-4 w-4" />
                            <span className="sr-only">Menú</span>
                        </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                        <DropdownMenuLabel>Acciones</DropdownMenuLabel>
                        <DropdownMenuItem onSelect={() => window.location.href = `/admin/clients/${client.id}`}>
                            Ver Detalles
                        </DropdownMenuItem>
                        <AssignAgreementDialog client={client}>
                            <DropdownMenuItem onSelect={(e) => e.preventDefault()}>Asignar Convenio</DropdownMenuItem>
                        </AssignAgreementDialog>
                        <DropdownMenuItem 
                            onClick={() => copyToClipboard(`${window.location.origin}/onboarding/${client.onboarding_token}`, 'Enlace de alta copiado!')}
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
    </>
  );
}
