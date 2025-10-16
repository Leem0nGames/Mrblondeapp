


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
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { submitOnboardingForm } from "@/app/actions/user.actions";
import type { Client } from "@/types";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { provinces, getLocalitiesByProvince } from "@/lib/geo-data";
import { Checkbox } from "@/components/ui/checkbox";

// --- CUIT Validation Logic ---
const validateCuit = (cuit: string): boolean | number => {
    if (!/^\d{11}$/.test(cuit)) return false;

    const coeficientes = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
    const digitos = cuit.split('').map(Number);
    const digitoVerificador = digitos.pop()!;

    let acumulado = 0;
    for (let i = 0; i < digitos.length; i++) {
        acumulado += digitos[i] * coeficientes[i];
    }

    const resto = acumulado % 11;
    let digitoCalculado = 11 - resto;
    if (digitoCalculado === 11) {
        digitoCalculado = 0;
    } else if (digitoCalculado === 10) {
        return false;
    }
    
    return digitoVerificador === digitoCalculado ? true : digitoCalculado;
};


const cuitSchema = z.string().superRefine((cuit, ctx) => {
    const validationResult = validateCuit(cuit);
    if (validationResult === true) {
        return;
    }
    if (typeof validationResult === 'number') {
        const CUITBase = cuit.slice(0, -1);
        ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: `CUIT inválido. El dígito verificador debería ser ${validationResult}. ¿Quisiste decir ${CUITBase}${validationResult}?`,
        });
    } else {
        ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "CUIT inválido. Debe tener 11 dígitos sin guiones y ser válido.",
        });
    }
});


const deliveryDays = [
  { id: 'lunes', label: 'L' },
  { id: 'martes', label: 'M' },
  { id: 'miercoles', label: 'M' },
  { id: 'jueves', label: 'J' },
  { id: 'viernes', label: 'V' },
  { id: 'sabado', label: 'S' },
];

const formSchema = z.object({
  cuit: cuitSchema,
  contact_name: z.string().min(3, "El nombre es requerido."),
  contact_dni: z.string().min(7, "El DNI debe tener entre 7 y 8 dígitos.").max(8, "El DNI debe tener entre 7 y 8 dígitos."),
  
  province: z.string().min(1, "La provincia es requerida."),
  locality: z.string().min(1, "La localidad es requerida."),
  street_address: z.string().min(3, "La calle es requerida."),
  street_number: z.string().min(1, "El número es requerido."),

  delivery_days: z.array(z.string()).refine((value) => value.some((item) => item), {
    message: "Debes seleccionar al menos un día.",
  }),
  delivery_time_from: z.string().min(1, "La hora de inicio es requerida."),
  delivery_time_to: z.string().min(1, "La hora de fin es requerida."),
  
  email: z.string().email("Debe ser un email válido."),
  instagram: z.string().optional(),
  fiscal_status: z.string().min(1, "La condición fiscal es requerida"),
}).refine(data => {
    // Combine address parts into a single string for DB
    // This logic can be done before sending to the server action
    return true;
});

type OnboardingFormValues = z.infer<typeof formSchema>;

const getAddressParts = (address: string | null) => {
    if (!address) return { street_address: '', street_number: '', locality: '', province: '' };
    const parts = address.split(',').map(p => p.trim());
    const province = provinces.find(p => p === parts[parts.length - 1]);
    const locality = province && parts[parts.length - 2] ? parts[parts.length - 2] : '';
    
    // Improved logic to separate street and number
    const streetAndNumber = parts.length > 2 ? parts[0] : (parts.length > 1 && !province && !locality) ? parts[0] : '';
    const match = streetAndNumber.match(/^(.*?)(\s+\d+)?$/);
    const street_address = match ? match[1] : streetAndNumber;
    const street_number = match && match[2] ? match[2].trim() : '';

    return {
        street_address: street_address,
        street_number: street_number,
        locality: locality || (parts.length > 1 && !province ? parts[1] : ''),
        province: province || '',
    };
};

