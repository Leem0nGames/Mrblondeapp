"use client";

import { useCartStore, type CartItem } from "@/hooks/use-cart-store";
import type { AgreementPromotion } from "@/types";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { ArrowRight, ShoppingCart } from "lucide-react";
import { PromotionFeedback } from "./promotion-feedback";


function formatWhatsAppMessage(
  clientName: string,
  cartItems: CartItem[],
  totalPrice: number,
  promotions: AgreementPromotion[],
  totalUnits: number,
) {
  const itemsText = cartItems
    .map((item) => `- ${item.quantity}x ${item.product.name}`)
    .join("\n");

  let bonusText = "";
  const buyXgetYFreePromos = promotions.filter(
    (p) => p.promotions.rules?.type === "buy_x_get_y_free"
  );
  
  if (buyXgetYFreePromos.length > 0) {
      buyXgetYFreePromos.sort((a, b) => (b.promotions.rules.buy || 0) - (a.promotions.rules.buy || 0));
      const bestPromo = buyXgetYFreePromos[0];
      
      if (bestPromo && bestPromo.promotions.rules.buy > 0) {
        const { buy, get } = bestPromo.promotions.rules;
        if (totalUnits >= buy) {
            const numberOfBonuses = Math.floor(totalUnits / buy) * get;
            // Sort items by price to find the cheapest one for the bonus
            const sortedItems = [...cartItems].sort((a, b) => a.product.price - b.product.price);
            const cheapestItem = sortedItems[0];
            
            if (numberOfBonuses > 0 && cheapestItem) {
              bonusText = `Bonificaciones de Regalo:\n- ${numberOfBonuses}x ${cheapestItem.product.name} (promo ${buy}+${get})`;
            }
        }
      }
  }

  const messageParts = [
    "✨ NUEVO PEDIDO ✨\n",
    `👤 *Cliente:*\n${clientName}\n`,
    `📦 *Productos:* (${totalUnits} unidades)\n${itemsText}\n`,
  ];

  if (bonusText) {
    messageParts.push(`🎁 *${bonusText}*\n`);
  }

  messageParts.push(`💰 *Total a Pagar:*\n$${totalPrice.toLocaleString('es-AR')}`);

  const message = messageParts.join("\n").trim();
  
  return encodeURIComponent(message);
}


export function OrderSummary({
  clientName,
  availablePromotions,
}: {
  clientName: string;
  availablePromotions: AgreementPromotion[];
}) {
  const { items, totalItems, totalPrice } = useCartStore();
  const { toast } = useToast();
  const whatsAppNumber =
    process.env.NEXT_PUBLIC_WHATSAPP_NUMBER || "5491123456789";


  const handleSend = () => {
    if (items.length === 0) {
      toast({
        title: "Carrito vacío",
        description: "Agrega productos antes de enviar el pedido.",
        variant: "destructive",
      });
      return;
    }
    const message = formatWhatsAppMessage(
      clientName,
      items,
      totalPrice,
      availablePromotions,
      totalItems
    );
    const whatsappUrl = `https://wa.me/${whatsAppNumber}?text=${message}`;
    window.open(whatsappUrl, "_blank");
  };

  const hasItems = items.length > 0;

  return (
    <div className="sticky top-16 z-30 bg-background/90 backdrop-blur-sm -mx-4 -mt-4 lg:-mx-8 lg:-mt-8 mb-8">
        <div className="container mx-auto p-4">
            <Card>
                 <CardHeader>
                    <CardTitle>Resumen de Pedido</CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="flex flex-col gap-4">
                        <div className="flex flex-wrap items-center justify-between gap-4">
                            <div className="flex items-baseline gap-6">
                                <div className="text-center">
                                    <p className="text-2xl font-bold">{totalItems}</p>
                                    <p className="text-sm text-muted-foreground">Unidades</p>
                                </div>
                                <div className="text-center">
                                    <p className="text-2xl font-bold">${totalPrice.toLocaleString()}</p>
                                    <p className="text-sm text-muted-foreground">Total</p>
                                </div>
                            </div>
                            <Button
                                onClick={handleSend}
                                size="lg"
                                className="w-full sm:w-auto"
                                disabled={!hasItems}
                            >
                                <span>Enviar Pedido</span>
                                <ArrowRight className="ml-2 h-4 w-4" />
                            </Button>
                        </div>
                        {hasItems && availablePromotions.length > 0 && (
                            <>
                                <Separator />
                                <PromotionFeedback promotions={availablePromotions} totalItems={totalItems} />
                            </>
                        )}
                    </div>
                </CardContent>
            </Card>
        </div>
    </div>
  );
}
