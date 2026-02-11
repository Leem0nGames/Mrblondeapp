
"use client";

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { UpsertClientForm } from "./upsert-client-form";
import { useState } from "react";

// This component has been refactored to be a simple wrapper for the upsert form.
// It's triggered by the CreateClientButton.
export function CreateClientDialog({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);

  const handleSuccess = () => {
    setIsOpen(false);
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-3xl grid-rows-[auto_1fr_auto] p-0 max-h-[90vh]">
        <DialogHeader className="p-6 pb-2">
          <DialogTitle>Crear Nuevo Cliente</DialogTitle>
          <DialogDescription>
            Completa el formulario para registrar un nuevo cliente en el sistema.
          </DialogDescription>
        </DialogHeader>
        <UpsertClientForm 
            onSuccess={handleSuccess} 
            onCancel={() => setIsOpen(false)} 
        />
      </DialogContent>
    </Dialog>
  );
}
