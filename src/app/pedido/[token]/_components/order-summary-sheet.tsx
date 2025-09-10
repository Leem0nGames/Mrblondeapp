"use client";

import { useState, useTransition } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
  SheetFooter,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { useCartStore } from "@/hooks/use-cart-store";
import { Agreement, ClientDetails } from "@/types";
import { ScrollArea } from "@/components/ui/scroll-area";
import Image from "next/image";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { IntelligentSuggestions } from "./intelligent-suggestions";

const clientDetailsSchema = z.object({
  name: z.string().min(3, "El nombre es requerido"),
  phone: z.string().min(8, "El teléfono es requerido"),
  address: z.string().min(5, "La dirección es requerida"),
  city: z.string().min(3, "La ciudad es requerida"),
});

function formatWhatsAppMessage(
  clientDetails: ClientDetails,
  cartItems: any[],
  totalPrice: number
) {
  const itemsText = cartItems
    .map(
      (item) =>
        `- ${item.product.name} x${item.quantity} = $${(
          item.product.base_price * item.quantity
        ).toLocaleString()}`
    )
    .join("\n");

  const message = `
¡Hola! 👋 Quisiera realizar el siguiente pedido:

*Cliente:* ${clientDetails.name}
*Teléfono:* ${clientDetails.phone}
*Dirección:* ${clientDetails.address}, ${clientDetails.city}

*Productos:*
${itemsText}

*Total:* $${totalPrice.toLocaleString()}

¡Gracias!
    `.trim();

  return encodeURIComponent(message);
}

export function OrderSummarySheet({
  isOpen,
  onOpenChange,
  agreement,
}: {
  isOpen: boolean;
  onOpenChange: (isOpen: boolean) => void;
  agreement: Agreement;
}) {
  const { items, totalPrice, totalItems } = useCartStore();
  const { toast } = useToast();
  const whatsAppNumber = process.env.NEXT_PUBLIC_WHATSAPP_NUMBER || '5491123456789';

  const form = useForm<ClientDetails>({
    resolver: zodResolver(clientDetailsSchema),
    defaultValues: {
      name: agreement.client_name,
      phone: "",
      address: "",
      city: "",
    },
  });

  const handleSubmit = (values: ClientDetails) => {
    if (items.length === 0) {
      toast({
        title: "Carrito vacío",
        description: "Agrega productos antes de enviar el pedido.",
        variant: "destructive",
      });
      return;
    }
    const message = formatWhatsAppMessage(values, items, totalPrice);
    const whatsappUrl = `https://wa.me/${whatsAppNumber}?text=${message}`;
    window.open(whatsappUrl, "_blank");
  };

  return (
    <Sheet open={isOpen} onOpenChange={onOpenChange}>
      <SheetContent className="flex flex-col w-full sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>Resumen del Pedido</SheetTitle>
          <SheetDescription>
            Confirma tus datos y envía el pedido por WhatsApp.
          </SheetDescription>
        </SheetHeader>
        <div className="flex-1 overflow-y-auto pr-6 -mr-6">
            <ScrollArea className="h-full">
                <div className="space-y-6">
                    {/* Items */}
                    <div>
                        <h3 className="text-lg font-medium mb-2">Productos</h3>
                        <div className="space-y-4">
                        {items.map((item) => (
                            <div key={item.product.id} className="flex items-center gap-4">
                            <Image
                                src={`https://picsum.photos/seed/${item.product.id}/48/48`}
                                alt={item.product.name}
                                width={48}
                                height={48}
                                className="rounded-md"
                                data-ai-hint="product image"
                            />
                            <div className="flex-grow">
                                <p className="font-medium">{item.product.name}</p>
                                <p className="text-sm text-muted-foreground">
                                {item.quantity} x ${item.product.base_price.toLocaleString()}
                                </p>
                            </div>
                            <p className="font-semibold">
                                ${(item.quantity * item.product.base_price).toLocaleString()}
                            </p>
                            </div>
                        ))}
                        </div>
                        <Separator className="my-4" />
                        <div className="flex justify-between font-bold text-lg">
                            <span>Total</span>
                            <span>${totalPrice.toLocaleString()}</span>
                        </div>
                    </div>
                    
                    <Separator />
                    
                    {/* Client Form */}
                    <div>
                        <h3 className="text-lg font-medium mb-4">Tus Datos</h3>
                        <form id="client-details-form" onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
                            <div>
                                <Label htmlFor="name">Nombre</Label>
                                <Input id="name" {...form.register("name")} />
                                {form.formState.errors.name && <p className="text-destructive text-sm mt-1">{form.formState.errors.name.message}</p>}
                            </div>
                            <div>
                                <Label htmlFor="phone">Teléfono (WhatsApp)</Label>
                                <Input id="phone" {...form.register("phone")} />
                                {form.formState.errors.phone && <p className="text-destructive text-sm mt-1">{form.formState.errors.phone.message}</p>}
                            </div>
                            <div>
                                <Label htmlFor="address">Dirección</Label>
                                <Input id="address" {...form.register("address")} />
                                {form.formState.errors.address && <p className="text-destructive text-sm mt-1">{form.formState.errors.address.message}</p>}
                            </div>
                            <div>
                                <Label htmlFor="city">Ciudad</Label>
                                <Input id="city" {...form.register("city")} />
                                {form.formState.errors.city && <p className="text-destructive text-sm mt-1">{form.formState.errors.city.message}</p>}
                            </div>
                        </form>
                    </div>

                    <Separator />

                    {/* AI Suggestions */}
                    <IntelligentSuggestions agreement={{
                        type: agreement.client_type,
                        agreement_id: agreement.id,
                        total_unidades: totalItems,
                        nombre: agreement.client_name,
                        // These will be updated from the form
                        ciudad: form.watch('city'),
                        direccion: form.watch('address'),
                        items: items.map(i => ({id: i.product.id, name: i.product.name, quantity: i.quantity}))
                    }}/>

                </div>
            </ScrollArea>
        </div>
        <SheetFooter className="mt-auto pt-4 border-t">
          <Button
            type="submit"
            form="client-details-form"
            size="lg"
            className="w-full"
            disabled={!form.formState.isValid || items.length === 0}
          >
            Enviar Pedido por WhatsApp
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