const getDeliveryParts = (deliveryWindow: string | null) => {
    if (!deliveryWindow) return { days: [], from: '09:00', to: '18:00' };
    
    const parts = deliveryWindow.split(' de ');
    if (parts.length < 2) return { days: [], from: '09:00', to: '18:00' };

    const dayString = parts[0].toLowerCase();
    const days = deliveryDays.map(d => d.id).filter(d => dayString.includes(d.slice(0, 2)) || dayString.includes(d));

    const timeString = parts[1];
    const timeParts = timeString.replace('hs', '').split(' a ');
    const from = timeParts[0] ? `${timeParts[0].padStart(2, '0')}:00` : '09:00';
    const to = timeParts[1] ? `${timeParts[1].padStart(2, '0')}:00` : '18:00';

    return { days, from, to };
};

export function OnboardingFormDialog({ children, client }: { children: React.ReactNode, client: Client }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  
  const addressParts = getAddressParts(client.address);
  const deliveryParts = getDeliveryParts(client.delivery_window);

  const form = useForm<OnboardingFormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      cuit: client.cuit ?? "",
      contact_name: client.contact_name?.startsWith('Cliente Pendiente') ? '' : client.contact_name ?? "",
      contact_dni: client.contact_dni ?? "",
      province: addressParts.province,
      locality: addressParts.locality,
      street_address: addressParts.street_address,
      street_number: addressParts.street_number,
      delivery_days: deliveryParts.days,
      delivery_time_from: deliveryParts.from,
      delivery_time_to: deliveryParts.to,
      email: client.email ?? "",
      instagram: client.instagram ?? "",
      fiscal_status: client.fiscal_status ?? "",
    },
  });

  const watchedProvince = form.watch("province");
  const availableLocalities = watchedProvince ? getLocalitiesByProvince(watchedProvince) : [];
  
  useEffect(() => {
    if (availableLocalities.length > 0 && !availableLocalities.includes(form.getValues('locality'))) {
      form.setValue('locality', '');
    }
  }, [watchedProvince, availableLocalities, form]);


  const onSubmit = (values: OnboardingFormValues) => {
    startTransition(async () => {
      const result = await submitOnboardingForm({
        ...values,
        onboarding_token: client.onboarding_token,
      });

      if (result.error) {
        toast({
          title: "Error al guardar",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "¡Datos guardados!",
          description: "La información del cliente ha sido actualizada.",
        });
        setIsOpen(false);
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>
        {children}
      </DialogTrigger>
      <DialogContent className="sm:max-w-2xl grid-rows-[auto_1fr_auto] p-0 max-h-[90vh]">
        <DialogHeader className="p-6 pb-2">
          <DialogTitle>Editar Datos del Cliente</DialogTitle>
          <DialogDescription>
            Actualiza la información de contacto y entrega de {client.contact_name}.
          </DialogDescription>
        </DialogHeader>
        <ScrollArea className="h-full w-full">
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6 px-6 pb-6">
                 <FormField
                  control={form.control}
                  name="fiscal_status"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Condición Fiscal</FormLabel>
                       <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Seleccione una condición..." />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="Responsable Inscripto">Responsable Inscripto (Factura A)</SelectItem>
                          <SelectItem value="Monotributista">Monotributista (Factura B)</SelectItem>
                          <SelectItem value="Consumidor Final">Consumidor Final (Factura B)</SelectItem>
                          <SelectItem value="Exento">Exento (Factura B)</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="cuit"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>CUIT de la barbería/distribuidora</FormLabel>
                      <FormControl>
                        <Input placeholder="Ej: 20123456789" {...field} />
                      </FormControl>
                      <FormDescription>11 dígitos, sin guiones.</FormDescription>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <FormField
                    control={form.control}
                    name="contact_name"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Nombre y Apellido de contacto</FormLabel>
                        <FormControl>
                          <Input {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={form.control}
                    name="contact_dni"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>DNI de contacto</FormLabel>
                        <FormControl>
                          <Input placeholder="Sin puntos" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </div>
                
                 <div className="space-y-4 rounded-lg border p-4">
                  <h4 className="font-medium">Dirección de Entrega</h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <FormField control={form.control} name="province" render={({ field }) => (
                      <FormItem><FormLabel>Provincia</FormLabel><Select onValueChange={field.onChange} defaultValue={field.value}><FormControl><SelectTrigger><SelectValue placeholder="Seleccione una provincia..." /></SelectTrigger></FormControl><SelectContent><ScrollArea className="h-72">{provinces.map(p => <SelectItem key={p} value={p}>{p}</SelectItem>)}</ScrollArea></SelectContent></Select><FormMessage /></FormItem>
                    )}/>
                    <FormField control={form.control} name="locality" render={({ field }) => (
                      <FormItem><FormLabel>Localidad</FormLabel><Select onValueChange={field.onChange} value={field.value || ''} disabled={!watchedProvince}><FormControl><SelectTrigger><SelectValue placeholder={watchedProvince ? "Seleccione una localidad..." : "Elija una provincia primero"} /></SelectTrigger></FormControl><SelectContent><ScrollArea className="h-72">{availableLocalities.map(l => <SelectItem key={l} value={l}>{l}</SelectItem>)}</ScrollArea></SelectContent></Select><FormMessage /></FormItem>
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
                  <h4 className="font-medium">Ventana Horaria de Entrega</h4>
                  <FormField control={form.control} name="delivery_days" render={() => (
                    <FormItem>
                      <FormLabel>Días de Entrega</FormLabel>
                      <div className="grid grid-cols-3 sm:grid-cols-6 gap-2 pt-2">
                        {deliveryDays.map((item) => (
                          <FormField key={item.id} control={form.control} name="delivery_days" render={({ field }) => (
                            <FormItem key={item.id} className="flex flex-row items-center space-x-2 space-y-0">
                              <FormControl>
                                <Checkbox
                                  checked={field.value?.includes(item.id)}
                                  onCheckedChange={(checked) => {
                                    return checked
                                      ? field.onChange([...(field.value || []), item.id])
                                      : field.onChange(field.value?.filter((value) => value !== item.id));
                                  }}
                                />
                              </FormControl>
                              <FormLabel className="font-normal">{item.label}</FormLabel>
                            </FormItem>
                          )} />
                        ))}
                      </div>
                      <FormMessage />
                    </FormItem>
                  )}/>
                   <div className="grid grid-cols-2 gap-4">
                      <FormField control={form.control} name="delivery_time_from" render={({ field }) => (
                        <FormItem><FormLabel>Desde</FormLabel><FormControl><Input type="time" {...field} /></FormControl><FormMessage /></FormItem>
                      )}/>
                       <FormField control={form.control} name="delivery_time_to" render={({ field }) => (
                        <FormItem><FormLabel>Hasta</FormLabel><FormControl><Input type="time" {...field} /></FormControl><FormMessage /></FormItem>
                      )}/>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <FormField
                    control={form.control}
                    name="email"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Mail</FormLabel>
                        <FormControl>
                          <Input type="email" placeholder="tu@email.com" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={form.control}
                    name="instagram"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Instagram (Opcional)</FormLabel>
                        <FormControl>
                          <Input placeholder="@usuario" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </div>
                 <DialogFooter className="pt-4 !mt-0">
                    <DialogClose asChild>
                        <Button variant="outline" type="button">Cancelar</Button>
                    </DialogClose>
                    <Button type="submit" disabled={isPending}>
                        {isPending ? "Guardando..." : "Guardar Cambios"}
                    </Button>
                </DialogFooter>
              </form>
            </Form>
        </ScrollArea>
      </DialogContent>
    </Dialog>
  );
}
