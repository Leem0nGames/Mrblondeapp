"use client"

import { MoreHorizontal } from "lucide-react";
import type { AgreementProduct } from "@/types";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
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
import Image from "next/image";
import { Badge } from "@/components/ui/badge";

export default function AgreementProductsTable({ products }: { products: AgreementProduct[] }) {

  if (products.length === 0) {
    return (
        <div className="text-center py-12 text-muted-foreground">
            <p>No hay productos asignados a este convenio.</p>
            <p className="text-sm">Usa el botón "Asignar Producto" para empezar.</p>
        </div>
    )
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
                    <DropdownMenuItem>Editar Precio</DropdownMenuItem>
                    <DropdownMenuItem className="text-destructive">
                      Desasignar
                    </DropdownMenuItem>
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
