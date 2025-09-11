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
import { getUnassignedPromotions, assignMultiplePromotionsToAgreement } from "@/app/actions/admin.actions";
import type { Promotion } from "@/types";
import { Checkbox } from "@/components/ui/checkbox";

const assignSchema = z.object({
  promotion_ids: z.array(z.string()).nonempty("Debes seleccionar al menos una promoción."),
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
      promotion_ids: [],
    },
  });
  
  const selectedPromotionIds = form.watch("promotion_ids");


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
      const result = await assignMultiplePromotionsToAgreement({ ...values, agreement_id: agreementId });
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: `${values.promotion_ids.length} promocion(es) asignada(s) correctamente.` });
        setIsOpen(false);
        form.reset();
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => {
      setIsOpen(open);
      if (!open) {
        form.reset();
      }
    }}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Asignar Promociones</DialogTitle>
          <DialogDescription>
            Selecciona una o más promociones para aplicar a los clientes de este convenio.
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
              name="promotion_ids"
              render={() => (
                <FormItem>
                  <FormLabel>Promociones Disponibles</FormLabel>
                   <ScrollArea className="h-60 border rounded-md">
                     <div className="p-1">
                      {promotions.length > 0 ? promotions.map(promo => (
                           <FormField
                              key={promo.id}
                              control={form.control}
                              name="promotion_ids"
                              render={({ field }) => (
                                <FormItem
                                  key={promo.id}
                                  className="flex flex-row items-center space-x-3 space-y-0 p-3 rounded-md hover:bg-muted/50 data-[state=checked]:bg-secondary"
                                  data-state={field.value?.includes(promo.id) ? "checked" : "unchecked"}
                                >
                                  <FormControl>
                                    <Checkbox
                                      checked={field.value?.includes(promo.id)}
                                      onCheckedChange={(checked) => {
                                        return checked
                                          ? field.onChange([...field.value, promo.id])
                                          : field.onChange(
                                              field.value?.filter(
                                                (value) => value !== promo.id
                                              )
                                            );
                                      }}
                                    />
                                  </FormControl>
                                  <label
                                    htmlFor={`checkbox-${promo.id}`}
                                    className="w-full flex flex-col font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 cursor-pointer"
                                  >
                                      <p>{promo.name}</p>
                                      <p className="text-sm font-normal text-muted-foreground">{promo.description}</p>
                                  </label>
                                </FormItem>
                              )}
                            />
                      )) : <p className="p-4 text-center text-sm text-muted-foreground">No hay más promociones para asignar.</p>}
                      </div>
                    </ScrollArea>
                  <FormMessage className="pt-2" />
                </FormItem>
              )}
            />
            <DialogFooter>
              <DialogClose asChild>
                <Button variant="outline" type="button">
                  Cancelar
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isPending || selectedPromotionIds.length === 0}>
                {isPending ? "Asignando..." : `Asignar ${selectedPromotionIds.length} Promocion(es)`}
              </Button>
            </DialogFooter>
          </form>
        </Form>
        )}
      </DialogContent>
    </Dialog>
  );
}
