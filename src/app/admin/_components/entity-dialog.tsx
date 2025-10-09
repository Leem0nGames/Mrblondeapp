
"use client";

import { useState, useTransition, useEffect, cloneElement } from "react";
import { z } from "zod";
import { useForm, UseFormReturn } from "react-hook-form";
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
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import type { Product, Promotion } from "@/types";

// Define una interfaz para la configuración del formulario
export interface FormConfig<T extends z.ZodType<any, any>> {
  entityName: string;
  schema: T;
  upsertAction: (payload: any) => Promise<{ data: any; error: any }>;
  getDefaultValues: (entity?: any) => z.infer<T>;
  renderFields: (form: UseFormReturn<z.infer<T>>) => React.ReactNode;
}

interface EntityDialogProps {
  children: React.ReactElement;
  formConfig: FormConfig<any>;
  entity?: Product | Promotion;
}

export function EntityDialog({
  children,
  formConfig,
  entity,
}: EntityDialogProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const {
    entityName,
    schema,
    upsertAction,
    getDefaultValues,
    renderFields,
  } = formConfig;

  const form = useForm({
    resolver: zodResolver(schema),
    defaultValues: getDefaultValues(entity),
  });

  // Efecto para resetear el formulario cuando se abre/cierra o cambia la entidad
  useEffect(() => {
    if (isOpen) {
      form.reset(getDefaultValues(entity));
    }
  }, [isOpen, entity, form, getDefaultValues]);

  const onSubmit = (values: z.infer<any>) => {
    startTransition(async () => {
      const result = await upsertAction({ ...values, id: entity?.id });
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Éxito",
          description: `${entityName} ${entity ? "actualizado" : "creado"} correctamente.`,
        });
        setIsOpen(false);
      }
    });
  };
  
  const dialogTitle = `${entity ? "Editar" : "Nuevo"} ${entityName}`;
  const dialogDescription = entity
    ? `Actualiza los detalles de este ${entityName.toLowerCase()}.`
    : `Completa los detalles para el nuevo ${entityName.toLowerCase()}.`;


  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{cloneElement(children, { onClick: () => setIsOpen(true) })}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{dialogTitle}</DialogTitle>
          <DialogDescription>{dialogDescription}</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 pt-4">
            {renderFields(form)}
            <DialogFooter className="pt-4">
              <DialogClose asChild>
                <Button variant="outline" type="button">
                  Cancelar
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isPending}>
                {isPending ? "Guardando..." : `Guardar ${entityName}`}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
