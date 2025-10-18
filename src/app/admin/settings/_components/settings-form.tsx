
"use client";

import { useTransition } from 'react';
import { useForm, FormProvider } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from 'zod';
import { Form, FormControl, FormField, FormItem, FormLabel, FormDescription, FormMessage } from '@/components/ui/form';
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { useToast } from '@/hooks/use-toast';
import { updateSettings } from '@/app/admin/actions/settings.actions';
import type { AppSettings } from '@/types';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import Image from 'next/image';

const settingsSchema = z.object({
    whatsapp_number: z.string().min(10, "Debe ser un número válido."),
    vat_percentage: z.coerce.number().min(0, "Debe ser un número positivo."),
    logo_image: z.any().optional(),
});

type SettingsFormValues = z.infer<typeof settingsSchema>;

export function SettingsForm({ settings }: { settings: AppSettings }) {
    const [isPending, startTransition] = useTransition();
    const { toast } = useToast();

    const form = useForm<SettingsFormValues>({
        resolver: zodResolver(settingsSchema),
        defaultValues: {
            whatsapp_number: settings.whatsapp_number || "",
            vat_percentage: settings.vat_percentage || 21,
            logo_image: undefined,
        },
    });

    const onSubmit = (values: SettingsFormValues) => {
        startTransition(async () => {
            const formData = new FormData();
            formData.append('whatsapp_number', values.whatsapp_number);
            formData.append('vat_percentage', String(values.vat_percentage));
            if (values.logo_image?.[0]) {
                formData.append('logo_image', values.logo_image[0]);
            }
            
            const result = await updateSettings(formData);

            if (result.error) {
                toast({ title: "Error", description: result.error, variant: "destructive" });
            } else {
                toast({ title: "Éxito", description: "Configuración guardada correctamente." });
                form.reset({ ...values, logo_image: undefined });
            }
        });
    };

    return (
        <FormProvider {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
                <Card>
                    <CardHeader>
                    <CardTitle>Ajustes Generales</CardTitle>
                    <CardDescription>
                        Configura variables importantes para el funcionamiento de la app.
                    </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-6">
                        <FormField
                            control={form.control}
                            name="whatsapp_number"
                            render={({ field }) => (
                                <FormItem>
                                    <FormLabel>Número de WhatsApp</FormLabel>
                                    <FormControl>
                                        <Input placeholder="e.g., 5491123456789" {...field} />
                                    </FormControl>
                                    <FormDescription>
                                        Este es el número al que se enviarán los resúmenes de pedido.
                                    </FormDescription>
                                    <FormMessage />
                                </FormItem>
                            )}
                        />
                        <FormField
                            control={form.control}
                            name="vat_percentage"
                            render={({ field }) => (
                                <FormItem>
                                    <FormLabel>Porcentaje de IVA (%)</FormLabel>
                                    <FormControl>
                                        <Input type="number" placeholder="21" {...field} />
                                    </FormControl>
                                    <FormDescription>
                                        Este porcentaje se usará para calcular el total de los pedidos.
                                    </FormDescription>
                                    <FormMessage />
                                </FormItem>
                            )}
                        />
                    </CardContent>
                </Card>
                
                <Card>
                    <CardHeader>
                        <CardTitle>Personalización</CardTitle>
                        <CardDescription>
                            Cambia el logo de la aplicación.
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-6">
                         {settings.logo_url && (
                             <div className="space-y-2">
                                <Label>Logo Actual</Label>
                                <div className="relative w-24 h-24 bg-muted rounded-md flex items-center justify-center">
                                    <Image
                                        src={settings.logo_url}
                                        alt="Logo actual"
                                        fill
                                        className="object-contain p-2"
                                    />
                                </div>
                            </div>
                         )}

                         <FormField
                            control-={form.control}
                            name="logo_image"
                            render={({ field }) => (
                                <FormItem>
                                    <FormLabel>Subir Nuevo Logo</FormLabel>
                                    <FormControl>
                                        <Input 
                                            type="file"
                                            accept="image/png, image/jpeg, image/svg+xml, image/webp"
                                            {...form.register("logo_image")}
                                        />
                                    </FormControl>
                                    <FormDescription>
                                        Sube una nueva imagen para reemplazar el logo actual. Se recomienda formato cuadrado.
                                    </FormDescription>
                                    <FormMessage />
                                </FormItem>
                            )}
                        />
                    </CardContent>
                </Card>

                <div>
                    <Button type="submit" disabled={isPending}>
                        {isPending ? "Guardando..." : "Guardar Cambios"}
                    </Button>
                </div>
            </form>
        </FormProvider>
    );
}
