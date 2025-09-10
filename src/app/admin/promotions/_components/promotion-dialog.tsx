
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
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { upsertPromotion } from "@/app/actions/admin.actions";
import type { Promotion } from "@/types";

// Helper to check for valid JSON
const isValidJson = (value: string) => {
  try {
    JSON.parse(value);
    return true;
  } catch {
    return false;
  }
};

const promotionSchema = z.object({
  name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  description: z.string().optional(),
  rules: z.string().refine(isValidJson, {
    message: "Debe ser un objeto JSON válido.",
  }),
});

type PromotionFormValues = z.infer<typeof promotionSchema>;

// Default rule structure as a placeholder
const defaultRule = {
  type: "buy_x_get_y_free",
  buy: 6,
  get: 1,
};


export function PromotionDialog({
  children,
  promotion,
}: {
  children: React.ReactNode;
  promotion?: Promotion;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const form = useForm<PromotionFormValues>({
    resolver: zodResolver(promotionSchema),
    defaultValues: {
      name: promotion?.name ?? "",
      description: promotion?.description ?? "",
      rules: promotion?.rules ? JSON.stringify(promotion.rules, null, 2) : JSON.stringify(defaultRule, null, 2),
    },
  });

  const onSubmit = (values: PromotionFormValues) => {
    startTransition(async () => {
      const payload = {
        ...values,
        id: promotion?.id,
        rules: JSON.parse(values.rules),
      }
      const result = await upsertPromotion(payload);

      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Éxito",
          description: `Promoción ${promotion ? "actualizada" : "creada"} correctamente.`,
        });
        setIsOpen(false);
        form.reset();
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-[525px]">
        <DialogHeader>
          <DialogTitle>{promotion ? "Editar Promoción" : "Nueva Promoción"}</DialogTitle>
          <DialogDescription>
            {promotion
              ? "Actualiza los detalles de esta promoción."
              : "Define una nueva promoción con sus reglas."}
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Nombre de la Promoción</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g., Promo Barberías 6+1" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
             <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Descripción</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g., Llevando 6 pagas 5" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="rules"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Reglas (JSON)</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder='{ "type": "buy_x_get_y_free", "buy": 6, "get": 1 }'
                      {...field}
                      rows={6}
                      className="font-code text-xs"
                    />
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
                {isPending ? "Guardando..." : "Guardar Promoción"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
