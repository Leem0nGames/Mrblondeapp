
"use client";

import { useState, useTransition, useEffect } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
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
import { getPriceLists, upsertAgreement } from "@/app/actions/admin.actions";
import type { DetailedAgreement, PriceList } from "@/types";

const agreementSchema = z.object({
  agreement_name: z.string().min(3, "El nombre debe tener al menos 3 caracteres"),
  client_type: z.enum(["barberia", "distribuidor", "especial"]),
  price_list_id: z.string().nullable(),
});

type AgreementFormValues = z.infer<typeof agreementSchema>;

export function AgreementDialog({
  children,
  agreement,
}: {
  children: React.ReactNode;
  agreement?: DetailedAgreement;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [priceLists, setPriceLists] = useState<PriceList[]>([]);
  const { toast } = useToast();

  const form = useForm<AgreementFormValues>({
    resolver: zodResolver(agreementSchema),
    defaultValues: {
      agreement_name: agreement?.agreement_name ?? "",
      client_type: agreement?.client_type ?? "barberia",
      price_list_id: agreement?.price_list_id ?? null,
    },
  });
  
  useEffect(() => {
    if (isOpen) {
        async function fetchPriceLists() {
            const { data } = await getPriceLists();
            setPriceLists(data ?? []);
        }
        fetchPriceLists();
    }
  }, [isOpen]);

  const onSubmit = (values: AgreementFormValues) => {
    startTransition(async () => {
      const result = await upsertAgreement({ ...values, id: agreement?.id });
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Éxito",
          description: `Convenio ${agreement ? "actualizado" : "creado"} correctamente.`,
        });
        setIsOpen(false);
        form.reset();
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{agreement ? "Editar Convenio" : "Nuevo Convenio"}</DialogTitle>
          <DialogDescription>
            {agreement
              ? "Actualiza los detalles de este convenio."
              : "Define un nuevo convenio para agrupar clientes y reglas."}
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 pt-4">
            <FormField
              control={form.control}
              name="agreement_name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Nombre del Convenio</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g., Distribuidores Premium" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
             <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <FormField
                control={form.control}
                name="client_type"
                render={({ field }) => (
                    <FormItem>
                    <FormLabel>Tipo de Cliente</FormLabel>
                        <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                            <SelectTrigger>
                            <SelectValue placeholder="Selecciona un tipo" />
                            </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                            <SelectItem value="barberia">Barbería</SelectItem>
                            <SelectItem value="distribuidor">Distribuidor</SelectItem>
                            <SelectItem value="especial">Especial</SelectItem>
                        </SelectContent>
                        </Select>
                    <FormMessage />
                    </FormItem>
                )}
                />
                 <FormField
                    control={form.control}
                    name="price_list_id"
                    render={({ field }) => (
                        <FormItem>
                        <FormLabel>Lista de Precios</FormLabel>
                        <Select onValueChange={(value) => field.onChange(value === 'null' ? null : value)} defaultValue={field.value ?? 'null'}>
                            <FormControl>
                            <SelectTrigger>
                                <SelectValue placeholder="Selecciona una lista..." />
                            </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                            <SelectItem value="null">Ninguna</SelectItem>
                            {priceLists.map(list => (
                                <SelectItem key={list.id} value={list.id}>
                                {list.name}
                                </SelectItem>
                            ))}
                            </SelectContent>
                        </Select>
                        <FormMessage />
                        </FormItem>
                    )}
                    />
            </div>
           
            <DialogFooter className="pt-4">
              <DialogClose asChild>
                <Button variant="outline" type="button">
                  Cancelar
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isPending}>
                {isPending ? "Guardando..." : "Guardar Convenio"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
