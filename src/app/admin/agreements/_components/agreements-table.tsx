
"use client";

import { useTransition, useCallback } from "react";
import Link from 'next/link';
import { MoreHorizontal, Trash2, FileText, Copy } from "lucide-react";
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
import {
  Card,
  CardContent,
  CardFooter,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { deleteAgreement } from "@/app/actions/admin.actions";
import type { AgreementWithCount } from "@/types";

export default function AgreementsTable({ agreements }: { agreements: AgreementWithCount[] }) {
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

  const copyToClipboard = useCallback((agreementId: string | null) => {
    if (!agreementId) {
        toast({ title: "Error", description: "Este convenio no tiene un ID.", variant: "destructive"});
        return;
    }
    const host = window.location.host;
    const protocol = window.location.protocol;
    const link = `${protocol}//${host}/pedido/${agreementId}`;
    navigator.clipboard.writeText(link);
    toast({ title: "Enlace copiado al portapapeles!" });
  }, [toast]);
  
  return (
    <Card>
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nombre del Convenio</TableHead>
              <TableHead>Tipo de Cliente</TableHead>
              <TableHead className="hidden sm:table-cell">Lista de Precios</TableHead>
              <TableHead className="hidden sm:table-cell">Promociones</TableHead>
              <TableHead>
                <span className="sr-only">Acciones</span>
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {agreements.map((agreement) => (
              <TableRow key={agreement.id}>
                <TableCell className="font-medium">{agreement.agreement_name}</TableCell>
                <TableCell>
                  <Badge variant="outline" className="capitalize">{agreement.client_type}</Badge>
                </TableCell>
                <TableCell className="hidden sm:table-cell">{agreement.price_lists?.name ?? <span className="text-muted-foreground">Ninguna</span>}</TableCell>
                <TableCell className="hidden sm:table-cell">{agreement.promotion_count ?? 0}</TableCell>
                <TableCell className="text-right">
                  <div className="flex items-center justify-end gap-2">
                      <Button variant="outline" size="sm" onClick={() => copyToClipboard(agreement.id)}>
                          <Copy className="mr-2 h-4 w-4" />
                          Copiar Link
                      </Button>
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
                                  Esta acción no se puede deshacer. Esto eliminará permanentemente el convenio y todas sus asignaciones.
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
      </CardContent>
      <CardFooter>
         <div className="text-xs text-muted-foreground">
            Mostrando <strong>{agreements.length}</strong> de{" "}
            <strong>{agreements.length}</strong> convenios.
          </div>
      </CardFooter>
    </Card>
  );
}
