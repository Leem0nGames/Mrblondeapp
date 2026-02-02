
"use client";

import { z } from "zod";
import { useState, useEffect } from "react";
import { FormField, FormItem, FormLabel, FormControl, FormMessage, FormDescription } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { upsertProduct } from "@/app/admin/actions/products.actions";
import type { FormConfig } from "../../_components/entity-dialog";
import Image from "next/image";
import { Label } from "@/components/ui/label";

const productSchema = z.object({
  name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  description: z.string().optional(),
  category: z.string().optional(),
  image: z.any().optional(),
});

const getProductDefaultValues = (product?: any) => ({
  name: product?.name ?? "",
  description: product?.description ?? "",
  category: product?.category ?? "",
  image_url: product?.image_url ?? null,
  image: undefined,
});

const renderProductFields = (form: any) => {
  const currentImageUrl = form.watch("image_url");
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  return (
  <>
    <FormField
        control={form.control}
        name="image"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Imagen del Producto</FormLabel>
            <FormControl>
                <Input
                    type="file"
                    accept="image/png, image/jpeg, image/webp"
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) {
                        field.onChange(file);
                        const objectUrl = URL.createObjectURL(file);
                        setPreviewUrl(objectUrl);
                      }
                    }}
                />
            </FormControl>
            <FormDescription>
                Sube una imagen (máx. 5MB, recomendado: formato cuadrado).
            </FormDescription>
            <FormMessage />
          </FormItem>
        )}
      />

    {previewUrl && (
        <div className="space-y-2">
            <Label>Vista Previa</Label>
            <div className="relative w-32 h-32 rounded-lg overflow-hidden border">
                <Image
                    src={previewUrl}
                    alt="Vista previa"
                    fill
                    className="object-cover"
                />
            </div>
        </div>
    )}

    {currentImageUrl && !previewUrl && (
        <div className="space-y-2">
            <Label>Imagen Actual</Label>
            <div className="relative w-24 h-24">
                <Image
                    src={currentImageUrl}
                    alt="Imagen actual"
                    fill
                    className="rounded-md object-cover"
                />
            </div>
            <p className="text-xs text-muted-foreground">
                Sube una nueva imagen para reemplazar.
            </p>
        </div>
    )}
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
  </>
)};


// Wrapper action to convert form data for the server action
const handleUpsertProduct = async (payload: z.infer<typeof productSchema> & { id?: string }) => {
    const formData = new FormData();
    Object.entries(payload).forEach(([key, value]) => {
        if (value !== null && value !== undefined) {
            formData.append(key, value);
        }
    });

    return upsertProduct(formData);
}

// 4. Configuración completa para el formulario de Producto
export const productFormConfig: FormConfig<typeof productSchema> = {
  entityName: "Producto",
  schema: productSchema,
  upsertAction: handleUpsertProduct,
  getDefaultValues: getProductDefaultValues,
  renderFields: renderProductFields,
};
