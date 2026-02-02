"use client";

import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { UpsertClientForm } from "./upsert-client-form";
import type { Client } from "@/types";
import { cn } from "@/lib/utils";

export function UpsertClientDialog({
  children,
  client,
}: {
  children: React.ReactNode;
  client?: Partial<Client>;
}) {
  const [isOpen, setIsOpen] = useState(false);

  const handleSuccess = () => {
    setIsOpen(false);
  };

  const isEditMode = !!client?.id;
  const dialogTitle = isEditMode ? `Editar Cliente` : "Crear Nuevo Cliente";
  const dialogDescription = isEditMode
    ? `Actualiza los detalles de ${client.contact_name}.`
    : "Completa el formulario para registrar un nuevo cliente en el sistema.";

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-3xl grid-rows-[auto_1fr_auto] p-0 max-h-[90vh]">
        <DialogHeader className="p-6 pb-2">
          <DialogTitle>{dialogTitle}</DialogTitle>
          <DialogDescription>{dialogDescription}</DialogDescription>
        </DialogHeader>
        <UpsertClientForm 
            client={client} 
            onSuccess={handleSuccess} 
            onCancel={() => setIsOpen(false)} 
        />
      </DialogContent>
    </Dialog>
  );
}
