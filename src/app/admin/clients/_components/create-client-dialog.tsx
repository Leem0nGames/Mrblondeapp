
"use client";

import { useState, useTransition, useCallback } from "react";
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
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";
import { Copy, Check } from "lucide-react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { AssignAgreementDialog } from "./assign-agreement-dialog";
import type { Client } from "@/types";

const formSchema = z.object({
  // No fields needed for this simple version
});

export function CreateClientDialog({
  children,
}: {
  children: React.ReactNode;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  const [newClient, setNewClient] = useState<Pick<
    Client,
    "id" | "onboarding_token" | "agreement_id"
  > | null>(null);
  const [hasCopied, setHasCopied] = useState(false);

  const form = useForm();

  const generateLink = () => {
    startTransition(async () => {
      const result = await createClientForInvitation(null);
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        setNewClient(result.data);
        toast({
          title: "¡Enlace Generado!",
          description:
            "Copia el enlace para enviárselo al cliente para que complete sus datos.",
        });
      }
    });
  };

  const copyToClipboard = useCallback(() => {
    if (!newClient || typeof window === "undefined") return;
    const link = `${window.location.origin}/onboarding/${newClient.onboarding_token}`;
    navigator.clipboard.writeText(link);
    setHasCopied(true);
    setTimeout(() => setHasCopied(false), 2000);
  }, [newClient]);

  const handleOpenChange = (open: boolean) => {
    if (!open) {
      // Reset state when closing
      setNewClient(null);
      setHasCopied(false);
    }
    setIsOpen(open);
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Crear Nuevo Cliente</DialogTitle>
          <DialogDescription>
            Esto generará un enlace único para que el nuevo cliente complete su
            información de alta.
          </DialogDescription>
        </DialogHeader>

        {!newClient ? (
          <div className="flex flex-col items-center gap-4 py-8">
            <p className="text-sm text-muted-foreground text-center">
              Haz clic en el botón para generar un nuevo enlace de alta.
            </p>
            <Button onClick={generateLink} disabled={isPending}>
              {isPending ? "Generando..." : "Generar Enlace de Alta"}
            </Button>
          </div>
        ) : (
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="onboarding-link">
                Enlace de Alta para el Cliente
              </Label>
              <div className="flex w-full items-center space-x-2">
                <Input
                  id="onboarding-link"
                  value={`${window.location.origin}/onboarding/${newClient.onboarding_token}`}
                  readOnly
                />
                <Button
                  type="button"
                  size="icon"
                  onClick={copyToClipboard}
                  className="px-3"
                >
                  <span className="sr-only">Copiar</span>
                  {hasCopied ? (
                    <Check className="h-4 w-4" />
                  ) : (
                    <Copy className="h-4 w-4" />
                  )}
                </Button>
              </div>
            </div>
            <div className="text-sm text-muted-foreground">
              <p>
                Opcional: puedes asignar un convenio a este cliente ahora.
              </p>
              <AssignAgreementDialog client={newClient}>
                 <Button variant="link" className="p-0 h-auto">Asignar Convenio</Button>
              </AssignAgreementDialog>
            </div>
          </div>
        )}

        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline" type="button">
              Cerrar
            </Button>
          </DialogClose>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
