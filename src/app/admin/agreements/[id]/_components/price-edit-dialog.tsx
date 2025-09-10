"use client";

import { useState, useTransition } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
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

import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { updateAgreementProductPrice } from "@/app/actions/admin.actions";
import type { Product } from "@/types";

const priceSchema = z.object({
  price: z.coerce.number().min(0, "El precio debe ser un número positivo."),
});

type PriceFormValues = z.infer<typeof priceSchema>;

export function PriceEditDialog({
  children,
  agreementId,
  product,
  currentPrice
}: {
  children: React.ReactNode;
  agreementId: string;
  product: Product;
  currentPrice: number;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const form = useForm<PriceFormValues>({
    resolver: zodResolver(priceSchema),
    defaultValues: {
      price: currentPrice,
    },
  });

  const onSubmit = (values: PriceFormValues) => {
    startTransition(async () => {
      const result = await updateAgreementProductPrice({ 
          agreement_id: agreementId,
          product_id: product.id,
          price: values.price 
      });
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Éxito",
          description: `Precio actualizado correctamente.`,
        });
        setIsOpen(false);
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Editar Precio para Convenio</DialogTitle>
          <DialogDescription>
            Establece un precio especial para <strong>{product.name}</strong> solo en este convenio.
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <div className="flex items-baseline gap-4">
                 <p className="text-sm text-muted-foreground">Precio Base:</p>
                 <p className="font-semibold line-through">${product.base_price.toLocaleString()}</p>
            </div>
            <FormField
              control={form.control}
              name="price"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Nuevo Precio de Convenio</FormLabel>
                  <FormControl>
                    <Input type="number" step="0.01" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <DialogFooter>
              <DialogClose asChild>
                <Button variant="outline" type="button">
                  Cancelar
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isPending}>
                {isPending ? "Guardando..." : "Guardar Precio"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
