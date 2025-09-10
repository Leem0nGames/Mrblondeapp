"use client";

import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
  SheetFooter,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { useCartStore } from "@/hooks/use-cart-store";
import { Agreement, ClientDetails } from "@/types";
import { ScrollArea } from "@/components/ui/scroll-area";
import Image from "next/image";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { IntelligentSuggestions } from "./intelligent-suggestions";

function formatWhatsAppMessage(
  clientName: string,
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

*Cliente:* ${clientName}

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


  const handleSend = () => {
    if (items.length === 0) {
      toast({
        title: "Carrito vacío",
        description: "Agrega productos antes de enviar el pedido.",
        variant: "destructive",
      });
      return;
    }
    const message = formatWhatsAppMessage(agreement.client_name, items, totalPrice);
    const whatsappUrl = `https://wa.me/${whatsAppNumber}?text=${message}`;
    window.open(whatsappUrl, "_blank");
  };

  return (
    <Sheet open={isOpen} onOpenChange={onOpenChange}>
      <SheetContent className="flex flex-col w-full sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>Resumen del Pedido</SheetTitle>
          <SheetDescription>
            Confirma tu pedido y envíalo por WhatsApp.
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

                    {/* AI Suggestions */}
                    <IntelligentSuggestions agreement={{
                        type: agreement.client_type,
                        agreement_id: agreement.id,
                        total_unidades: totalItems,
                        nombre: agreement.client_name,
                        items: items.map(i => ({id: i.product.id, name: i.product.name, quantity: i.quantity}))
                    }}/>

                </div>
            </ScrollArea>
        </div>
        <SheetFooter className="mt-auto pt-4 border-t">
          <Button
            onClick={handleSend}
            size="lg"
            className="w-full"
            disabled={items.length === 0}
          >
            Enviar Pedido por WhatsApp
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
