
"use client";

import { useTransition } from "react";
import Link from 'next/link';
import { MoreHorizontal, Trash2, Edit } from "lucide-react";
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
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { deletePriceList } from "@/app/actions/admin.actions";
import type { PriceList } from "@/types";
import { formatDate } from "@/lib/utils";
import { PriceListDialog } from "./pricelist-dialog";

export function PriceListsTable({ priceLists }: { priceLists: PriceList[] }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleDelete = (id: string) => {
    startTransition(async () => {
      const result = await deletePriceList(id);
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: "Lista de precios eliminada." });
      }
    });
  };

  return (
    <Card>
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nombre</TableHead>
              <TableHead className="hidden sm:table-cell">Creada el</TableHead>
              <TableHead>
                <span className="sr-only">Acciones</span>
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {priceLists.map((list) => (
              <TableRow key={list.id}>
                <TableCell className="font-medium">
                  <Link href={`/admin/pricelists/${list.id}`} className="hover:underline">
                    {list.name}
                  </Link>
                </TableCell>
                <TableCell className="hidden sm:table-cell">{formatDate(list.created_at)}</TableCell>
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
                            <Link href={`/admin/pricelists/${list.id}`}>Gestionar Productos</Link>
                        </DropdownMenuItem>
                        <PriceListDialog priceList={list}>
                            <DropdownMenuItem onSelect={(e) => e.preventDefault()}>Editar Nombre</DropdownMenuItem>
                        </PriceListDialog>
                        <DropdownMenuSeparator />
                        <AlertDialog>
                            <AlertDialogTrigger asChild>
                            <DropdownMenuItem className="text-destructive" onSelect={(e) => e.preventDefault()}>
                                <Trash2 className="mr-2 h-4 w-4" />
                                Eliminar
                            </DropdownMenuItem>
                            </AlertDialogTrigger>
                            <AlertDialogContent>
                            <AlertDialogHeader>
                                <AlertDialogTitle>¿Estás seguro?</AlertDialogTitle>
                                <AlertDialogDescription>
                                    Esta acción no se puede deshacer. Los convenios que usen esta lista quedarán sin precios.
                                </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                                <AlertDialogCancel>Cancelar</AlertDialogCancel>
                                <AlertDialogAction
                                onClick={() => handleDelete(list.id)}
                                disabled={isPending}
                                className="bg-destructive hover:bg-destructive/90"
                                >
                                {isPending ? "Eliminando..." : "Confirmar"}
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
            Mostrando <strong>{priceLists.length}</strong> de <strong>{priceLists.length}</strong> listas.
          </div>
      </CardFooter>
    </Card>
  );
}
