
"use client";

import { useState, useTransition, useCallback } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { UpsertClientForm } from "./upsert-client-form";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Copy, Check, Link as LinkIcon, UserPlus, Loader2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";

type View = "options" | "manual" | "link";

export function CreateClientDialog({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const [view, setView] = useState<View>("options");
  const [generatedLink, setGeneratedLink] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleOpenChange = (open: boolean) => {
    setIsOpen(open);
    if (!open) {
      // Reset state when closing
      setTimeout(() => {
        setView("options");
        setGeneratedLink(null);
      }, 300);
    }
  };

  const handleGenerateLink = () => {
    startTransition(async () => {
      const result = await createClientForInvitation();
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        const origin = window.location.origin;
        setGeneratedLink(`${origin}/onboarding/${result.data.onboarding_token}`);
        setView("link");
      }
    });
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    toast({ title: "Enlace copiado al portapapeles" });
  };
  
  const handleSuccessManual = () => {
      handleOpenChange(false);
  }

  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-xl">
        {view === "options" && (
          <>
            <DialogHeader>
              <DialogTitle>Agregar un Nuevo Cliente</DialogTitle>
              <DialogDescription>
                Elige cómo quieres agregar al cliente. Puedes enviarle un enlace para que complete sus datos o cargarlos tú mismo.
              </DialogDescription>
            </DialogHeader>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 py-4">
              <Button variant="outline" className="h-24 flex-col gap-2" onClick={() => setView("manual")}>
                <UserPlus className="h-6 w-6" />
                <span>Cargar Manualmente</span>
              </Button>
              <Button variant="outline" className="h-24 flex-col gap-2" onClick={handleGenerateLink} disabled={isPending}>
                {isPending ? <Loader2 className="h-6 w-6 animate-spin" /> : <LinkIcon className="h-6 w-6" />}
                <span>Generar Link de Invitación</span>
              </Button>
            </div>
          </>
        )}
        
        {view === "manual" && (
             <>
                <DialogHeader>
                    <DialogTitle>Crear Nuevo Cliente Manualmente</DialogTitle>
                    <DialogDescription>
                        Completa el formulario para registrar un nuevo cliente en el sistema.
                    </DialogDescription>
                </DialogHeader>
                <div className="max-h-[60vh] overflow-y-auto pr-2">
                    <UpsertClientForm onSuccess={handleSuccessManual} onCancel={() => setView("options")} />
                </div>
            </>
        )}

        {view === "link" && (
          <>
            <DialogHeader>
              <DialogTitle>Enlace de Invitación Generado</DialogTitle>
              <DialogDescription>
                Copia este enlace y envíaselo a tu cliente para que complete su alta.
              </DialogDescription>
            </DialogHeader>
            <div className="flex items-center space-x-2 py-4">
              <Input id="link" value={generatedLink ?? ""} readOnly />
              <Button type="button" size="icon" onClick={() => copyToClipboard(generatedLink!)}>
                <Copy className="h-4 w-4" />
              </Button>
            </div>
            <Button variant="outline" onClick={() => handleOpenChange(false)}>
              Cerrar
            </Button>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
