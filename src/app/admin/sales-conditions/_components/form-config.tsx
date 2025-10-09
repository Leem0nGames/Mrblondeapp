"use client";

import { z } from "zod";
import { FormField, FormItem, FormLabel, FormControl, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { upsertSalesCondition } from "@/app/actions/admin.actions";
import type { FormConfig } from "../../_components/entity-dialog";
import { cn } from "@/lib/utils";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";


// --- Esquemas de Zod ---
const netDaysSchema = z.object({
  days: z.coerce.number().min(1, "Debe ser al menos 1"),
});

const discountSchema = z.object({
  percentage: z.coerce.number().min(1, "Debe ser al menos 1").max(100, "No puede ser más de 100"),
});

const installmentsSchema = z.object({
    installments: z.coerce.number().min(1, "Debe ser al menos 1"),
});

const salesConditionSchema = z.object({
  name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  description: z.string().optional(),
  type: z.enum(["net_days", "discount", "installments"]),
  net_days: netDaysSchema.optional(),
  discount: discountSchema.optional(),
  installments: installmentsSchema.optional(),
}).superRefine((data, ctx) => {
    if (data.type === 'net_days' && !data.net_days) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: "Las reglas de 'Plazo de pago' son requeridas.", path: ["net_days"] });
    }
    if (data.type === 'discount' && !data.discount) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: "Las reglas de 'Descuento' son requeridas.", path: ["discount"] });
    }
    if (data.type === 'installments' && !data.installments) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: "Las reglas de 'Cuotas' son requeridas.", path: ["installments"] });
    }
});


// --- Lógica de Procesamiento y Valores por Defecto ---
const getSalesConditionDefaultValues = (entity?: any) => {
  if (!entity) {
    return {
      name: "",
      description: "",
      type: "net_days" as const,
      net_days: { days: 30 },
      discount: { percentage: 5 },
      installments: { installments: 3 },
    };
  }

  const type = entity.rules.type || "net_days";
  return {
    name: entity.name,
    description: entity.description ?? "",
    type: type,
    net_days: {
        days: entity.rules.days || 30,
    },
    discount: {
        percentage: entity.rules.percentage || 5,
    },
    installments: {
        installments: entity.rules.installments || 3,
    }
  };
};

const processPayload = (values: z.infer<typeof salesConditionSchema>) => {
  let rules: any = { type: values.type };
  if (values.type === "net_days" && values.net_days) {
    rules = { ...rules, ...values.net_days };
  } else if (values.type === "discount" && values.discount) {
    rules = { ...rules, ...values.discount };
  } else if (values.type === "installments" && values.installments) {
    rules = { ...rules, ...values.installments };
  }

  return {
    name: values.name,
    description: values.description,
    rules,
  };
};

// --- Renderizado de Campos ---
const renderSalesConditionFields = (form: any) => {
    const selectedType = form.watch("type");

    return (
        <>
        <FormField
            control={form.control}
            name="name"
            render={({ field }) => (
            <FormItem>
                <FormLabel>Nombre de la Condición</FormLabel>
                <FormControl>
                <Input placeholder="e.g., Pago a 30 días" {...field} />
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
                <Input placeholder="El pago total debe realizarse 30 días después de la fecha de la factura." {...field} />
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
                <FormLabel>Tipo de Condición</FormLabel>
                <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                    <SelectTrigger>
                    <SelectValue placeholder="Selecciona un tipo" />
                    </SelectTrigger>
                </FormControl>
                <SelectContent>
                    <SelectItem value="net_days">Plazo de pago (días)</SelectItem>
                    <SelectItem value="discount">Descuento por pronto pago (%)</SelectItem>
                    <SelectItem value="installments">Financiación (cuotas)</SelectItem>
                </SelectContent>
                </Select>
                <FormMessage />
            </FormItem>
            )}
        />

        {/* --- Campos Condicionales --- */}
        <div className={cn("space-y-4 p-4 border rounded-md bg-muted/30", selectedType === "net_days" ? "block" : "hidden")}>
            <h4 className="font-medium text-sm">Reglas de "Plazo de pago"</h4>
            <FormField control={form.control} name="net_days.days" render={({ field }) => (
                <FormItem>
                    <FormLabel>Días de Plazo</FormLabel>
                    <FormControl><Input type="number" placeholder="30" {...field} /></FormControl>
                    <FormMessage />
                </FormItem>
            )}
            />
        </div>

        <div className={cn("space-y-4 p-4 border rounded-md bg-muted/30", selectedType === "discount" ? "block" : "hidden")}>
            <h4 className="font-medium text-sm">Reglas de "Descuento"</h4>
            <FormField control={form.control} name="discount.percentage" render={({ field }) => (
                <FormItem>
                    <FormLabel>Porcentaje de Descuento</FormLabel>
                    <FormControl><Input type="number" placeholder="10" {...field} /></FormControl>
                    <FormMessage />
                </FormItem>
            )}
            />
        </div>

        <div className={cn("space-y-4 p-4 border rounded-md bg-muted/30", selectedType === "installments" ? "block" : "hidden")}>
            <h4 className="font-medium text-sm">Reglas de "Cuotas"</h4>
            <FormField control={form.control} name="installments.installments" render={({ field }) => (
                <FormItem>
                    <FormLabel>Cantidad de Cuotas</FormLabel>
                    <FormControl><Input type="number" placeholder="3" {...field} /></FormControl>
                    <FormMessage />
                </FormItem>
            )}
            />
        </div>
        </>
    );
};


// 4. Configuración completa para el formulario
export const salesConditionFormConfig: FormConfig<typeof salesConditionSchema> = {
  entityName: "Condición de Venta",
  schema: salesConditionSchema,
  upsertAction: (values) => upsertSalesCondition(processPayload(values)),
  getDefaultValues: getSalesConditionDefaultValues,
  renderFields: renderSalesConditionFields,
};
