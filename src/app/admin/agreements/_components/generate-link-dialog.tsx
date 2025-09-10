
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
  DialogClose,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { generateOrderLink } from "@/app/actions/admin.actions";
import type { Agreement } from "@/types";
import { Copy } from "lucide-react";

export function GenerateLinkDialog({
  children,
  agreement,
}: {
  children: React.ReactNode;
  agreement: Agreement;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [generatedLink, setGeneratedLink] = useState<string | null>(null);
  const [clientName, setClientName] = useState<string>(agreement.agreement_name);
  const { toast } = useToast();

  const handleGenerate = () => {
    startTransition(async () => {
      const result = await generateOrderLink(agreement.id, clientName);
      if (result.error) {
        toast({
          title: "Error al generar enlace",
          description: result.error.message,
          variant: "destructive",
        });
        setGeneratedLink(null);
      } else {
        setGeneratedLink(result.link);
        toast({ title: "Enlace generado correctamente!" });
      }
    });
  };

  const copyToClipboard = () => {
    if (generatedLink) {
      navigator.clipboard.writeText(generatedLink);
      toast({ title: "Enlace copiado al portapapeles!" });
    }
  };
  
  const handleOpenChange = (open: boolean) => {
    setIsOpen(open);
    if (!open) {
      setGeneratedLink(null);
      setClientName(agreement.agreement_name);
    }
  }


  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Generar Enlace de Pedido</DialogTitle>
          <DialogDescription>
            Genera un enlace de 24hs para el convenio <strong>{agreement.agreement_name}</strong>.
          </DialogDescription>
        </DialogHeader>
        
        {!generatedLink ? (
          <div className="space-y-4 py-4">
             <div className="space-y-2">
              <Label htmlFor="clientName">Nombre del Cliente (Opcional)</Label>
               <Input 
                id="clientName"
                value={clientName}
                onChange={(e) => setClientName(e.target.value)}
                placeholder="Usará el nombre del convenio"
               />
               <p className="text-xs text-muted-foreground">
                Este nombre aparecerá en la página del pedido. Por defecto, es el nombre del convenio.
               </p>
            </div>
            <Button onClick={handleGenerate} disabled={isPending} className="w-full">
              {isPending ? "Generando..." : "Generar Enlace"}
            </Button>
          </div>
        ) : (
          <div className="mt-6 space-y-2">
            <Label>Enlace Generado</Label>
            <div className="flex items-center gap-2">
              <Input
                type="text"
                readOnly
                value={generatedLink}
                className="bg-muted"
              />
              <Button
                variant="outline"
                size="icon"
                onClick={copyToClipboard}
              >
                <Copy className="h-4 w-4" />
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              Este enlace expirará en 24 horas.
            </p>
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
