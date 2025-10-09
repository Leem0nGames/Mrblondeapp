
"use client";

import { useState, useEffect } from "react";
import { z } from "zod";
import { FormField, FormItem, FormLabel, FormControl, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { upsertAgreement, getPriceLists } from "@/app/actions/admin.actions";
import type { FormConfig } from "../../_components/entity-dialog";
import type { PriceList } from "@/types";

const agreementSchema = z.object({
  agreement_name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  client_type: z.enum(["barberia", "distribuidor", "especial"]),
  price_list_id: z.string().nullable(),
});

const getAgreementDefaultValues = (agreement?: any) => ({
  agreement_name: agreement?.agreement_name ?? "",
  client_type: agreement?.client_type ?? "barberia",
  price_list_id: agreement?.price_list_id ?? null,
});

const renderAgreementFields = (form: any) => {
  const [priceLists, setPriceLists] = useState<PriceList[]>([]);
  
  useEffect(() => {
    async function fetchPriceLists() {
        const { data } = await getPriceLists();
        setPriceLists(data ?? []);
    }
    fetchPriceLists();
  }, []);

  return (
    <>
      <FormField
        control={form.control}
        name="agreement_name"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Nombre del Convenio</FormLabel>
            <FormControl>
              <Input placeholder="e.g., Distribuidores Premium" {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <FormField
          control={form.control}
          name="client_type"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Tipo de Cliente</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Selecciona un tipo" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="barberia">Barbería</SelectItem>
                  <SelectItem value="distribuidor">Distribuidor</SelectItem>
                  <SelectItem value="especial">Especial</SelectItem>
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="price_list_id"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Lista de Precios</FormLabel>
              <Select onValueChange={(value) => field.onChange(value === 'null' ? null : value)} defaultValue={field.value ?? 'null'}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Selecciona una lista..." />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="null">Ninguna</SelectItem>
                  {priceLists.map(list => (
                    <SelectItem key={list.id} value={list.id}>
                      {list.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />
      </div>
    </>
  );
};

export const agreementFormConfig: FormConfig<typeof agreementSchema> = {
  entityName: "Convenio",
  schema: agreementSchema,
  upsertAction: (values) => upsertAgreement(values),
  getDefaultValues: getAgreementDefaultValues,
  renderFields: renderAgreementFields,
};
