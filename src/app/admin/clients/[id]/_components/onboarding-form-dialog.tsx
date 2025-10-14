
"use client";

import { useState, useTransition } from "react";
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
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { submitOnboardingForm } from "@/app/actions/user.actions";
import type { Client } from "@/types";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ActionButton } from "./client-action-buttons";
import { Edit } from "lucide-react";

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

const formSchema = z.object({
  cuit: cuitSchema,
  contact_name: z.string().min(3, "El nombre es requerido."),
  contact_dni: z.string().min(7, "El DNI debe tener entre 7 y 8 dígitos.").max(8, "El DNI debe tener entre 7 y 8 dígitos."),
  address: z.string().min(5, "La dirección es requerida."),
  delivery_window: z.string().min(5, "Este campo es requerido."),
  email: z.string().email("Debe ser un email válido."),
  instagram: z.string().optional(),
  fiscal_status: z.string().min(1, "La condición fiscal es requerida"),
});

type OnboardingFormValues = z.infer<typeof formSchema>;

export function OnboardingFormDialog({ children, client }: { children: React.ReactNode, client: Client }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const form = useForm<OnboardingFormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      cuit: client.cuit ?? "",
      contact_name: client.contact_name ?? "",
      contact_dni: client.contact_dni ?? "",
      address: client.address ?? "",
      delivery_window: client.delivery_window ?? "",
      email: client.email ?? "",
      instagram: client.instagram ?? "",
      fiscal_status: client.fiscal_status ?? "",
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
      <DialogContent className="sm:max-w-lg grid-rows-[auto_1fr_auto] p-0 max-h-[90vh]">
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
