
"use client";

import { MoreHorizontal, Trash2, Edit, ChevronLeft, ChevronRight } from "lucide-react";
import { useTransition, useEffect, useState } from "react";
import Image from "next/image";
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
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardFooter,
} from "@/components/ui/card";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger,
  DropdownMenuSeparator
} from "@/components/ui/dropdown-menu";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Product } from "@/types";
import { deleteProduct } from "@/app/admin/actions/products.actions";
import { useToast } from "@/hooks/use-toast";
import { formatDate } from "@/lib/utils";
import { getImageUrl } from "@/lib/placeholder-images";
import { EntityDialog } from "../../_components/entity-dialog";
import { productFormConfig } from "./form-config";

const ITEMS_PER_PAGE = 10;

interface ProductsTableProps {
    products: Product[];
    emptyState: React.ReactNode;
    page?: number;
    totalCount?: number;
    onPageChange?: (page: number) => void;
}

export default function ProductsTable({ products, emptyState, page = 1, totalCount, onPageChange }: ProductsTableProps) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  const [isClient, setIsClient] = useState(false);

  const totalPages = totalCount ? Math.ceil(totalCount / ITEMS_PER_PAGE) : 1;
  const hasPagination = totalCount !== undefined;

  useEffect(() => {
    setIsClient(true);
  }, []);

  const handleDelete = (productId: string) => {
    startTransition(async () => {
      const result = await deleteProduct(productId);
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Éxito",
          description: "Producto eliminado correctamente.",
        });
      }
    });
  };

  const handlePageChange = (newPage: number) => {
    if (newPage >= 1 && newPage <= totalPages && onPageChange) {
      onPageChange(newPage);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };
  
  if (products.length === 0) {
    return <>{emptyState}</>;
  }

  return (
    <>
      <div className="grid gap-4 sm:hidden">
        {products.map((product) => (
          <Card key={product.id}>
            <CardContent className="pt-6">
              <div className="flex gap-4">
                <Image
                  src={getImageUrl("product", { seed: product.id }, product.image_url)}
                  alt={product.name}
                  width={64}
                  height={64}
                  className="rounded-lg aspect-square object-cover"
                  data-ai-hint="product image"
                />
                <div className="flex-grow">
                  <h3 className="font-semibold text-lg">{product.name}</h3>
                  {product.category && (
                    <Badge variant="outline" className="mt-1">{product.category}</Badge>
                  )}
                  <p className="text-sm text-muted-foreground line-clamp-2 mt-2">{product.description}</p>
                </div>
              </div>
            </CardContent>
            <CardFooter className="flex justify-end gap-2">
                <EntityDialog formConfig={productFormConfig} entity={product}>
                  <Button variant="outline" size="sm">
                    <Edit className="mr-2 h-4 w-4" /> Editar
                  </Button>
                </EntityDialog>
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button variant="destructive" size="sm">
                      <Trash2 className="mr-2 h-4 w-4" /> Eliminar
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>¿Eliminar producto?</AlertDialogTitle>
                      <AlertDialogDescription>
                        Esta acción no se puede deshacer.
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel>Cancelar</AlertDialogCancel>
                      <AlertDialogAction
                        onClick={() => handleDelete(product.id)}
                        disabled={isPending}
                        className="bg-destructive hover:bg-destructive/90"
                      >
                        {isPending ? "Eliminando..." : "Eliminar"}
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
            </CardFooter>
          </Card>
        ))}
      </div>

      <div className="hidden sm:block">
        <Card>
          <CardContent className="p-0">
            <div className="relative w-full overflow-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[64px]">
                      <span className="sr-only">Imagen</span>
                    </TableHead>
                    <TableHead>Nombre</TableHead>
                    <TableHead>Descripción</TableHead>
                    <TableHead>Creado el</TableHead>
                    <TableHead className="text-right">
                      <span className="sr-only">Acciones</span>
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {products.map((product) => (
                    <TableRow key={product.id}>
                      <TableCell>
                        <Image
                          src={getImageUrl("product", { seed: product.id }, product.image_url)}
                          alt={product.name}
                          width={48}
                          height={48}
                          className="rounded-md aspect-square object-cover"
                          data-ai-hint="product image"
                        />
                      </TableCell>
                      <TableCell className="font-medium">{product.name}</TableCell>
                      <TableCell className="text-sm text-muted-foreground truncate max-w-xs">
                        {product.description}
                      </TableCell>
                      <TableCell>
                        {formatDate(product.created_at)}
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
                            <EntityDialog formConfig={productFormConfig} entity={product}>
                              <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
                                Editar
                              </DropdownMenuItem>
                            </EntityDialog>
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
                                  <AlertDialogTitle>¿Eliminar producto?</AlertDialogTitle>
                                  <AlertDialogDescription>
                                    Esta acción no se puede deshacer.
                                  </AlertDialogDescription>
                                </AlertDialogHeader>
                                <AlertDialogFooter>
                                  <AlertDialogCancel>Cancelar</AlertDialogCancel>
                                  <AlertDialogAction
                                    onClick={() => handleDelete(product.id)}
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
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </CardContent>
          {hasPagination && (
            <CardFooter className="flex items-center justify-between border-t p-4">
              <div className="text-sm text-muted-foreground">
                Página <strong>{page}</strong> de <strong>{totalPages}</strong> ({totalCount} productos)
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handlePageChange(page - 1)}
                  disabled={page <= 1 || isPending}
                >
                  <ChevronLeft className="h-4 w-4" />
                  Anterior
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handlePageChange(page + 1)}
                  disabled={page >= totalPages || isPending}
                >
                  Siguiente
                  <ChevronRight className="h-4 w-4" />
                </Button>
              </div>
            </CardFooter>
          )}
          {!hasPagination && (
            <CardFooter>
              <div className="text-xs text-muted-foreground">
                Mostrando <strong>{products.length}</strong> productos
              </div>
            </CardFooter>
          )}
        </Card>
      </div>
    </>
  );
}
