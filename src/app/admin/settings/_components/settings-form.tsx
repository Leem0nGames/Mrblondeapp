"use client";

import { useState, useTransition } from 'react';
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { useToast } from '@/hooks/use-toast';
import { updateSettings } from '@/app/admin/actions/settings.actions';
import type { AppSettings } from '@/types';

export function SettingsForm({ settings }: { settings: AppSettings }) {
    const [isPending, startTransition] = useTransition();
    const { toast } = useToast();

    const [whatsappNumber, setWhatsappNumber] = useState(settings.whatsapp_number || "");
    const [vatPercentage, setVatPercentage] = useState(settings.vat_percentage || 21);

    const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        startTransition(async () => {
            const result = await updateSettings({ 
                whatsapp_number: whatsappNumber,
                vat_percentage: vatPercentage,
            });

            if (result.error) {
                toast({ title: "Error", description: result.error, variant: "destructive" });
            } else {
                toast({ title: "Éxito", description: "Configuración guardada correctamente." });
            }
        });
    };

    return (
        <form className="space-y-6 max-w-lg" onSubmit={handleSubmit}>
            <div className="space-y-2">
                <Label htmlFor="whatsapp">Número de WhatsApp</Label>
                <Input 
                    id="whatsapp"
                    placeholder="e.g., 5491123456789"
                    value={whatsappNumber}
                    onChange={(e) => setWhatsappNumber(e.target.value)}
                />
                <p className="text-xs text-muted-foreground">
                    Este es el número al que se enviarán los resúmenes de pedido.
                </p>
            </div>
             <div className="space-y-2">
                <Label htmlFor="vat">Porcentaje de IVA (%)</Label>
                <Input 
                    id="vat"
                    type="number"
                    placeholder="21"
                    value={vatPercentage}
                    onChange={(e) => setVatPercentage(Number(e.target.value))}
                />
                <p className="text-xs text-muted-foreground">
                    Este porcentaje se usará para calcular el total de los pedidos.
                </p>
            </div>
            <Button type="submit" disabled={isPending}>
                {isPending ? "Guardando..." : "Guardar Cambios"}
            </Button>
        </form>
    );
}
