
"use client";

import { useTransition } from "react";
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
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { submitOnboardingForm } from "@/app/actions/user.actions";
import type { Client } from "@/types";
import { useRouter } from "next/navigation";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

// Zod schema for CUIT validation
const cuitSchema = z.string().refine(
  (cuit) => {
    if (!/^\d{11}$/.test(cuit)) return false;
    const [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11] = cuit.split("").map(Number);
    const sum = p1 * 5 + p2 * 4 + p3 * 3 + p4 * 2 + p5 * 7 + p6 * 6 + p7 * 5 + p8 * 4 + p9 * 3 + p10 * 2;
    const rest = sum % 11;
    const digit = rest === 0 ? 0 : rest === 1 ? 9 : 11 - rest;
    return digit === p11;
  },
  { message: "CUIT inválido. Debe tener 11 dígitos sin guiones y ser válido." }
);

const formSchema = z.object({
  fiscal_status: z.string().min(1, "La condición fiscal es requerida"),
  cuit: cuitSchema,
  contact_name: z.string().min(3, "El nombre es requerido."),
  contact_dni: z.string().min(7, "El DNI debe tener entre 7 y 8 dígitos.").max(8, "El DNI debe tener entre 7 y 8 dígitos."),
  address: z.string().min(5, "La dirección es requerida."),
  delivery_window: z.string().min(5, "Este campo es requerido."),
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
      address: client.address ?? "",
      delivery_window: client.delivery_window ?? "",
      email: client.email ?? "",
      instagram: client.instagram ?? "",
    },
  });

  const onSubmit = (values: OnboardingFormValues) => {
    startTransition(async () => {
      const result = await submitOnboardingForm({
        ...values,
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
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
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
        <FormField
          control={form.control}
          name="address"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Dirección de entrega</FormLabel>
              <FormControl>
                <Input placeholder="Calle Falsa 123, Localidad, Provincia" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="delivery_window"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Días y Horarios de entrega</FormLabel>
              <FormControl>
                <Textarea placeholder="Ej: Lunes a Viernes de 9 a 18hs" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
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
        <div className="pt-4">
            <Button type="submit" disabled={isPending} className="w-full">
              {isPending ? "Enviando..." : "Enviar Datos"}
            </Button>
        </div>
      </form>
    </Form>
  );
}
