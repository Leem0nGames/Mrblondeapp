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
import { ScrollArea } from "@/components/ui/scroll-area";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";
import { getUnassignedPromotions, assignPromotionToAgreement } from "@/app/actions/admin.actions";
import type { Promotion } from "@/types";
import { Check, PlusCircle } from "lucide-react";

const assignSchema = z.object({
  promotion_id: z.string().min(1, "Debes seleccionar una promoción."),
});

type AssignFormValues = z.infer<typeof assignSchema>;

export function AssignPromotionDialog({
  children,
  agreementId,
}: {
  children: React.ReactNode;
  agreementId: string;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [promotions, setPromotions] = useState<Promotion[]>([]);
  const [isPending, startTransition] = useTransition();
  const [isLoading, startLoading] = useTransition();
  const { toast } = useToast();

  const form = useForm<AssignFormValues>({
    resolver: zodResolver(assignSchema),
    defaultValues: {
      promotion_id: "",
    },
  });

  useEffect(() => {
    if (isOpen) {
      startLoading(async () => {
        const { data, error } = await getUnassignedPromotions(agreementId);
        if (error) {
          toast({ title: "Error", description: "No se pudieron cargar las promociones.", variant: "destructive" });
        } else {
          setPromotions(data ?? []);
        }
      });
    }
  }, [isOpen, agreementId, toast]);


  const onSubmit = (values: AssignFormValues) => {
    startTransition(async () => {
      const result = await assignPromotionToAgreement({ ...values, agreement_id: agreementId });
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: `Promoción asignada correctamente.` });
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
          <DialogTitle>Asignar Promoción</DialogTitle>
          <DialogDescription>
            Selecciona una promoción para aplicar a los clientes de este convenio.
          </DialogDescription>
        </DialogHeader>
        {isLoading ? <div className="space-y-4 py-4">
            <Skeleton className="h-24 w-full" />
            <div className="flex justify-end gap-2 pt-4">
                <Skeleton className="h-10 w-24" />
                <Skeleton className="h-10 w-24" />
            </div>
        </div> : (
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
            <FormField
              control={form.control}
              name="promotion_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Promociones Disponibles</FormLabel>
                   <ScrollArea className="h-60 border rounded-md">
                     <div className="p-2 space-y-1">
                      {promotions.length > 0 ? promotions.map(promo => (
                          <button
                            type="button"
                            key={promo.id}
                            onClick={() => field.onChange(promo.id)}
                            className={`w-full flex items-start gap-4 p-3 rounded-md text-left transition-colors ${field.value === promo.id ? 'bg-secondary' : 'hover:bg-muted/50'}`}
                          >
                              <div className="flex-grow">
                                <p className="font-medium">{promo.name}</p>
                                <p className="text-sm text-muted-foreground">{promo.description}</p>
                              </div>
                              {field.value === promo.id && <Check className="h-5 w-5 text-primary" />}
                          </button>
                      )) : <p className="p-4 text-center text-sm text-muted-foreground">No hay más promociones para asignar.</p>}
                      </div>
                    </ScrollArea>
                  <FormMessage className="pt-2" />
                </FormItem>
              )}
            />
            <DialogFooter>
              <DialogClose asChild>
                <Button variant="outline" type="button" onClick={() => form.reset()}>
                  Cancelar
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isPending || !form.getValues("promotion_id")}>
                {isPending ? "Asignando..." : "Asignar Promoción"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
        )}
      </DialogContent>
    </Dialog>
  );
}
