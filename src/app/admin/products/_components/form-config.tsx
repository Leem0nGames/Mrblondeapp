
"use client";

import { z } from "zod";
import { FormField, FormItem, FormLabel, FormControl, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { upsertProduct } from "@/app/actions/admin.actions";
import type { FormConfig } from "../../_components/entity-dialog";

// 1. Esquema de validación para Producto
const productSchema = z.object({
  name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  description: z.string().optional(),
  base_price: z.coerce.number().min(0, "El precio debe ser un número positivo"),
  category: z.string().optional(),
});

// 2. Función para obtener los valores por defecto del formulario de Producto
const getProductDefaultValues = (product?: any) => ({
  name: product?.name ?? "",
  description: product?.description ?? "",
  base_price: product?.base_price ?? 0,
  category: product?.category ?? "",
});

// 3. Función para renderizar los campos del formulario de Producto
const renderProductFields = (form: any) => (
  <>
    <FormField
      control={form.control}
      name="name"
      render={({ field }) => (
        <FormItem>
          <FormLabel>Nombre del Producto</FormLabel>
          <FormControl>
            <Input placeholder="e.g., Cera Modeladora" {...field} />
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
            <Textarea placeholder="Detalles del producto..." {...field} />
          </FormControl>
          <FormMessage />
        </FormItem>
      )}
    />
     <div className="grid grid-cols-2 gap-4">
      <FormField
        control={form.control}
        name="base_price"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Precio Base</FormLabel>
            <FormControl>
              <Input type="number" step="0.01" {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
       <FormField
        control={form.control}
        name="category"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Categoría</FormLabel>
            <FormControl>
              <Input placeholder="e.g., Ceras, Shampoos" {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
    </div>
  </>
);

// 4. Configuración completa para el formulario de Producto
export const productFormConfig: FormConfig<typeof productSchema> = {
  entityName: "Producto",
  schema: productSchema,
  upsertAction: upsertProduct,
  getDefaultValues: getProductDefaultValues,
  renderFields: renderProductFields,
};
