

"use client";

import { useState, useTransition, useEffect, useCallback } from "react";
import { z } from "zod";
import { useForm, FormProvider } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
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
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";
import { getAgreements } from "@/app/admin/actions/agreements.actions";
import type { AgreementWithCount } from "@/types";
import { Copy, Check, FilePen } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { useRouter } from "next/navigation";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";


const formSchema = z.object({
  agreementId: z.string().nullable(),
});

type FormValues = z.infer<typeof formSchema>;


export function CreateClientDialog({ children, open, onOpenChange }: { children: React.ReactNode, open: boolean, onOpenChange: (open: boolean) => void }) {
  const [isGenerating, startGeneration] = useTransition();
  const [isLoadingData, startLoadingData] = useTransition();

  const { toast } = useToast();
  const router = useRouter();
  
  const [invitationLink, setInvitationLink] = useState<string | null>(null);
  const [hasCopied, setHasCopied] = useState(false);
  const [agreements, setAgreements] = useState<AgreementWithCount[]>([]);

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      agreementId: null,
    },
  });

  const fetchAgreements = useCallback(() => {
    startLoadingData(async () => {
      const { data } = await getAgreements();
      setAgreements(data ?? []);
    });
  }, []);

  useEffect(() => {
    if (open) {
      fetchAgreements();
    }
  }, [open, fetchAgreements]);


  const onSubmit = (values: FormValues) => {
      startGeneration(async () => {
          const result = await createClientForInvitation(values.agreementId);
          if (result.error || !result.data) {
              toast({ title: "Error", description: result.error?.message || 'No se pudo crear la invitación.', variant: "destructive" });
          } else {
              const link = `${window.location.origin}${result.data.link}`;
              setInvitationLink(link);
              toast({ title: "¡Enlace Generado!", description: "Ahora puedes copiar el enlace y enviarlo." });
              router.refresh();
          }
      });
  };

  const handleCopyToClipboard = () => {
    if (!invitationLink) return;
    navigator.clipboard.writeText(invitationLink);
    setHasCopied(true);
    toast({ title: "Enlace copiado al portapapeles" });
    setTimeout(() => setHasCopied(false), 2000);
  };

  const handleDialogChange = (isOpen: boolean) => {
      onOpenChange(isOpen);
      if (!isOpen) {
          setTimeout(() => {
            setInvitationLink(null);
            setHasCopied(false);
            form.reset();
          }, 300);
      }
  }
  
  const renderContent = () => {
      if (invitationLink) {
          return (
             <div className="space-y-4">
                <Alert>
                    <AlertTitle>¡Enlace de Invitación Generado!</AlertTitle>
                    <AlertDescription className="break-all mt-2">
                        {invitationLink}
                    </AlertDescription>
                </Alert>
                <Button onClick={handleCopyToClipboard} className="w-full">
                    {hasCopied ? <Check className="mr-2 h-4 w-4" /> : <Copy className="mr-2 h-4 w-4" />}
                    {hasCopied ? "Copiado" : "Copiar Enlace"}
                </Button>
            </div>
          );
      }

      if (isLoadingData) {
          return (
            <div className="space-y-4 py-4">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          );
      }

      return (
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
               <FormField
                control={form.control}
                name="agreementId"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Convenio a Asignar</FormLabel>
                    <Select 
                      onValueChange={(value) => field.onChange(value === 'null' ? null : value)} 
                      defaultValue={field.value ?? 'null'}
                    >
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Selecciona un convenio..." />
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
               <DialogFooter className="pt-4 !mt-0">
                  <DialogClose asChild>
                      <Button variant="outline" type="button">Cancelar</Button>
                  </DialogClose>
                  <Button type="submit" disabled={isGenerating}>
                      {isGenerating ? "Generando..." : "Generar Enlace"}
                  </Button>
              </DialogFooter>
            </form>
        </Form>
      )
  }

  return (
    <Dialog open={open} onOpenChange={handleDialogChange}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Invitar Nuevo Cliente</DialogTitle>
          <DialogDescription>
            Selecciona un convenio para pre-asignar y genera un enlace único para que el cliente complete sus datos.
          </DialogDescription>
        </DialogHeader>

        <div className="py-4">
           {renderContent()}
        </div>
        
         {invitationLink && (
             <DialogFooter>
                <DialogClose asChild>
                    <Button variant="outline">
                        Cerrar
                    </Button>
                </DialogClose>
            </DialogFooter>
         )}
      </DialogContent>
    </Dialog>
  );
}
