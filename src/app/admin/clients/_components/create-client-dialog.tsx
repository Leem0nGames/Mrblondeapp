
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
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";
import { Copy, Check, Loader2, UserPlus, Link2 } from "lucide-react";
import { UpsertClientDialog } from "./upsert-client-dialog";

export function CreateClientDialog({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const [view, setView] = useState<"options" | "link">("options");
  const [generatedLink, setGeneratedLink] = useState("");
  const [hasCopied, setHasCopied] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleGenerateLink = () => {
    startTransition(async () => {
      const result = await createClientForInvitation();
      if (result.error || !result.data) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        const origin = window.location.origin;
        setGeneratedLink(`${origin}/onboarding/${result.data.onboarding_token}`);
        setView("link");
      }
    });
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(generatedLink);
    setHasCopied(true);
    setTimeout(() => setHasCopied(false), 2000);
    toast({ title: "Enlace de invitación copiado!" });
  };

  const handleOpenChange = (open: boolean) => {
    setIsOpen(open);
    if (!open) {
      // Reset state when closing
      setTimeout(() => {
        setView("options");
        setGeneratedLink("");
        setHasCopied(false);
      }, 300);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Agregar Nuevo Cliente</DialogTitle>
          <DialogDescription>
            Elige cómo deseas agregar un nuevo cliente al sistema.
          </DialogDescription>
        </DialogHeader>

        {view === "options" && (
          <div className="grid grid-cols-1 gap-4 py-4">
            <UpsertClientDialog client={undefined}>
              <Button
                variant="outline"
                className="h-20 flex flex-col gap-1"
                onClick={() => setIsOpen(false)} // Close this dialog to open the other
              >
                <UserPlus className="h-6 w-6" />
                <span>Crear Manualmente</span>
                <span className="text-xs text-muted-foreground">
                  (Tú cargas todos los datos)
                </span>
              </Button>
            </UpsertClientDialog>

            <Button
              variant="outline"
              className="h-20 flex flex-col gap-1"
              onClick={handleGenerateLink}
              disabled={isPending}
            >
              {isPending ? (
                <Loader2 className="h-6 w-6 animate-spin" />
              ) : (
                <Link2 className="h-6 w-6" />
              )}
              <span>Generar Enlace de Invitación</span>
              <span className="text-xs text-muted-foreground">
                (El cliente carga sus datos)
              </span>
            </Button>
          </div>
        )}

        {view === "link" && (
          <div className="space-y-4 py-4">
            <p className="text-sm text-muted-foreground">
              Comparte este enlace con tu cliente para que complete su
              formulario de alta.
            </p>
            <div className="flex items-center space-x-2">
              <input
                value={generatedLink}
                readOnly
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background"
              />
              <Button
                size="icon"
                className="h-10 w-10"
                onClick={copyToClipboard}
              >
                {hasCopied ? (
                  <Check className="h-4 w-4" />
                ) : (
                  <Copy className="h-4 w-4" />
                )}
              </Button>
            </div>
            <DialogFooter className="!mt-6">
                <Button variant="secondary" onClick={() => setView('options')}>Volver</Button>
                <Button onClick={() => handleOpenChange(false)}>Finalizar</Button>
            </DialogFooter>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
