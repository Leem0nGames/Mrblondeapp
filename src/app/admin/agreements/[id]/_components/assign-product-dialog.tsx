"use client";

import { useState, useTransition, useEffect } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import Image from "next/image";

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";
import { getUnassignedProducts, assignProductToAgreement } from "@/app/actions/admin.actions";
import type { Product } from "@/types";
import { getImageUrl } from "@/lib/placeholder-images";

const assignSchema = z.object({
  product_id: z.string().min(1, "Debes seleccionar un producto."),
  price: z.coerce.number().min(0, "El precio debe ser un número positivo."),
});

type AssignFormValues = z.infer<typeof assignSchema>;

export function AssignProductDialog({
  children,
  agreementId,
}: {
  children: React.ReactNode;
  agreementId: string;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [products, setProducts] = useState<Product[]>([]);
  const [isPending, startTransition] = useTransition();
  const [isLoading, startLoading] = useTransition();
  const { toast } = useToast();

  const form = useForm<AssignFormValues>({
    resolver: zodResolver(assignSchema),
    defaultValues: {
      product_id: "",
      price: 0,
    },
  });

  const selectedProductId = form.watch("product_id");

  useEffect(() => {
    if (isOpen) {
      startLoading(async () => {
        const { data, error } = await getUnassignedProducts(agreementId);
        if (error) {
          toast({ title: "Error", description: "No se pudieron cargar los productos.", variant: "destructive" });
        } else {
          setProducts(data ?? []);
        }
      });
    }
  }, [isOpen, agreementId, toast]);

  useEffect(() => {
      const selectedProduct = products.find(p => p.id === selectedProductId);
      if (selectedProduct) {
        form.setValue("price", selectedProduct.base_price);
      }
  }, [selectedProductId, products, form]);

  const onSubmit = (values: AssignFormValues) => {
    startTransition(async () => {
      const result = await assignProductToAgreement({ ...values, agreement_id: agreementId });
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: `Producto asignado correctamente.` });
        setIsOpen(false);
        form.reset();
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Asignar Producto</DialogTitle>
          <DialogDescription>
            Selecciona un producto para añadir al convenio y establece su precio especial.
          </DialogDescription>
        </DialogHeader>
        {isLoading ? <div className="space-y-4 py-4">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <div className="flex justify-end gap-2 pt-4">
                <Skeleton className="h-10 w-24" />
                <Skeleton className="h-10 w-24" />
            </div>
        </div> : (
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
             <FormField
              control={form.control}
              name="product_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Producto</FormLabel>
                   <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Selecciona un producto" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <ScrollArea className="h-60">
                         {products.length > 0 ? products.map(product => (
                            <SelectItem key={product.id} value={product.id}>
                                <div className="flex items-center gap-2">
                                     <Image
                                        src={getImageUrl("product_sm", {id: product.id, width: 40, height: 40})}
                                        alt={product.name}
                                        width={24}
                                        height={24}
                                        className="rounded-sm"
                                        data-ai-hint="product image"
                                    />
                                    <span>{product.name}</span>
                                </div>
                            </SelectItem>
                         )) : <div className="p-4 text-center text-sm text-muted-foreground">No hay más productos para asignar.</div>}
                         </ScrollArea>
                      </SelectContent>
                    </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="price"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Precio para Convenio</FormLabel>
                  <FormControl>
                    <Input type="number" step="0.01" {...field} disabled={!selectedProductId} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <DialogClose asChild>
                <Button variant="outline" type="button" onClick={() => form.reset()}>
                  Cancelar
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isPending}>
                {isPending ? "Asignando..." : "Asignar Producto"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
        )}
      </DialogContent>
    </Dialog>
  );
}
