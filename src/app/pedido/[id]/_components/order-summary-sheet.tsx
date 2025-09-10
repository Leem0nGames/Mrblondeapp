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
import { useCartStore, type CartItem } from "@/hooks/use-cart-store";
import { AgreementPromotion } from "@/types";
import { ScrollArea } from "@/components/ui/scroll-area";
import Image from "next/image";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { IntelligentSuggestions } from "./intelligent-suggestions";
import { getImageUrl } from "@/lib/placeholder-images";

function formatWhatsAppMessage(
  clientName: string,
  cartItems: CartItem[],
  totalPrice: number,
  promotions: AgreementPromotion[],
  totalUnits: number,
) {
  // 1. Format product list
  const itemsText = cartItems
    .map((item) => `- ${item.quantity}x ${item.product.name}`)
    .join("\n");

  // 2. Calculate bonuses
  let bonusText = "";
  const buyXgetYFreePromos = promotions.filter(
    (p) => p.promotions.rules?.type === "buy_x_get_y_free"
  );
  
  if (buyXgetYFreePromos.length > 0) {
      // Find the most advantageous promotion (the one that requires more items, assuming it gives more)
      buyXgetYFreePromos.sort((a, b) => (b.promotions.rules.buy || 0) - (a.promotions.rules.buy || 0));
      const bestPromo = buyXgetYFreePromos[0];
      const { buy, get } = bestPromo.promotions.rules;

      if (totalUnits >= buy) {
          const numberOfBonuses = Math.floor(totalUnits / buy) * get;
          bonusText = `Bonificaciones de Regalo:\n- ${numberOfBonuses}x Unidades de regalo (promo ${buy}+${get})`;
      }
  }

  // 3. Build message
  const messageParts = [
    "NUEVO PEDIDO\n",
    `Cliente:\n${clientName}\n`,
    `Productos:\n${itemsText}\n`,
  ];

  if (bonusText) {
    messageParts.push(`${bonusText}\n`);
  }

  messageParts.push(`Total a Pagar:\n$${totalPrice.toLocaleString('es-AR')}`);

  const message = messageParts.join("\n").trim();
  
  return encodeURIComponent(message);
}


export function OrderSummarySheet({
  isOpen,
  onOpenChange,
  clientName,
  availablePromotions
}: {
  isOpen: boolean;
  onOpenChange: (isOpen: boolean) => void;
  clientName: string;
  availablePromotions: AgreementPromotion[];
}) {
  const { items, totalItems, totalPrice } = useCartStore();
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
    const message = formatWhatsAppMessage(clientName, items, totalPrice, availablePromotions, totalItems);
    const whatsappUrl = `https://wa.me/${whatsAppNumber}?text=${message}`;
    window.open(whatsappUrl, "_blank");
  };

  return (
    <Sheet open={isOpen} onOpenChange={onOpenChange}>
      <SheetContent className="flex flex-col w-full sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>Resumen del Pedido</SheetTitle>
          <SheetDescription>
            Confirma tu pedido y envíalo por WhatsApp. Las promociones sugeridas se aplicarán al facturar.
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
                                src={getImageUrl("summary_item", {id: item.product.id, width: 48, height: 48})}
                                alt={item.product.name}
                                width={48}
                                height={48}
                                className="rounded-md object-cover"
                                data-ai-hint="product image"
                            />
                            <div className="flex-grow">
                                <p className="font-medium">{item.product.name}</p>
                                <p className="text-sm text-muted-foreground">
                                {item.quantity} x ${item.product.price.toLocaleString()}
                                </p>
                            </div>
                            <p className="font-semibold">
                                ${(item.quantity * item.product.price).toLocaleString()}
                            </p>
                            </div>
                        ))}
                        </div>
                        <Separator className="my-4" />
                        <div className="flex justify-between font-bold text-lg">
                            <span>Total (precios convenio)</span>
                            <span>${totalPrice.toLocaleString()}</span>
                        </div>
                    </div>
                    
                    <Separator />

                    {/* AI Suggestions */}
                    <IntelligentSuggestions 
                      clientName={clientName} 
                      availablePromotions={availablePromotions}
                    />

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
