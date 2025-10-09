
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
import { getUnassignedSalesConditions, assignMultipleSalesConditionsToAgreement } from "@/app/actions/admin.actions";
import type { SalesCondition } from "@/types";
import { Checkbox } from "@/components/ui/checkbox";

const assignSchema = z.object({
  sales_condition_ids: z.array(z.string()).nonempty("Debes seleccionar al menos una condición."),
});

type AssignFormValues = z.infer<typeof assignSchema>;

export function AssignSalesConditionDialog({
  children,
  agreementId,
}: {
  children: React.ReactNode;
  agreementId: string;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [conditions, setConditions] = useState<SalesCondition[]>([]);
  const [isPending, startTransition] = useTransition();
  const [isLoading, startLoading] = useTransition();
  const { toast } = useToast();

  const form = useForm<AssignFormValues>({
    resolver: zodResolver(assignSchema),
    defaultValues: {
      sales_condition_ids: [],
    },
  });
  
  const selectedIds = form.watch("sales_condition_ids");


  useEffect(() => {
    if (isOpen) {
      startLoading(async () => {
        const { data, error } = await getUnassignedSalesConditions(agreementId);
        if (error) {
          toast({ title: "Error", description: "No se pudieron cargar las condiciones de venta.", variant: "destructive" });
        } else {
          setConditions(data ?? []);
        }
      });
    }
  }, [isOpen, agreementId, toast]);


  const onSubmit = (values: AssignFormValues) => {
    startTransition(async () => {
      const result = await assignMultipleSalesConditionsToAgreement({ ...values, agreement_id: agreementId });
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: `${values.sales_condition_ids.length} condicion(es) asignada(s) correctamente.` });
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
          <DialogTitle>Asignar Condiciones de Venta</DialogTitle>
          <DialogDescription>
            Selecciona una o más condiciones para aplicar a los clientes de este convenio.
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
              name="sales_condition_ids"
              render={() => (
                <FormItem>
                  <FormLabel>Condiciones Disponibles</FormLabel>
                   <ScrollArea className="h-60 border rounded-md">
                     <div className="p-1">
                      {conditions.length > 0 ? conditions.map(condition => (
                           <FormField
                              key={condition.id}
                              control={form.control}
                              name="sales_condition_ids"
                              render={({ field }) => (
                                <FormItem
                                  key={condition.id}
                                  className="flex flex-row items-center space-x-3 space-y-0 p-3 rounded-md hover:bg-muted/50 data-[state=checked]:bg-secondary"
                                  data-state={field.value?.includes(condition.id) ? "checked" : "unchecked"}
                                >
                                  <FormControl>
                                    <Checkbox
                                      checked={field.value?.includes(condition.id)}
                                      onCheckedChange={(checked) => {
                                        return checked
                                          ? field.onChange([...(field.value || []), condition.id])
                                          : field.onChange(
                                              field.value?.filter(
                                                (value) => value !== condition.id
                                              )
                                            );
                                      }}
                                    />
                                  </FormControl>
                                  <label
                                    htmlFor={`checkbox-${condition.id}`}
                                    className="w-full flex flex-col font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 cursor-pointer"
                                  >
                                      <p>{condition.name}</p>
                                      <p className="text-sm font-normal text-muted-foreground">{condition.description}</p>
                                  </label>
                                </FormItem>
                              )}
                            />
                      )) : <p className="p-4 text-center text-sm text-muted-foreground">No hay más condiciones para asignar.</p>}
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
              <Button type="submit" disabled={isPending || selectedIds.length === 0}>
                {isPending ? "Asignando..." : `Asignar ${selectedIds.length} Condicion(es)`}
              </Button>
            </DialogFooter>
          </form>
        </Form>
        )}
      </DialogContent>
    </Dialog>
  );
}

    