
"use client";

import { useEffect } from "react";
import { useFormContext } from "react-hook-form";
import { cn } from "@/lib/utils";
import {
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export function PromotionFormFields({ form }: { form: any }) {
  const { watch, setValue } = form;
  const selectedType = watch("type");

  // This is the key change: When the promotion type changes,
  // we clear the values of the other rule type to avoid validation conflicts.
  useEffect(() => {
    if (selectedType === "buy_x_get_y_free") {
      setValue("rules.free_shipping", undefined, { shouldValidate: false });
    } else if (selectedType === "free_shipping") {
      setValue("rules.buy_x_get_y_free", undefined, { shouldValidate: false });
    }
  }, [selectedType, setValue]);

  return (
    <>
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
              <Input
                placeholder="Llevando 8 productos, te llevas 2 gratis."
                {...field}
              />
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
                  <SelectValue placeholder="Selecciona un tipo" />
                </SelectTrigger>
              </FormControl>
              <SelectContent>
                <SelectItem value="buy_x_get_y_free">
                  Compre X, lleve Y gratis
                </SelectItem>
                <SelectItem value="free_shipping">Envío sin cargo</SelectItem>
              </SelectContent>
            </Select>
            <FormMessage />
          </FormItem>
        )}
      />

      {/* --- Conditional Fields --- */}
      <div
        className={cn(
          "space-y-4 p-4 border rounded-md bg-muted/30",
          selectedType === "buy_x_get_y_free" ? "block" : "hidden"
        )}
      >
        <h4 className="font-medium text-sm">
          Reglas de "Compre X, lleve Y gratis"
        </h4>
        <div className="grid grid-cols-2 gap-4">
          <FormField
            control={form.control}
            name="rules.buy_x_get_y_free.buy"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Cantidad a Comprar</FormLabel>
                <FormControl>
                  <Input type="number" placeholder="8" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormField
            control={form.control}
            name="rules.buy_x_get_y_free.get"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Cantidad de Regalo</FormLabel>
                <FormControl>
                  <Input type="number" placeholder="2" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        </div>
      </div>

      <div
        className={cn(
          "space-y-4 p-4 border rounded-md bg-muted/30",
          selectedType === "free_shipping" ? "block" : "hidden"
        )}
      >
        <h4 className="font-medium text-sm">Reglas de "Envío sin cargo"</h4>
        <FormField
          control={form.control}
          name="rules.free_shipping.min_units"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Unidades Mínimas</FormLabel>
              <FormControl>
                <Input type="number" placeholder="12" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="rules.free_shipping.locations"
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
    </>
  );
}
