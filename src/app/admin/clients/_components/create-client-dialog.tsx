"use client";

import { useState, useTransition, useEffect } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { UpsertClientForm } from "./upsert-client-form";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { useToast } from "@/hooks/use-toast";
import { createClientForInvitation } from "@/app/admin/actions/clients.actions";
import { Check, Copy, Link, Loader2 } from "lucide-react";
import { getAgreements } from "@/app/admin/actions/agreements.actions";
import type { Agreement } from "@/types";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";


const generateOnboardingLinkSchema = z.object({
  contact_name: z.string().min(3, "El nombre es requerido."),
  email: z.string().email("Debe ser un email válido."),
  agreement_id: z.string({ required_error: "Debes seleccionar un convenio." }).min(1, "Debes seleccionar un convenio."),
});


function GenerateOnboardingLinkForm({ onSuccess }: { onSuccess: () => void }) {
    const [isPending, startTransition] = useTransition();
    const [generatedLink, setGeneratedLink] = useState<string | null>(null);
    const [hasCopied, setHasCopied] = useState(false);
    const { toast } = useToast();
    const [agreements, setAgreements] = useState<Agreement[]>([]);

    useEffect(() => {
        getAgreements().then(({ data }) => {
            if (data) setAgreements(data as Agreement[]);
        });
    }, []);

    const form = useForm({
        resolver: zodResolver(generateOnboardingLinkSchema),
        defaultValues: { contact_name: "", email: "", agreement_id: "" },
    });
    
    const onSubmit = (values: z.infer<typeof generateOnboardingLinkSchema>) => {
        startTransition(async () => {
            const result = await createClientForInvitation(values);
            if (result.error) {
                toast({ title: "Error", description: result.error.message, variant: "destructive" });
            } else {
                const link = `${window.location.origin}/onboarding/${result.data.onboarding_token}`;
                setGeneratedLink(link);
                toast({ title: "Éxito", description: "Enlace de alta generado." });
            }
        });
    };
    
    const handleCopy = () => {
        if (!generatedLink) return;
        navigator.clipboard.writeText(generatedLink);
        setHasCopied(true);
        setTimeout(() => setHasCopied(false), 2000);
    };

    if (generatedLink) {
        return (
            <div className="space-y-4 text-center">
                <p className="text-lg font-semibold">¡Enlace Generado!</p>
                <div className="flex items-center gap-2">
                    <Input value={generatedLink} readOnly className="flex-grow"/>
                    <Button onClick={handleCopy} variant="outline" size="icon">
                        {hasCopied ? <Check className="h-4 w-4 text-green-500"/> : <Copy className="h-4 w-4"/>}
                    </Button>
                </div>
                <p className="text-sm text-muted-foreground">
                    Envía este enlace a tu cliente para que complete sus datos y sea redirigido a su portal de pedidos.
                </p>
                <Button onClick={onSuccess}>Finalizar</Button>
            </div>
        )
    }

    return (
        <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                <p className="text-sm text-muted-foreground">
                   Define el nombre, email y convenio inicial para generar el enlace. El cliente completará el resto y podrá realizar su primer pedido inmediatamente.
                </p>
                <FormField control={form.control} name="contact_name" render={({ field }) => (
                    <FormItem>
                        <FormLabel>Nombre y Apellido / Razón Social</FormLabel>
                        <FormControl><Input placeholder="Nombre del cliente" {...field} /></FormControl>
                        <FormMessage />
                    </FormItem>
                )}/>
                <FormField control={form.control} name="email" render={({ field }) => (
                    <FormItem>
                        <FormLabel>Email</FormLabel>
                        <FormControl><Input type="email" placeholder="cliente@email.com" {...field} /></FormControl>
                        <FormMessage />
                    </FormItem>
                )}/>
                 <FormField control={form.control} name="agreement_id" render={({ field }) => (
                    <FormItem>
                        <FormLabel>Convenio Inicial</FormLabel>
                        <Select onValueChange={field.onChange} defaultValue={field.value}>
                            <FormControl>
                                <SelectTrigger>
                                    <SelectValue placeholder="Selecciona un convenio..." />
                                </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                                {agreements.length === 0 && <p className="p-4 text-sm text-muted-foreground">No hay convenios. Crea uno primero.</p>}
                                {agreements.map(agreement => (
                                    <SelectItem key={agreement.id} value={agreement.id}>
                                        {agreement.agreement_name}
                                    </SelectItem>
                                ))}
                            </SelectContent>
                        </Select>
                        <FormMessage />
                    </FormItem>
                )}/>
                 <Button type="submit" disabled={isPending || agreements.length === 0} className="w-full">
                    {isPending ? <><Loader2 className="mr-2 h-4 w-4 animate-spin"/> Generando...</> : <><Link className="mr-2 h-4 w-4"/> Generar Enlace de Alta</>}
                </Button>
            </form>
        </Form>
    );
}


export function CreateClientDialog({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);

  const handleSuccess = () => {
    setIsOpen(false);
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-3xl grid-rows-[auto_1fr] p-0 max-h-[90vh]">
        <DialogHeader className="p-6 pb-0">
          <DialogTitle>Agregar Cliente</DialogTitle>
          <DialogDescription>
            Elige un método para agregar un nuevo cliente al sistema.
          </DialogDescription>
        </DialogHeader>
        <div className="p-6">
          <Tabs defaultValue="manual" className="w-full">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="manual">Carga Manual</TabsTrigger>
              <TabsTrigger value="link">Generar Link de Alta</TabsTrigger>
            </TabsList>
            <TabsContent value="manual" className="pt-6">
              <p className="text-sm text-muted-foreground mb-4">Completa todos los datos del cliente directamente. Ideal si ya tienes toda su información.</p>
              <UpsertClientForm 
                  onSuccess={handleSuccess} 
                  onCancel={() => setIsOpen(false)} 
              />
            </TabsContent>
            <TabsContent value="link" className="pt-6">
               <GenerateOnboardingLinkForm onSuccess={handleSuccess} />
            </TabsContent>
          </Tabs>
        </div>
      </DialogContent>
    </Dialog>
  );
}
