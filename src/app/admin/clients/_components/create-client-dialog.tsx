"use client";

import { useState, useTransition } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Copy, Link as LinkIcon, UserPlus, Loader2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";
import { UpsertClientDialog } from "./upsert-client-dialog";

export function CreateClientDialog({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const [generatedLink, setGeneratedLink] = useState<string | null>(null);
  const [showLinkView, setShowLinkView] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleOpenChange = (open: boolean) => {
    setIsOpen(open);
    if (!open) {
      // Reset state when closing
      setTimeout(() => {
        setGeneratedLink(null);
        setShowLinkView(false);
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
        setShowLinkView(true);
      }
    });
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    toast({ title: "Enlace copiado al portapapeles" });
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        {!showLinkView ? (
          <>
            <DialogHeader>
              <DialogTitle>Agregar un Nuevo Cliente</DialogTitle>
              <DialogDescription>
                Elige un método. Puedes cargar los datos tú mismo o enviar un enlace al cliente.
              </DialogDescription>
            </DialogHeader>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 py-4">
              <UpsertClientDialog client={undefined}>
                <Button variant="outline" className="h-24 flex-col gap-2">
                  <UserPlus className="h-6 w-6" />
                  <span>Cargar Manualmente</span>
                </Button>
              </UpsertClientDialog>
              <Button variant="outline" className="h-24 flex-col gap-2" onClick={handleGenerateLink} disabled={isPending}>
                {isPending ? <Loader2 className="h-6 w-6 animate-spin" /> : <LinkIcon className="h-6 w-6" />}
                <span>Generar Link de Invitación</span>
              </Button>
            </div>
          </>
        ) : (
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
            <DialogFooter className="gap-2 sm:justify-between">
                <Button variant="outline" onClick={() => setShowLinkView(false)}>
                    Volver
                </Button>
                 <Button onClick={() => handleOpenChange(false)}>
                    Cerrar
                </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}