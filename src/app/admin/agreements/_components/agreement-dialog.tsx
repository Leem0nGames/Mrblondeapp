"use client";

import { useState, useTransition } from "react";
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
import { upsertAgreement } from "@/app/actions/admin.actions";
import type { Agreement } from "@/types";

const agreementSchema = z.object({
  name: z.string().min(3, "Name must be at least 3 characters"),
  client_type: z.enum(["barberia", "distribuidor", "especial"]),
  price_adjustment: z.coerce.number(),
});

type AgreementFormValues = z.infer<typeof agreementSchema>;

export function AgreementDialog({
  children,
  agreement,
}: {
  children: React.ReactNode;
  agreement?: Agreement;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const form = useForm<AgreementFormValues>({
    resolver: zodResolver(agreementSchema),
    defaultValues: {
      name: agreement?.name ?? "",
      client_type: agreement?.client_type ?? "barberia",
      price_adjustment: agreement?.price_adjustment ?? 0,
    },
  });

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
          title: "Success",
          description: `Agreement ${agreement ? "updated" : "created"} successfully.`,
        });
        setIsOpen(false);
        form.reset();
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-[525px]">
        <DialogHeader>
          <DialogTitle>{agreement ? "Edit Agreement" : "Add New Agreement"}</DialogTitle>
          <DialogDescription>
            {agreement
              ? "Update the details of this agreement."
              : "Fill in the details for the new agreement."}
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Agreement Name</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g., Distribuidores Premium" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <div className="grid grid-cols-2 gap-4">
               <FormField
                control={form.control}
                name="client_type"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Client Type</FormLabel>
                     <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select a client type" />
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
                name="price_adjustment"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Price Adjustment (%)</FormLabel>
                    <FormControl>
                      <Input type="number" step="0.1" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
           
            <DialogFooter>
              <DialogClose asChild>
                <Button variant="outline" type="button">
                  Cancel
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isPending}>
                {isPending ? "Saving..." : "Save Agreement"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
