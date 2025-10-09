
"use client";

import { z } from "zod";
import { FormField, FormItem, FormLabel, FormControl, FormMessage, FormDescription } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { upsertSalesCondition } from "@/app/actions/admin.actions";
import type { FormConfig } from "../../_components/entity-dialog";

// 1. Esquema de validación para SalesCondition
const salesConditionSchema = z.object({
  name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  description: z.string().optional(),
  rules: z.string().min(1, "Las reglas son requeridas"), // Por ahora un string, luego puede ser un JSON
});

// 2. Función para obtener los valores por defecto
const getSalesConditionDefaultValues = (entity?: any) => ({
  name: entity?.name ?? "",
  description: entity?.description ?? "",
  rules: entity ? JSON.stringify(entity.rules, null, 2) : "{\n  \"type\": \"net_30\"\n}",
});

// 3. Función para renderizar los campos del formulario
const renderSalesConditionFields = (form: any) => (
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
        name="rules"
        render={({ field }) => (
            <FormItem>
            <FormLabel>Reglas (JSON)</FormLabel>
            <FormControl>
                <Textarea
                placeholder='{ "type": "net_days", "days": 30 }'
                className="font-code"
                rows={5}
                {...field}
                />
            </FormControl>
            <FormDescription>
                Define la lógica de la condición en formato JSON.
            </FormDescription>
            <FormMessage />
            </FormItem>
        )}
        />
  </>
);


const processPayload = (values: z.infer<typeof salesConditionSchema>) => {
  try {
    const parsedRules = JSON.parse(values.rules);
    return {
      name: values.name,
      description: values.description,
      rules: parsedRules,
    };
  } catch (error) {
    // Si el JSON es inválido, se lanzará un error que será atrapado por el `upsertAction`
    throw new Error("El formato de las reglas JSON es inválido.");
  }
};


// 4. Configuración completa para el formulario
export const salesConditionFormConfig: FormConfig<typeof salesConditionSchema> = {
  entityName: "Condición de Venta",
  schema: salesConditionSchema,
  upsertAction: async (values) => {
    try {
        const payload = processPayload(values);
        return await upsertSalesCondition(payload);
    } catch (error: any) {
        return { data: null, error: { message: error.message || "Error al procesar las reglas." } };
    }
  },
  getDefaultValues: getSalesConditionDefaultValues,
  renderFields: renderSalesConditionFields,
};

