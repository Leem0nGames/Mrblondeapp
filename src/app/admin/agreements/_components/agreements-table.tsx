
"use client";

import { useTransition, useCallback } from "react";
import Link from 'next/link';
import { MoreHorizontal, Trash2, Edit, FileText, Copy, Link2 } from "lucide-react";
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
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import type { Agreement } from "@/types";
import { deleteAgreement, generateLinkToken } from "@/app/actions/admin.actions";
import { AgreementDialog } from "./agreement-dialog";

export default function AgreementsTable({ agreements }: { agreements: Agreement[] }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleDelete = (agreementId: string) => {
    startTransition(async () => {
      const result = await deleteAgreement(agreementId);
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Éxito",
          description: "Convenio eliminado correctamente.",
        });
      }
    });
  };

  const handleGenerateLink = (agreementId: string) => {
    startTransition(async () => {
        const result = await generateLinkToken(agreementId);
        if (result.error) {
            toast({ title: "Error", description: result.error.message, variant: "destructive" });
        } else {
            toast({ title: "Éxito", description: "Nuevo enlace generado y copiado." });
            copyToClipboard(result.data?.link_token ?? null);
        }
    });
  }

  const copyToClipboard = useCallback((token: string | null) => {
    if (!token) {
        toast({ title: "Error", description: "Este convenio no tiene un link.", variant: "destructive"});
        return;
    }
    const host = window.location.host;
    const protocol = window.location.protocol;
    const link = `${protocol}//${host}/pedido/${token}`;
    navigator.clipboard.writeText(link);
    toast({ title: "Enlace copiado al portapapeles!" });
  }, [toast]);
  
  return (
    <>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Nombre del Convenio</TableHead>
            <TableHead>Tipo de Cliente</TableHead>
            <TableHead className="hidden sm:table-cell">Productos</TableHead>
            <TableHead className="hidden sm:table-cell">Promociones</TableHead>
            <TableHead className="text-right">Acciones</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {agreements.map((agreement) => (
            <TableRow key={agreement.id}>
              <TableCell className="font-medium">{agreement.agreement_name}</TableCell>
              <TableCell>
                <Badge variant="outline" className="capitalize">{agreement.client_type}</Badge>
              </TableCell>
              <TableCell className="hidden sm:table-cell">{agreement.agreement_products.length}</TableCell>
              <TableCell className="hidden sm:table-cell">{agreement.agreement_promotions.length}</TableCell>
              <TableCell className="text-right">
                <div className="flex items-center justify-end gap-2">
                    {agreement.link_token ? (
                        <Button variant="outline" size="sm" onClick={() => copyToClipboard(agreement.link_token)}>
                            <Copy className="mr-2 h-4 w-4" />
                            Copiar Link
                        </Button>
                    ) : (
                        <Button variant="secondary" size="sm" onClick={() => handleGenerateLink(agreement.id)} disabled={isPending}>
                            <Link2 className="mr-2 h-4 w-4" />
                            {isPending ? "Generando..." : "Generar Link"}
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
                        <DropdownMenuItem asChild>
                            <Link href={`/admin/agreements/${agreement.id}`}>
                                <FileText className="mr-2 h-4 w-4" />
                                Gestionar
                            </Link>
                        </DropdownMenuItem>
                        <AgreementDialog agreement={agreement}>
                            <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
                                <Edit className="mr-2 h-4 w-4" />
                                Editar Detalles
                            </DropdownMenuItem>
                        </AgreementDialog>
                        <DropdownMenuItem onClick={() => handleGenerateLink(agreement.id)} disabled={isPending}>
                           <Link2 className="mr-2 h-4 w-4" />
                           {isPending ? "Generando..." : "Regenerar Link"}
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <AlertDialog>
                            <AlertDialogTrigger asChild>
                            <DropdownMenuItem
                                className="text-destructive"
                                onSelect={(e) => e.preventDefault()}
                            >
                                <Trash2 className="mr-2 h-4 w-4" />
                                Eliminar
                            </DropdownMenuItem>
                            </AlertDialogTrigger>
                            <AlertDialogContent>
                            <AlertDialogHeader>
                                <AlertDialogTitle>
                                ¿Estás seguro?
                                </AlertDialogTitle>
                                <AlertDialogDescription>
                                Esta acción no se puede deshacer. Esto eliminará permanentemente el convenio.
                                </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                                <AlertDialogCancel>Cancelar</AlertDialogCancel>
                                <AlertDialogAction
                                onClick={() => handleDelete(agreement.id)}
                                disabled={isPending}
                                className="bg-destructive hover:bg-destructive/90"
                                >
                                {isPending ? "Eliminando..." : "Eliminar"}
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
       <div className="text-xs text-muted-foreground pt-4 px-4">
          Mostrando <strong>{agreements.length}</strong> de{" "}
          <strong>{agreements.length}</strong> convenios.
        </div>
    </>
  );
}
