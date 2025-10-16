
"use client";

import { useState, useTransition, useEffect, useCallback } from "react";
import { z } from "zod";
import { useForm, FormProvider } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation, createFullClient, getAgreements } from "@/app/actions/admin.actions";
import type { Client, Agreement } from "@/types";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Copy, Check } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { EntityDialog, type FormConfig } from "../../_components/entity-dialog";
import { agreementFormConfig } from "../../agreements/_components/form-config";


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
  fiscal_status: z.string().min(1, "La condición fiscal es requerida"),
  cuit: cuitSchema,
  contact_name: z.string().min(3, "El nombre es requerido."),
  contact_dni: z.string().min(7, "El DNI debe tener entre 7 y 8 dígitos.").max(8, "El DNI debe tener entre 7 y 8 dígitos."),
  address: z.string().min(5, "La dirección es requerida."),
  delivery_window: z.string().min(5, "Este campo es requerido."),
  email: z.string().email("Debe ser un email válido."),
  instagram: z.string().optional(),
  agreement_id: z.string().nullable(),
});

type OnboardingFormValues = z.infer<typeof formSchema>;

export function CreateClientDialog({ children, open, onOpenChange }: { children: React.ReactNode, open: boolean, onOpenChange: (open: boolean) => void }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  const [agreements, setAgreements] = useState<Agreement[]>([]);
  const [invitationLink, setInvitationLink] = useState<string | null>(null);
  const [hasCopied, setHasCopied] = useState(false);

  const fetchAgreements = useCallback(async () => {
    const { data } = await getAgreements();
    setAgreements(data ?? []);
  }, []);

   useEffect(() => {
    if (open) {
        fetchAgreements();
    }
  }, [open, fetchAgreements]);

  const form = useForm<OnboardingFormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      fiscal_status: "",
      cuit: "",
      contact_name: "",
      contact_dni: "",
      address: "",
      delivery_window: "",
      email: "",
      instagram: "",
      agreement_id: null,
    },
  });

  const onSubmit = (values: OnboardingFormValues) => {
    startTransition(async () => {
      const result = await createFullClient(values);

      if (result.error) {
        toast({
          title: "Error al crear cliente",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "¡Cliente Creado!",
          description: "El nuevo cliente ha sido agregado y está listo para usarse.",
        });
        onOpenChange(false);
        form.reset();
      }
    });
  };

  const handleInvite = () => {
      startTransition(async () => {
          const result = await createClientForInvitation();
          if (result.error) {
              toast({ title: "Error", description: result.error.message, variant: "destructive" });
          } else {
              const link = `${window.location.origin}/onboarding/${result.data?.onboarding_token}`;
              setInvitationLink(link);
              toast({ title: "Invitación Creada", description: "Copia el enlace y compártelo con tu cliente." });
          }
      });
  };

  const handleCopyToClipboard = () => {
    if (!invitationLink) return;
    navigator.clipboard.writeText(invitationLink);
    setHasCopied(true);
    setTimeout(() => setHasCopied(false), 2000);
  };

  const handleDialogChange = (isOpen: boolean) => {
      onOpenChange(isOpen);
      if (!isOpen) {
          form.reset();
          setInvitationLink(null);
      }
  }
  
  const handleNewAgreementSuccess = useCallback(async (newAgreement: Agreement) => {
      await fetchAgreements();
      form.setValue('agreement_id', newAgreement.id, { shouldValidate: true });
  }, [fetchAgreements, form]);

  const upsertActionWithCallback = useCallback(async (payload: any) => {
    const result = await agreementFormConfig.upsertAction(payload);
    if (!result.error && result.data) {
        await handleNewAgreementSuccess(result.data);
    }
    return result;
  }, [handleNewAgreementSuccess]);

  const newAgreementDialogConfig: FormConfig<any> = {
      ...agreementFormConfig,
      upsertAction: upsertActionWithCallback,
  };


  return (
    <Dialog open={open} onOpenChange={handleDialogChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-xl grid-rows-[auto_1fr_auto] p-0 max-h-[90vh]">
        <DialogHeader className="p-6 pb-4">
          <DialogTitle>Agregar Nuevo Cliente</DialogTitle>
          <DialogDescription>
            Elige cómo quieres agregar un nuevo cliente al sistema.
          </DialogDescription>
        </DialogHeader>
        
        <Tabs defaultValue="fast-track" className="w-full">
            <TabsList className="grid w-full grid-cols-2 mx-auto px-6">
                <TabsTrigger value="fast-track">Alta Rápida</TabsTrigger>
                <TabsTrigger value="invite">Invitar Cliente</TabsTrigger>
            </TabsList>
            
            <TabsContent value="fast-track">
                <ScrollArea className="h-[60vh] w-full">
                    <FormProvider {...form}>
                        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6 px-6 pb-6">
                            <p className="text-sm text-muted-foreground pt-4">Completa los datos del cliente para darle de alta inmediatamente.</p>
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
                                <FormField control={form.control} name="cuit" render={({ field }) => (
                                    <FormItem><FormLabel>CUIT</FormLabel><FormControl><Input placeholder="11 dígitos, sin guiones" {...field} /></FormControl><FormMessage /></FormItem>
                                )}/>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <FormField control={form.control} name="contact_name" render={({ field }) => (
                                        <FormItem><FormLabel>Nombre y Apellido</FormLabel><FormControl><Input {...field} /></FormControl><FormMessage /></FormItem>
                                    )}/>
                                    <FormField control={form.control} name="contact_dni" render={({ field }) => (
                                        <FormItem><FormLabel>DNI</FormLabel><FormControl><Input placeholder="Sin puntos" {...field} /></FormControl><FormMessage /></FormItem>
                                    )}/>
                                </div>
                                <FormField control={form.control} name="address" render={({ field }) => (
                                    <FormItem><FormLabel>Dirección de entrega</FormLabel><FormControl><Input placeholder="Calle Falsa 123, Localidad, Provincia" {...field} /></FormControl><FormMessage /></FormItem>
                                )}/>
                                <FormField control={form.control} name="delivery_window" render={({ field }) => (
                                    <FormItem><FormLabel>Días y Horarios de entrega</FormLabel><FormControl><Textarea placeholder="Ej: Lunes a Viernes de 9 a 18hs" {...field} /></FormControl><FormMessage /></FormItem>
                                )}/>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <FormField control={form.control} name="email" render={({ field }) => (
                                        <FormItem><FormLabel>Mail</FormLabel><FormControl><Input type="email" placeholder="tu@email.com" {...field} /></FormControl><FormMessage /></FormItem>
                                    )}/>
                                    <FormField control={form.control} name="instagram" render={({ field }) => (
                                        <FormItem><FormLabel>Instagram (Opcional)</FormLabel><FormControl><Input placeholder="@usuario" {...field} /></FormControl><FormMessage /></FormItem>
                                    )}/>
                                </div>
                                <FormField
                                    control={form.control}
                                    name="agreement_id"
                                    render={({ field }) => (
                                        <FormItem>
                                        <FormLabel>Convenio (Opcional)</FormLabel>
                                        <Select onValueChange={(value) => field.onChange(value === 'null' ? null : value)} value={field.value ?? 'null'}>
                                            <FormControl><SelectTrigger><SelectValue placeholder="Asignar un convenio..." /></SelectTrigger></FormControl>
                                            <SelectContent>
                                                <SelectItem value="null">Ninguno por ahora</SelectItem>
                                                {agreements.map(agreement => (<SelectItem key={agreement.id} value={agreement.id}>{agreement.agreement_name}</SelectItem>))}
                                            </SelectContent>
                                        </Select>
                                        <FormDescription>
                                            <span>¿El convenio que buscas no existe?</span>
                                            <EntityDialog formConfig={newAgreementDialogConfig} entity={undefined}>
                                                <Button variant="link" size="sm" type="button" className="p-1 h-auto text-xs">
                                                    o, Crear Nuevo Convenio
                                                </Button>
                                            </EntityDialog>
                                        </FormDescription>
                                        <FormMessage />
                                        </FormItem>
                                    )}
                                />
                                <DialogFooter className="pt-4 !mt-0 bg-background sticky bottom-0 pb-6">
                                    <Button type="submit" disabled={isPending} className="w-full">
                                        {isPending ? "Guardando..." : "Crear Cliente"}
                                    </Button>
                                </DialogFooter>
                        </form>
                    </FormProvider>
                </ScrollArea>
            </TabsContent>

            <TabsContent value="invite">
                <div className="px-6 py-4 space-y-6">
                    <p className="text-sm text-muted-foreground">Genera un enlace único para que el cliente complete sus datos. El cliente aparecerá en tu lista como "Pendiente de Alta".</p>
                    {invitationLink ? (
                        <Alert>
                            <AlertTitle>¡Enlace Generado!</AlertTitle>
                            <AlertDescription className="break-all">
                                {invitationLink}
                            </AlertDescription>
                            <div className="mt-4">
                                <Button size="sm" onClick={handleCopyToClipboard}>
                                    {hasCopied ? <Check className="mr-2 h-4 w-4" /> : <Copy className="mr-2 h-4 w-4" />}
                                    {hasCopied ? "Copiado" : "Copiar Enlace"}
                                </Button>
                            </div>
                        </Alert>
                    ) : (
                         <Button onClick={handleInvite} disabled={isPending} className="w-full">
                            {isPending ? "Generando..." : "Generar Enlace de Invitación"}
                        </Button>
                    )}
                </div>
            </TabsContent>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}
