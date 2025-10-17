
"use client";

import { useState, useTransition, useCallback, useEffect } from "react";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";
import { getAgreements } from "@/app/admin/actions/agreements.actions";
import { Copy, Check, Loader2 } from "lucide-react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import type { AgreementWithCount } from "@/types";

const formSchema = z.object({
  agreementId: z.string().nullable(),
});

type FormValues = z.infer<typeof formSchema>;

export function CreateClientDialog({
  children,
}: {
  children: React.ReactNode;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [isGenerating, startGenerating] = useTransition();
  const { toast } = useToast();
  
  const [generatedLink, setGeneratedLink] = useState<string | null>(null);
  const [hasCopied, setHasCopied] = useState(false);
  const [agreements, setAgreements] = useState<AgreementWithCount[]>([]);
  const [isLoadingAgreements, setIsLoadingAgreements] = useState(false);

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      agreementId: null,
    }
  });

  const fetchAgreements = useCallback(async () => {
    setIsLoadingAgreements(true);
    const { data } = await getAgreements();
    setAgreements(data ?? []);
    setIsLoadingAgreements(false);
  }, []);

  useEffect(() => {
    if (isOpen) {
      fetchAgreements();
    }
  }, [isOpen, fetchAgreements]);


  const onSubmit = (values: FormValues) => {
    startGenerating(async () => {
      const result = await createClientForInvitation(values.agreementId);
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        setGeneratedLink(result.data.link);
        toast({
          title: "¡Enlace Generado!",
          description: "Copia el enlace para enviárselo al cliente.",
        });
      }
    });
  };

  const copyToClipboard = useCallback(() => {
    if (!generatedLink || typeof window === "undefined") return;
    const fullLink = `${window.location.origin}${generatedLink}`;
    navigator.clipboard.writeText(fullLink);
    setHasCopied(true);
    setTimeout(() => setHasCopied(false), 2000);
  }, [generatedLink]);

  const handleOpenChange = (open: boolean) => {
    if (!open) {
      // Reset state when closing
      setGeneratedLink(null);
      setHasCopied(false);
      form.reset();
    }
    setIsOpen(open);
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Crear Enlace de Alta para Cliente</DialogTitle>
          <DialogDescription>
            Selecciona un convenio y genera un enlace único para que un nuevo cliente complete su información.
          </DialogDescription>
        </DialogHeader>

        {!generatedLink ? (
            <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6 pt-4">
              <FormField
                control={form.control}
                name="agreementId"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Convenio (Opcional)</FormLabel>
                    <Select onValueChange={(value) => field.onChange(value === 'null' ? null : value)} defaultValue={field.value ?? 'null'}>
                      <FormControl>
                        <SelectTrigger disabled={isLoadingAgreements}>
                          <SelectValue placeholder={isLoadingAgreements ? "Cargando convenios..." : "Selecciona un convenio..."} />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="null">Ninguno (se asignará después)</SelectItem>
                        {agreements.map(agreement => (
                          <SelectItem key={agreement.id} value={agreement.id}>
                            {agreement.agreement_name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
               <Button type="submit" disabled={isGenerating} className="w-full">
                {isGenerating ? <><Loader2 className="mr-2 h-4 w-4 animate-spin" /> Generando...</> : "Generar Enlace de Alta"}
              </Button>
            </form>
          </Form>
        ) : (
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="onboarding-link">
                Enlace de Alta Generado
              </Label>
              <div className="flex w-full items-center space-x-2">
                <Input
                  id="onboarding-link"
                  value={`${window.location.origin}${generatedLink}`}
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
             <p className="text-sm text-muted-foreground">
                Envía este enlace al cliente para que complete su registro.
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
