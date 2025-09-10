"use client"

import { useTransition } from "react";
import { MoreHorizontal, Trash2 } from "lucide-react";
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

import type { AgreementProduct } from "@/types";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import Image from "next/image";
import { Badge } from "@/components/ui/badge";
import { unassignProductFromAgreement } from "@/app/actions/admin.actions";
import { useToast } from "@/hooks/use-toast";
import { PriceEditDialog } from "./price-edit-dialog";

export default function AgreementProductsTable({ products, agreementId }: { products: AgreementProduct[], agreementId: string }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  if (products.length === 0) {
    return (
        <div className="text-center py-12 text-muted-foreground">
            <p>No hay productos asignados a este convenio.</p>
            <p className="text-sm">Usa el botón "Asignar Producto" para empezar.</p>
        </div>
    )
  }

  const handleUnassign = (productId: string) => {
    startTransition(async () => {
      const result = await unassignProductFromAgreement({ agreement_id: agreementId, product_id: productId });
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: "Producto desasignado correctamente." });
      }
    });
  }

  return (
    <>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="hidden w-[64px] sm:table-cell">
                <span className="sr-only">Imagen</span>
            </TableHead>
            <TableHead>Nombre</TableHead>
            <TableHead>Precio Base</TableHead>
            <TableHead>Precio Convenio</TableHead>
            <TableHead>
              <span className="sr-only">Acciones</span>
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {products.map((item) => (
            <TableRow key={item.products.id}>
              <TableCell className="hidden sm:table-cell">
                 <Image
                    src={`https://picsum.photos/seed/${item.products.id}/64/64`}
                    alt={item.products.name}
                    width={48}
                    height={48}
                    className="rounded-md aspect-square object-cover"
                    data-ai-hint="product image"
                  />
              </TableCell>
              <TableCell className="font-medium">{item.products.name}</TableCell>
              <TableCell>${item.products.base_price.toLocaleString()}</TableCell>
              <TableCell>
                <Badge variant="secondary" className="text-base">${item.price.toLocaleString()}</Badge>
              </TableCell>
              <TableCell>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button aria-haspopup="true" size="icon" variant="ghost">
                      <MoreHorizontal className="h-4 w-4" />
                      <span className="sr-only">Toggle menu</span>
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuLabel>Acciones</DropdownMenuLabel>
                     <PriceEditDialog 
                        agreementId={agreementId}
                        product={item.products}
                        currentPrice={item.price}
                      >
                         <DropdownMenuItem onSelect={(e) => e.preventDefault()}>Editar Precio</DropdownMenuItem>
                      </PriceEditDialog>

                    <DropdownMenuSeparator />
                     <AlertDialog>
                        <AlertDialogTrigger asChild>
                           <DropdownMenuItem className="text-destructive" onSelect={(e) => e.preventDefault()}>
                              <Trash2 className="mr-2 h-4 w-4" />
                              Desasignar
                            </DropdownMenuItem>
                        </AlertDialogTrigger>
                        <AlertDialogContent>
                          <AlertDialogHeader>
                            <AlertDialogTitle>¿Estás seguro?</AlertDialogTitle>
                            <AlertDialogDescription>
                              Esta acción quitará el producto de este convenio.
                            </AlertDialogDescription>
                          </AlertDialogHeader>
                          <AlertDialogFooter>
                            <AlertDialogCancel>Cancelar</AlertDialogCancel>
                            <AlertDialogAction
                              onClick={() => handleUnassign(item.products.id)}
                              disabled={isPending}
                              className="bg-destructive hover:bg-destructive/90"
                            >
                              {isPending ? "Desasignando..." : "Confirmar"}
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
       <div className="text-xs text-muted-foreground pt-4 px-4">
          Mostrando <strong>{products.length}</strong> de{" "}
          <strong>{products.length}</strong> productos asignados.
        </div>
    </>
  );
}
