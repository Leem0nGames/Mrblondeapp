
"use client";

import { z } from "zod";
import { FormField, FormItem, FormLabel, FormControl, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { upsertPromotion } from "@/app/actions/admin.actions";
import type { FormConfig } from "../../_components/entity-dialog";
import { cn } from "@/lib/utils";

// --- Esquemas de Zod ---
const buyXgetYFreeSchema = z.object({
  buy: z.coerce.number().min(1, "Debe ser al menos 1"),
  get: z.coerce.number().min(1, "Debe ser al menos 1"),
});

const freeShippingSchema = z.object({
  min_units: z.coerce.number().min(1, "Debe ser al menos 1"),
  locations: z.string().min(1, "Debe haber al menos una ciudad"),
});

const promotionSchema = z.object({
  name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  description: z.string().optional(),
  type: z.enum(["buy_x_get_y_free", "free_shipping"]),
  buy_x_get_y_free: buyXgetYFreeSchema.optional(),
  free_shipping: freeShippingSchema.optional(),
}).superRefine((data, ctx) => {
    if (data.type === 'buy_x_get_y_free' && !data.buy_x_get_y_free) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: "Las reglas de 'Compre X, lleve Y' son requeridas.", path: ["buy_x_get_y_free"] });
    }
    if (data.type === 'free_shipping' && !data.free_shipping) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: "Las reglas de 'Envío sin cargo' son requeridas.", path: ["free_shipping"] });
    }
});


// --- Lógica de Procesamiento y Valores por Defecto ---
const getPromotionDefaultValues = (promotion?: any) => {
  if (!promotion) {
    return {
      name: "",
      description: "",
      type: "buy_x_get_y_free" as const,
      buy_x_get_y_free: { buy: 8, get: 2 },
      free_shipping: { min_units: 12, locations: "" },
    };
  }

  const type = promotion.rules.type || "buy_x_get_y_free";
  return {
    name: promotion.name,
    description: promotion.description ?? "",
    type: type,
    buy_x_get_y_free: {
      buy: promotion.rules.buy || 8,
      get: promotion.rules.get || 2,
    },
    free_shipping: {
      min_units: promotion.rules.min_units || 12,
      locations: (promotion.rules.locations || []).join(", "),
    },
  };
};

const processPromotionPayload = (values: z.infer<typeof promotionSchema>) => {
  let rules: any = { type: values.type };
  if (values.type === "buy_x_get_y_free" && values.buy_x_get_y_free) {
    rules = { ...rules, ...values.buy_x_get_y_free };
  } else if (values.type === "free_shipping" && values.free_shipping) {
    rules = {
      ...rules,
      min_units: values.free_shipping.min_units,
      locations: values.free_shipping.locations.split(',').map(s => s.trim()).filter(Boolean),
    };
  }

  return {
    name: values.name,
    description: values.description,
    rules,
  };
};

// --- Renderizado de Campos ---
const renderPromotionFields = (form: any) => {
  const selectedType = form.watch("type");

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
              <Input placeholder="Llevando 8 productos, te llevas 2 gratis." {...field} />
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
                <SelectItem value="buy_x_get_y_free">Compre X, lleve Y gratis</SelectItem>
                <SelectItem value="free_shipping">Envío sin cargo</SelectItem>
              </SelectContent>
            </Select>
            <FormMessage />
          </FormItem>
        )}
      />

      {/* --- Campos Condicionales --- */}
      <div className={cn("space-y-4 p-4 border rounded-md bg-muted/30", selectedType === "buy_x_get_y_free" ? "block" : "hidden")}>
        <h4 className="font-medium text-sm">Reglas de "Compre X, lleve Y gratis"</h4>
        <div className="grid grid-cols-2 gap-4">
          <FormField control={form.control} name="buy_x_get_y_free.buy" render={({ field }) => (
              <FormItem>
                <FormLabel>Cantidad a Comprar</FormLabel>
                <FormControl><Input type="number" placeholder="8" {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormField control={form.control} name="buy_x_get_y_free.get" render={({ field }) => (
              <FormItem>
                <FormLabel>Cantidad de Regalo</FormLabel>
                <FormControl><Input type="number" placeholder="2" {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        </div>
      </div>

      <div className={cn("space-y-4 p-4 border rounded-md bg-muted/30", selectedType === "free_shipping" ? "block" : "hidden")}>
        <h4 className="font-medium text-sm">Reglas de "Envío sin cargo"</h4>
        <FormField control={form.control} name="free_shipping.min_units" render={({ field }) => (
            <FormItem>
              <FormLabel>Unidades Mínimas</FormLabel>
              <FormControl><Input type="number" placeholder="12" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField control={form.control} name="free_shipping.locations" render={({ field }) => (
            <FormItem>
              <FormLabel>Ciudades (separadas por coma)</FormLabel>
              <FormControl><Input placeholder="CABA, Rosario, Córdoba" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
      </div>
    </>
  );
};


// --- Configuración Final ---
export const promotionFormConfig: FormConfig<typeof promotionSchema> = {
  entityName: "Promoción",
  schema: promotionSchema,
  upsertAction: (values) => upsertPromotion(processPromotionPayload(values)),
  getDefaultValues: getPromotionDefaultValues,
  renderFields: renderPromotionFields,
};
