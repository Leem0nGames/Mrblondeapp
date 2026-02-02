"use client";

import React, { useState, useTransition, useCallback } from "react";
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
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";
import { UserPlus, Link as LinkIcon, Check, Copy, ArrowLeft } from "lucide-react";
import { UpsertClientForm } from "./upsert-client-form";
import { cn } from "@/lib/utils";

type View = "choice" | "invite" | "manual";

export function CreateClientDialog({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const [view, setView] = useState<View>("choice");
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  
  const [email, setEmail] = useState("");
  const [generatedLink, setGeneratedLink] = useState("");
  const [hasCopied, setHasCopied] = useState(false);

  const handleGenerateLink = () => {
    if (!email) {
      toast({ title: "Email requerido", description: "Por favor, ingresa un email.", variant: "destructive" });
      return;
    }
    startTransition(async () => {
      const result = await createClientForInvitation(email);
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else if (result.data?.onboarding_token) {
        const link = `${window.location.origin}/onboarding/${result.data.onboarding_token}`;
        setGeneratedLink(link);
        toast({ title: "¡Enlace generado!", description: "Copia el enlace y envíalo a tu cliente." });
      }
    });
  };

  const copyToClipboard = useCallback(() => {
    if (!generatedLink) return;
    navigator.clipboard.writeText(generatedLink);
    setHasCopied(true);
    setTimeout(() => setHasCopied(false), 2000);
  }, [generatedLink]);

  const resetState = () => {
    setView("choice");
    setEmail("");
    setGeneratedLink("");
    setHasCopied(false);
  };

  const handleOpenChange = (open: boolean) => {
    setIsOpen(open);
    if (!open) {
      setTimeout(resetState, 300);
    }
  };

  const handleSuccess = () => {
    setIsOpen(false);
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className={cn(
          "sm:max-w-md",
          view === 'manual' && "sm:max-w-3xl grid-rows-[auto_1fr_auto] p-0 max-h-[90vh]"
      )}>
        {view === "choice" && (
          <>
            <DialogHeader>
              <DialogTitle>Agregar Nuevo Cliente</DialogTitle>
              <DialogDescription>
                Elige cómo quieres registrar a tu nuevo cliente.
              </DialogDescription>
            </DialogHeader>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 py-4">
              <Button variant="outline" className="h-24 flex-col gap-2" onClick={() => setView("manual")}>
                <UserPlus className="h-6 w-6" />
                <span>Crear Manualmente</span>
              </Button>
              <Button variant="outline" className="h-24 flex-col gap-2" onClick={() => setView("invite")}>
                <LinkIcon className="h-6 w-6" />
                <span>Generar Link de Alta</span>
              </Button>
            </div>
          </>
        )}

        {view === "invite" && (
          <>
            <DialogHeader>
              <DialogTitle>Generar Enlace de Alta</DialogTitle>
              <DialogDescription>
                Ingresa el email del cliente. Se creará un enlace único para que complete sus datos.
              </DialogDescription>
            </DialogHeader>
            <div className="py-4 space-y-4">
              {!generatedLink ? (
                <div className="space-y-2">
                  <Label htmlFor="email">Email del Cliente</Label>
                  <Input
                    id="email"
                    type="email"
                    placeholder="cliente@ejemplo.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    disabled={isPending}
                  />
                </div>
              ) : (
                <div className="space-y-2">
                   <Label>Enlace de Alta Generado</Label>
                   <div className="flex items-center gap-2">
                     <Input value={generatedLink} readOnly className="bg-muted"/>
                     <Button size="icon" onClick={copyToClipboard}>
                        {hasCopied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                     </Button>
                   </div>
                   <p className="text-sm text-muted-foreground">Envía este enlace a tu cliente para que se registre.</p>
                </div>
              )}
            </div>
            <DialogFooter>
              <Button variant="ghost" onClick={resetState}>
                <ArrowLeft className="h-4 w-4 mr-2" />
                Volver
              </Button>
              {!generatedLink ? (
                <Button onClick={handleGenerateLink} disabled={isPending || !email}>
                    {isPending ? "Generando..." : "Generar Enlace"}
                </Button>
              ) : (
                <DialogClose asChild><Button onClick={resetState}>Hecho</Button></DialogClose>
              )}
            </DialogFooter>
          </>
        )}
        
        {view === "manual" && (
           <>
             <DialogHeader className="p-6 pb-2">
                <DialogTitle>Crear Nuevo Cliente</DialogTitle>
                <DialogDescription>
                  Completa el formulario para registrar un nuevo cliente en el sistema.
                </DialogDescription>
            </DialogHeader>
            <UpsertClientForm onSuccess={handleSuccess} onCancel={() => setView('choice')} />
           </>
        )}

      </DialogContent>
    </Dialog>
  );
}
