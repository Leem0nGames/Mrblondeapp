"use client";

import { useCartStore, type CartItem } from "@/hooks/use-cart-store";
import type { AgreementPromotion } from "@/types";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { ArrowRight, ShoppingCart } from "lucide-react";
import { PromotionFeedback } from "./promotion-feedback";

// Función para calcular el total de bonificaciones (debe ser la misma que en PromotionFeedback)
function calculateTotalBonuses(promos: AgreementPromotion[], totalItems: number) {
    const sortedPromos = promos
      .filter(p => p.promotions.rules?.type === 'buy_x_get_y_free' && Number(p.promotions.rules.buy) > 0)
      .map(p => ({
          buy: Number(p.promotions.rules.buy),
          get: Number(p.promotions.rules.get)
      }))
      .sort((a, b) => b.buy - a.buy); // Ordenar de mayor a menor requisito

    let remainingItems = totalItems;
    let totalBonuses = 0;

    for (const promo of sortedPromos) {
        if (remainingItems >= promo.buy) {
            const times = Math.floor(remainingItems / promo.buy);
            totalBonuses += times * promo.get;
            remainingItems %= promo.buy;
        }
    }
    return totalBonuses;
}

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
  const totalBonuses = calculateTotalBonuses(promotions, totalUnits);

  if (totalBonuses > 0) {
      // Regla de negocio: el producto de regalo es el más barato del carrito
      const sortedItems = [...cartItems].sort((a, b) => a.product.price - b.product.price);
      const cheapestItem = sortedItems[0];
      
      if (cheapestItem) {
        bonusText = `*Bonificaciones de Regalo:*\n- ${totalBonuses}x ${cheapestItem.product.name}`;
      }
  }


  const messageParts = [
    "✨ NUEVO PEDIDO ✨\n",
    `👤 *Cliente:*\n${clientName}\n`,
    `📦 *Productos:* (${totalUnits} unidades)\n${itemsText}\n`,
  ];

  if (bonusText) {
    messageParts.push(`🎁 ${bonusText}\n`);
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
  const hasBuyXGetYPromos = availablePromotions.some(p => p.promotions.rules?.type === 'buy_x_get_y_free');

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
                        {hasItems && hasBuyXGetYPromos && (
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
