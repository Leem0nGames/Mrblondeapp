
"use client";

import { useTransition } from "react";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { createPlaceholderClient } from "@/app/actions/admin.actions";
import { PlusCircle } from "lucide-react";

export function CreateClientButton() {
    const [isPending, startTransition] = useTransition();
    const { toast } = useToast();

    const handleClick = () => {
        startTransition(async () => {
            const result = await createPlaceholderClient();
            if (result.error) {
                toast({
                    title: "Error al crear cliente",
                    description: result.error.message,
                    variant: "destructive",
                });
            } else {
                toast({
                    title: "Cliente placeholder creado",
                    description: "El nuevo cliente aparece en la lista, listo para que compartas su enlace de alta.",
                });
            }
        });
    };

    return (
        <Button size="sm" className="h-8 gap-1" onClick={handleClick} disabled={isPending}>
            <PlusCircle className="h-3.5 w-3.5" />
            <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                {isPending ? "Creando Cliente..." : "Crear Cliente"}
            </span>
        </Button>
    );
}

    