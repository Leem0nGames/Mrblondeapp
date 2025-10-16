
"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { PlusCircle } from "lucide-react";
import { CreateClientDialog } from "./create-client-dialog";

export function CreateClientButton() {
    const [isDialogOpen, setIsDialogOpen] = useState(false);

    return (
        <CreateClientDialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
            <Button size="sm" className="h-8 gap-1">
                <PlusCircle className="h-3.5 w-3.5" />
                <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                    Agregar Cliente
                </span>
            </Button>
        </CreateClientDialog>
    );
}
