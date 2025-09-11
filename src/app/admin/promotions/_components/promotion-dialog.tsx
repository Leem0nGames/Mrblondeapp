"use client";

import { useState, useTransition, useEffect } from "react";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { upsertPromotion } from "@/app/actions/admin.actions";
import type { Promotion } from "@/types";
import { cn } from "@/lib/utils";

// Define schemas for each promotion type
const buyXgetYFreeSchema = z.object({
  buy: z.coerce.number().min(1, "Debe ser al menos 1"),
  get: z.coerce.number().min(1, "Debe ser al menos 1"),
});

const freeShippingSchema = z.object({
  min_units: z.coerce.number().min(1, "Debe ser al menos 1"),
  locations: z.string().min(1, "Debe haber al menos una ciudad"),
});

// Main schema with a discriminator for the promotion type
const promotionSchema = z.object({
  name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  description: z.string().optional(),
  type: z.enum(["buy_x_get_y_free", "free_shipping"]),
}).superRefine((data, ctx) => {
    if (data.type === "buy_x_get_y_free") {
      // Manually add fields for refinement if needed, though they are not part of the main form object
    } else if (data.type === "free_shipping") {
      // Manually add fields
    }
});


type PromotionFormValues = z.infer<typeof promotionSchema> & {
    buy_x_get_y_free?: z.infer<typeof buyXgetYFreeSchema>;
    free_shipping?: z.infer<typeof freeShippingSchema>;
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

  const getDefaultValues = (promo?: Promotion): PromotionFormValues => {
    if (!promo) {
      return {
        name: "",
        description: "",
        type: "buy_x_get_y_free",
        buy_x_get_y_free: { buy: 0, get: 0 },
        free_shipping: { min_units: 0, locations: "" },
      };
    }

    const type = promo.rules.type || "buy_x_get_y_free";
    return {
      name: promo.name,
      description: promo.description ?? "",
      type: type,
      buy_x_get_y_free: {
        buy: promo.rules.buy || 0,
        get: promo.rules.get || 0,
      },
      free_shipping: {
        min_units: promo.rules.min_units || 0,
        locations: (promo.rules.locations || []).join(", "),
      },
    };
  };

  const form = useForm<PromotionFormValues>({
    resolver: zodResolver(promotionSchema),
    defaultValues: getDefaultValues(promotion),
  });

  const selectedType = form.watch("type");

   useEffect(() => {
    if (promotion) {
      form.reset(getDefaultValues(promotion));
    } else {
      form.reset(getDefaultValues());
    }
  }, [isOpen, promotion, form]);

  const onSubmit = (values: PromotionFormValues) => {
    startTransition(async () => {
      let rules: any = { type: values.type };
      if (values.type === "buy_x_get_y_free") {
        rules = { ...rules, ...values.buy_x_get_y_free };
      } else if (values.type === "free_shipping") {
        rules = { 
            ...rules, 
            min_units: values.free_shipping?.min_units,
            locations: values.free_shipping?.locations.split(',').map(s => s.trim()).filter(Boolean) || []
        };
      }

      const payload = {
        name: values.name,
        description: values.description,
        id: promotion?.id,
        rules,
      };

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
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{promotion ? "Editar Promoción" : "Nueva Promoción"}</DialogTitle>
          <DialogDescription>
            {promotion
              ? "Actualiza los detalles y reglas de esta promoción."
              : "Define una nueva promoción con sus reglas."}
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 pt-4">
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Nombre de la Promoción</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g., Promo Barberías 8+2" {...field} />
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
                  <FormLabel>Descripción Breve</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g., Llevando 8 productos, te llevas 2 gratis." {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="type"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Tipo de Promoción</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Selecciona un tipo de promoción" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="buy_x_get_y_free">Compre X, lleve Y gratis</SelectItem>
                      <SelectItem value="free_shipping">Envío sin cargo</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            {/* Conditional Fields */}
            <div className={cn("space-y-4 p-4 border rounded-md bg-muted/30", selectedType === "buy_x_get_y_free" ? "block" : "hidden")}>
                <h4 className="font-medium text-sm">Reglas de "Compre X, lleve Y gratis"</h4>
                <div className="grid grid-cols-2 gap-4">
                    <FormField
                    control={form.control}
                    name="buy_x_get_y_free.buy"
                    render={({ field }) => (
                        <FormItem>
                        <FormLabel>Cantidad a Comprar</FormLabel>
                        <FormControl>
                            <Input type="number" placeholder="e.g., 8" {...field} />
                        </FormControl>
                        <FormMessage />
                        </FormItem>
                    )}
                    />
                    <FormField
                    control={form.control}
                    name="buy_x_get_y_free.get"
                    render={({ field }) => (
                        <FormItem>
                        <FormLabel>Cantidad de Regalo</FormLabel>
                        <FormControl>
                            <Input type="number" placeholder="e.g., 2" {...field} />
                        </FormControl>
                        <FormMessage />
                        </FormItem>
                    )}
                    />
                </div>
            </div>

            <div className={cn("space-y-4 p-4 border rounded-md bg-muted/30", selectedType === "free_shipping" ? "block" : "hidden")}>
                 <h4 className="font-medium text-sm">Reglas de "Envío sin cargo"</h4>
                 <FormField
                    control={form.control}
                    name="free_shipping.min_units"
                    render={({ field }) => (
                        <FormItem>
                        <FormLabel>Unidades Mínimas</FormLabel>
                        <FormControl>
                            <Input type="number" placeholder="e.g., 12" {...field} />
                        </FormControl>
                        <FormMessage />
                        </FormItem>
                    )}
                    />
                 <FormField
                    control={form.control}
                    name="free_shipping.locations"
                    render={({ field }) => (
                        <FormItem>
                        <FormLabel>Ciudades (separadas por coma)</FormLabel>
                        <FormControl>
                            <Input placeholder="CABA, Rosario, Córdoba" {...field} />
                        </FormControl>
                        <FormMessage />
                        </FormItem>
                    )}
                    />
            </div>


            <DialogFooter className="pt-4">
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
