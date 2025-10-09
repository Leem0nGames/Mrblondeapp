
"use client";

import { useState, useTransition, cloneElement } from "react";
import { Copy } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { createClientOnboardingLink } from "@/app/actions/admin.actions";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";


export function CreateClientButton({ children }: { children: React.ReactElement }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();
  const [generatedLink, setGeneratedLink] = useState<string | null>(null);

  const handleCreateLink = () => {
    startTransition(async () => {
      const result = await createClientOnboardingLink();
      if (result.error) {
        toast({ title: "Error al crear enlace", description: result.error.message, variant: "destructive" });
      } else {
        const token = result.data?.onboarding_token;
        if (token) {
          const link = `${window.location.origin}/onboarding/${token}`;
          setGeneratedLink(link);
        } else {
            toast({ title: "Error", description: "No se pudo generar el token del enlace.", variant: "destructive" });
        }
      }
    });
  };

  const handleCopyToClipboard = () => {
    if (generatedLink) {
        navigator.clipboard.writeText(generatedLink);
        toast({
            title: "¡Enlace de invitación copiado!",
            description: "Puedes enviarle este enlace a tu nuevo cliente.",
        });
    }
  }

  const resetAndClose = () => {
    setGeneratedLink(null);
  }

  return (
    <>
      <AlertDialog>
        <AlertDialogTrigger asChild>
          {cloneElement(children, { disabled: isPending })}
        </AlertDialogTrigger>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Generar Enlace de Invitación</AlertDialogTitle>
            <AlertDialogDescription>
              Se generará un enlace único para que un nuevo cliente complete sus datos. 
              Luego podrás copiarlo.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleCreateLink}
              disabled={isPending}
            >
              {isPending ? "Generando..." : "Generar Enlace"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

       <Dialog open={!!generatedLink} onOpenChange={(isOpen) => !isOpen && resetAndClose()}>
        <DialogContent>
            <DialogHeader>
                <DialogTitle>Enlace Generado</DialogTitle>
                <DialogDescription>
                    Envía este enlace a tu nuevo cliente para que complete su alta.
                </DialogDescription>
            </DialogHeader>
            <div className="flex items-center space-x-2">
                <div className="grid flex-1 gap-2">
                    <Label htmlFor="link" className="sr-only">
                        Link
                    </Label>
                    <Input
                        id="link"
                        defaultValue={generatedLink ?? ""}
                        readOnly
                    />
                </div>
                <Button type="button" size="sm" className="px-3" onClick={handleCopyToClipboard}>
                    <span className="sr-only">Copiar</span>
                    <Copy className="h-4 w-4" />
                </Button>
            </div>
            <DialogFooter>
                <DialogClose asChild>
                    <Button variant="outline">Cerrar</Button>
                </DialogClose>
            </DialogFooter>
        </DialogContent>
       </Dialog>
    </>
  );
}
