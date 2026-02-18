
"use client";

import { useTransition, useEffect, useState } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
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
import type { Client } from "@/types";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { provinces, getLocalitiesByProvince } from "@/lib/geo-data";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { Search, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { getCuitData } from "@/app/admin/actions/cuit.actions";
import { submitOnboardingForm } from "@/app/actions/user.actions";

// --- Validation Schemas ---
const cuitSchema = z.string().optional().or(z.literal(''));
const formSchema = z.object({
  contact_name: z.string().min(3, "El nombre es requerido."),
  email: z.string().email("Debe ser un email válido."),
  cuit: cuitSchema,
  contact_dni: z.string().optional(),
  fiscal_status: z.string().optional(),
  instagram: z.string().optional(),
  
  province: z.string().optional(),
  locality: z.string().optional(),
  street_address: z.string().optional(),
  street_number: z.string().optional(),

  delivery_days: z.array(z.string()).optional(),
  delivery_time_from: z.string().optional(),
  delivery_time_to: z.string().optional(),
});
type OnboardingFormValues = z.infer<typeof formSchema>;


// --- Helper Functions ---
const deliveryDays = [
  { id: 'lunes', label: 'L' }, { id: 'martes', label: 'M' }, { id: 'miercoles', label: 'Mi' },
  { id: 'jueves', label: 'J' }, { id: 'viernes', label: 'V' }, { id: 'sabado', label: 'S' },
];

const generateTimeOptions = () => {
    const options = [];
    for (let h = 8; h <= 20; h++) {
        const hour = h.toString().padStart(2, '0');
        options.push(`${hour}:00`);
    }
    return options;
};
const timeOptions = generateTimeOptions();


type OnboardingFormProps = {
    client: Partial<Client>;
    onSuccess: (clientName: string) => void;
}

export function OnboardingForm({ client, onSuccess }: OnboardingFormProps) {
  const [isPending, startTransition] = useTransition();
  const [isSearchingCuit, startCuitSearch] = useTransition();
  const { toast } = useToast();
  
  const form = useForm<OnboardingFormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      contact_name: client?.contact_name ?? "",
      email: client?.email ?? "",
      cuit: client?.cuit ?? "",
      delivery_time_from: '09:00',
      delivery_time_to: '18:00',
    },
  });

  const watchedProvince = form.watch("province");
  const watchedCuit = form.watch("cuit");
  const availableLocalities = watchedProvince ? getLocalitiesByProvince(watchedProvince) : [];
  
  useEffect(() => {
    if (watchedProvince && availableLocalities.length > 0 && !availableLocalities.includes(form.getValues('locality') || '')) {
      form.setValue('locality', '');
    }
  }, [watchedProvince, availableLocalities, form]);

  const handleCuitLookup = () => {
    const cuit = form.getValues("cuit");
    if (!cuit || !/^\d{11}$/.test(cuit)) {
        toast({ title: "CUIT Inválido", description: "Por favor, ingresa un CUIT de 11 dígitos sin guiones.", variant: "destructive" });
        return;
    }
    
    startCuitSearch(async () => {
        const { data, error } = await getCuitData(cuit);
        
        if (error) {
            toast({ title: "Error de Búsqueda", description: error, variant: "destructive" });
            return;
        }

        if (data) {
            toast({ title: "Datos Encontrados", description: `Se autocompletaron los datos para ${data.razonSocial}` });
            
            form.setValue("contact_name", data.razonSocial, { shouldValidate: true });
            form.setValue("fiscal_status", data.condicionFiscal, { shouldValidate: true });
            form.setValue("province", data.provincia, { shouldValidate: true });
            setTimeout(() => {
                form.setValue("locality", data.localidad, { shouldValidate: true });
            }, 100);
            form.setValue("street_address", data.calle, { shouldValidate: true });
            form.setValue("street_number", data.numero, { shouldValidate: true });
        }
    });
  };


  const onSubmit = (values: OnboardingFormValues) => {
    startTransition(async () => {
      // 1. Construir campos compuestos
      const fullAddress = (values.street_address && values.locality && values.province)
        ? `${values.street_address} ${values.street_number || ''}, ${values.locality}, ${values.province}`
        : undefined;

      const fullDeliveryWindow = (values.delivery_days && values.delivery_days.length > 0)
        ? `${values.delivery_days.join(', ')} de ${values.delivery_time_from} a ${values.delivery_time_to}hs`
        : undefined;

      // 2. Extraer solo los campos que la base de datos acepta
      const {
        contact_name,
        email,
        cuit,
        contact_dni,
        fiscal_status,
        instagram
      } = values;

      const result = await submitOnboardingForm({
        onboarding_token: client.onboarding_token!,
        contact_name,
        email,
        cuit: cuit || null,
        contact_dni: contact_dni || null,
        fiscal_status: fiscal_status || null,
        instagram: instagram || null,
        address: fullAddress,
        delivery_window: fullDeliveryWindow,
      });

      if (result.error) {
        toast({ title: "Error al guardar", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "¡Gracias!", description: "Tus datos han sido enviados. Pronto nos pondremos en contacto." });
        onSuccess(values.contact_name);
      }
    });
  };

  return (
      <ScrollArea className="h-full w-full">
        <div className="px-1 pb-6">
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <FormField control={form.control} name="contact_name" render={({ field }) => (
                      <FormItem><FormLabel>Razón Social / Nombre y Apellido</FormLabel><FormControl><Input placeholder="Nombre de contacto" {...field} /></FormControl><FormMessage /></FormItem>
                  )}/>
                  <FormField control={form.control} name="email" render={({ field }) => (
                      <FormItem><FormLabel>Email</FormLabel><FormControl><Input type="email" placeholder="cliente@email.com" {...field} /></FormControl><FormMessage /></FormItem>
                  )}/>
                </div>
                
                <div className="space-y-4 rounded-lg border p-4">
                  <h4 className="font-medium text-base">Información Fiscal y de Contacto</h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <FormField control={form.control} name="cuit" render={({ field }) => (
                        <FormItem>
                            <FormLabel>CUIT</FormLabel>
                            <div className="flex items-center gap-2">
                              <FormControl>
                                  <Input placeholder="11 dígitos sin guiones" {...field} />
                              </FormControl>
                              <TooltipProvider>
                                  <Tooltip>
                                      <TooltipTrigger asChild>
                                          <Button type="button" variant="outline" size="icon" onClick={handleCuitLookup} disabled={isSearchingCuit || !watchedCuit}>
                                              {isSearchingCuit ? <Loader2 className="h-4 w-4 animate-spin" /> : <Search className="h-4 w-4" />}
                                          </Button>
                                      </TooltipTrigger>
                                      <TooltipContent>
                                          <p>Buscar datos fiscales con CUIT</p>
                                      </TooltipContent>
                                  </Tooltip>
                              </TooltipProvider>
                            </div>
                            <FormMessage />
                        </FormItem>
                    )}/>
                    <FormField control={form.control} name="fiscal_status" render={({ field }) => (
                        <FormItem><FormLabel>Condición Fiscal</FormLabel><Select onValueChange={field.onChange} value={field.value || ''}><FormControl><SelectTrigger><SelectValue placeholder="Seleccione una condición..." /></SelectTrigger></FormControl><SelectContent><SelectItem value="Responsable Inscripto">Responsable Inscripto</SelectItem><SelectItem value="Monotributista">Monotributista</SelectItem><SelectItem value="Consumidor Final">Consumidor Final</SelectItem><SelectItem value="Exento">Exento</SelectItem></SelectContent></Select><FormMessage /></FormItem>
                    )}/>
                    <FormField control={form.control} name="contact_dni" render={({ field }) => (
                        <FormItem><FormLabel>DNI (Contacto)</FormLabel><FormControl><Input placeholder="Sin puntos" {...field} /></FormControl><FormMessage /></FormItem>
                    )}/>
                    <FormField control={form.control} name="instagram" render={({ field }) => (
                        <FormItem><FormLabel>Instagram (Opcional)</FormLabel><FormControl><Input placeholder="@usuario" {...field} /></FormControl><FormMessage /></FormItem>
                    )}/>
                  </div>
                </div>

                <div className="space-y-4 rounded-lg border p-4">
                  <h4 className="font-medium text-base">Dirección de Entrega</h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <FormField control={form.control} name="province" render={({ field }) => (
                      <FormItem><FormLabel>Provincia</FormLabel><Select onValueChange={field.onChange} value={field.value || ''}><FormControl><SelectTrigger><SelectValue placeholder="Seleccione una provincia..." /></SelectTrigger></FormControl><SelectContent><ScrollArea className="h-72">{provinces.map(p => <SelectItem key={p} value={p}>{p}</SelectItem>)}</ScrollArea></SelectContent></Select><FormMessage /></FormItem>
                    )}/>
                    <FormField control={form.control} name="locality" render={({ field }) => (
                      <FormItem><FormLabel>Localidad</FormLabel><Select onValueChange={field.onChange} value={field.value || ''} disabled={!watchedProvince}><FormControl><SelectTrigger><SelectValue placeholder={watchedProvince ? "Seleccione una localidad..." : "Elija provincia"} /></SelectTrigger></FormControl><SelectContent><ScrollArea className="h-72">{availableLocalities.map(l => <SelectItem key={l} value={l}>{l}</SelectItem>)}</ScrollArea></SelectContent></Select><FormMessage /></FormItem>
                    )}/>
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <div className="md:col-span-2"><FormField control={form.control} name="street_address" render={({ field }) => (
                          <FormItem><FormLabel>Calle</FormLabel><FormControl><Input placeholder="Ej: Av. Corrientes" {...field} /></FormControl><FormMessage /></FormItem>
                      )}/></div>
                      <div><FormField control={form.control} name="street_number" render={({ field }) => (
                          <FormItem><FormLabel>Número</FormLabel><FormControl><Input placeholder="Ej: 1234" {...field} /></FormControl><FormMessage /></FormItem>
                      )}/></div>
                  </div>
                </div>

                <div className="space-y-4 rounded-lg border p-4">
                  <h4 className="font-medium text-base">Ventana Horaria de Entrega</h4>
                  <FormField control={form.control} name="delivery_days" render={({ field }) => (
                    <FormItem>
                      <FormLabel>Días de Entrega</FormLabel>
                      <FormControl>
                        <div className="flex items-center gap-2 pt-2 flex-wrap">
                          {deliveryDays.map((day) => {
                            const isSelected = field.value?.includes(day.id);
                            return (
                              <Button
                                key={day.id}
                                type="button"
                                variant={isSelected ? "default" : "outline"}
                                size="sm"
                                className={cn("h-8 w-8 p-0 rounded-full", isSelected && "shadow-md")}
                                onClick={() => {
                                  const newValue = isSelected
                                    ? field.value?.filter((d) => d !== day.id)
                                    : [...(field.value || []), day.id];
                                  field.onChange(newValue);
                                }}
                              >
                                {day.label}
                              </Button>
                            );
                          })}
                        </div>
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}/>
                  <div className="grid grid-cols-2 gap-4">
                      <FormField control={form.control} name="delivery_time_from" render={({ field }) => (
                          <FormItem>
                            <FormLabel>Desde</FormLabel>
                            <Select onValueChange={field.onChange} defaultValue={field.value}>
                              <FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl>
                              <SelectContent>{timeOptions.map(time => <SelectItem key={time} value={time}>{time}</SelectItem>)}</SelectContent>
                            </Select>
                            <FormMessage />
                          </FormItem>
                      )}/>
                      <FormField control={form.control} name="delivery_time_to" render={({ field }) => (
                          <FormItem>
                            <FormLabel>Hasta</FormLabel>
                            <Select onValueChange={field.onChange} defaultValue={field.value}>
                              <FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl>
                              <SelectContent>{timeOptions.map(time => <SelectItem key={time} value={time}>{time}</SelectItem>)}</SelectContent>
                            </Select>
                            <FormMessage />
                          </FormItem>
                      )}/>
                  </div>
                </div>
                
                 <Button
                    type="submit"
                    disabled={isPending}
                    size="lg"
                    className="w-full"
                >
                    {isPending ? "Enviando datos..." : "Finalizar y Enviar Datos"}
                </Button>
              </form>
            </Form>
          </div>
        </ScrollArea>
  );
}
