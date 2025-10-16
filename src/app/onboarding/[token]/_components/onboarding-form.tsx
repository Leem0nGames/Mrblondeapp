

"use client";

import { useTransition, useEffect } from "react";
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
  FormDescription,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { submitOnboardingForm } from "@/app/actions/user.actions";
import type { Client } from "@/types";
import { useRouter } from "next/navigation";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { provinces, getLocalitiesByProvince } from "@/lib/geo-data";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Checkbox } from "@/components/ui/checkbox";

// Zod schema for CUIT validation
const cuitSchema = z.string().refine(
  (cuit) => {
    if (!/^\d{11}$/.test(cuit)) return false;
    const coeficientes = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
    const digitos = cuit.split('').map(Number);
    const digitoVerificador = digitos.pop();

    let acumulado = 0;
    for (let i = 0; i < digitos.length; i++) {
        acumulado += digitos[i] * coeficientes[i];
    }

    const resto = acumulado % 11;
    let digitoCalculado = 11 - resto;
    if (digitoCalculado === 11) {
        digitoCalculado = 0;
    } else if (digitoCalculado === 10) {
        return false; // CUIT inválido
    }

    return digitoVerificador === digitoCalculado;
  },
  { message: "CUIT inválido. Debe tener 11 dígitos sin guiones y ser válido." }
);

const deliveryDays = [
  { id: 'lunes', label: 'Lunes' },
  { id: 'martes', label: 'Martes' },
  { id: 'miercoles', label: 'Miércoles' },
  { id: 'jueves', label: 'Jueves' },
  { id: 'viernes', label: 'Viernes' },
  { id: 'sabado', label: 'Sábado' },
];

const formSchema = z.object({
  fiscal_status: z.string().min(1, "La condición fiscal es requerida"),
  cuit: cuitSchema,
  contact_name: z.string().min(3, "El nombre es requerido."),
  contact_dni: z.string().min(7, "El DNI debe tener entre 7 y 8 dígitos.").max(8, "El DNI debe tener entre 7 y 8 dígitos."),
  
  province: z.string().min(1, "La provincia es requerida."),
  locality: z.string().min(1, "La localidad es requerida."),
  street_address: z.string().min(3, "La calle es requerida."),
  street_number: z.string().min(1, "El número es requerido."),

  delivery_days: z.array(z.string()).refine((value) => value.some((item) => item), {
    message: "Debes seleccionar al menos un día de entrega.",
  }),
  delivery_time_from: z.string().min(1, "La hora de inicio es requerida."),
  delivery_time_to: z.string().min(1, "La hora de fin es requerida."),
  
  email: z.string().email("Debe ser un email válido."),
  instagram: z.string().optional(),
});

type OnboardingFormValues = z.infer<typeof formSchema>;

export function OnboardingForm({ client }: { client: Client }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  const router = useRouter();

  const form = useForm<OnboardingFormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      fiscal_status: client.fiscal_status ?? "",
      cuit: client.cuit ?? "",
      contact_name: client.contact_name ?? "",
      contact_dni: client.contact_dni ?? "",
      province: "",
      locality: "",
      street_address: "",
      street_number: "",
      delivery_days: ["lunes", "miercoles", "viernes"],
      delivery_time_from: "09:00",
      delivery_time_to: "18:00",
      email: client.email ?? "",
      instagram: client.instagram ?? "",
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
    const address = `${values.street_address} ${values.street_number}, ${values.locality}, ${values.province}`;
    const delivery_window = `${values.delivery_days.join(', ')} de ${values.delivery_time_from} a ${values.delivery_time_to}hs`;

    startTransition(async () => {
      const result = await submitOnboardingForm({
        ...values,
        address: address,
        delivery_window: delivery_window,
        onboarding_token: client.onboarding_token,
      });

      if (result.error) {
        toast({
          title: "Error al enviar",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "¡Formulario enviado con éxito!",
          description: "Tus datos fueron guardados. Pronto recibirás tu enlace para pedidos.",
        });
        // Refresh the page to show the "already registered" message
        router.refresh();
      }
    });
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
        <FormField
          control={form.control}
          name="fiscal_status"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Condición Fiscal</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Seleccione su condición frente al IVA..." />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="Responsable Inscripto">Responsable Inscripto (para Factura A)</SelectItem>
                  <SelectItem value="Monotributista">Monotributista (para Factura B)</SelectItem>
                  <SelectItem value="Consumidor Final">Consumidor Final (para Factura B)</SelectItem>
                  <SelectItem value="Exento">Exento (para Factura B)</SelectItem>
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
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
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
                <FormItem><FormLabel>Localidad</FormLabel><Select onValueChange={field.onChange} value={field.value} disabled={!watchedProvince}><FormControl><SelectTrigger><SelectValue placeholder={watchedProvince ? "Seleccione una localidad..." : "Elija una provincia primero"} /></SelectTrigger></FormControl><SelectContent><ScrollArea className="h-72">{availableLocalities.map(l => <SelectItem key={l} value={l}>{l}</SelectItem>)}</ScrollArea></SelectContent></Select><FormMessage /></FormItem>
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
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 pt-2">
                  {deliveryDays.map((item) => (
                    <FormField key={item.id} control={form.control} name="delivery_days" render={({ field }) => (
                      <FormItem key={item.id} className="flex flex-row items-center space-x-3 space-y-0">
                        <FormControl>
                          <Checkbox
                            checked={field.value?.includes(item.id)}
                            onCheckedChange={(checked) => {
                              return checked
                                ? field.onChange([...field.value, item.id])
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

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
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
        <div className="pt-4">
            <Button type="submit" disabled={isPending} className="w-full">
              {isPending ? "Enviando..." : "Enviar Datos"}
            </Button>
        </div>
      </form>
    </Form>
  );
}
