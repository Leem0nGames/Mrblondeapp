

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
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation, createFullClient, getAgreements } from "@/app/actions/admin.actions";
import type { Agreement } from "@/types";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Copy, Check } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { EntityDialog, type FormConfig } from "../../_components/entity-dialog";
import { agreementFormConfig } from "../../agreements/_components/form-config";
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
        // This case is invalid and doesn't have a correct digit.
        // It's very rare. We will just return false.
        return false;
    }
    
    // If it matches, return true. Otherwise, return the correct digit.
    return digitoVerificador === digitoCalculado ? true : digitoCalculado;
};


const cuitSchema = z.string().superRefine((cuit, ctx) => {
    const validationResult = validateCuit(cuit);
    if (validationResult === true) {
        return; // It's valid
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
  fiscal_status: z.string().min(1, "La condición fiscal es requerida"),
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
  agreement_id: z.string().nullable(),
});

type OnboardingFormValues = z.infer<typeof formSchema>;

export function CreateClientDialog({ children, open, onOpenChange }: { children: React.ReactNode, open: boolean, onOpenChange: (open: boolean) => void }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  const [agreements, setAgreements] = useState<Agreement[]>([]);
  const [invitationLink, setInvitationLink] = useState<string | null>(null);
  const [hasCopied, setHasCopied] = useState(false);
  const [activeTab, setActiveTab] = useState("fast-track");

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
      province: "",
      locality: "",
      street_address: "",
      street_number: "",
      delivery_days: ["lunes", "miercoles", "viernes"],
      delivery_time_from: "09:00",
      delivery_time_to: "18:00",
      email: "",
      instagram: "",
      agreement_id: null,
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
      const result = await createFullClient({
        ...values,
        address,
        delivery_window
      });

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
          setActiveTab("fast-track");
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
      <DialogContent className="sm:max-w-2xl grid-rows-[auto_1fr_auto] p-0 max-h-[90vh]">
        <DialogHeader className="p-6 pb-2">
          <DialogTitle>Agregar Nuevo Cliente</DialogTitle>
          <DialogDescription>
            Elige cómo quieres agregar un nuevo cliente al sistema.
          </DialogDescription>
        </DialogHeader>
        
        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
            <div className="px-6">
                <TabsList className="grid w-full grid-cols-2">
                    <TabsTrigger value="fast-track">Alta Rápida</TabsTrigger>
                    <TabsTrigger value="invite">Invitar Cliente</TabsTrigger>
                </TabsList>
            </div>
            
            <TabsContent value="fast-track" className="mt-0">
                <FormProvider {...form}>
                    <form onSubmit={form.handleSubmit(onSubmit)}>
                        <ScrollArea className="h-[55vh] w-full">
                            <div className="space-y-6 px-6 pb-6 pt-4">
                                <p className="text-sm text-muted-foreground">Completa los datos del cliente para darle de alta inmediatamente.</p>
                                <FormField
                                    control={form.control}
                                    name="fiscal_status"
                                    render={({ field }) => (
                                        <FormItem>
                                        <FormLabel>Condición Fiscal</FormLabel>
                                        <Select onValueChange={field.onChange} defaultValue={field.value}>
                                            <FormControl><SelectTrigger><SelectValue placeholder="Seleccione una condición..." /></SelectTrigger></FormControl>
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
                                            <FormDescription className="flex items-center gap-1">
                                                <span>¿El convenio que buscas no existe?</span>
                                                <EntityDialog formConfig={newAgreementDialogConfig} entity={undefined}>
                                                    <Button variant="link" size="sm" type="button" className="p-0 h-auto text-xs">
                                                        Crear uno nuevo.
                                                    </Button>
                                                </EntityDialog>
                                            </FormDescription>
                                            <FormMessage />
                                            </FormItem>
                                        )}
                                    />
                                </div>
                        </ScrollArea>
                        <DialogFooter className="p-6 pt-2 border-t">
                            <Button type="submit" disabled={isPending} className="w-full sm:w-auto">
                                {isPending ? "Guardando..." : "Crear Cliente"}
                            </Button>
                        </DialogFooter>
                    </form>
                </FormProvider>
            </TabsContent>

            <TabsContent value="invite" className="mt-0">
                <div className="h-[55vh] flex flex-col">
                    <div className="p-6 space-y-6 flex-grow">
                        <p className="text-sm text-muted-foreground">Genera un enlace único para que el cliente complete sus datos. El cliente aparecerá en tu lista como "Pendiente de Alta".</p>
                        {invitationLink && (
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
                        )}
                    </div>
                     <DialogFooter className="p-6 pt-2 border-t">
                         <Button onClick={handleInvite} disabled={isPending} className="w-full sm:w-auto" variant={invitationLink ? "secondary" : "default"}>
                            {isPending ? "Generando..." : invitationLink ? "Generar Otro Enlace" : "Generar Enlace de Invitación"}
                        </Button>
                    </DialogFooter>
                </div>
            </TabsContent>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}
