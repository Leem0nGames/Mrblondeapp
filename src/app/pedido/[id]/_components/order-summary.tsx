
"use client";

import { useEffect, useMemo } from "react";
import { useCartStore, type CartItem } from "@/hooks/use-cart-store";
import type { AgreementPromotion } from "@/types";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { ArrowRight, Truck } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";


// Helper function to parse promotion rules safely
function parseBuyXGetYPromo(promo: AgreementPromotion) {
  const rules = promo.promotions.rules;
  if (rules?.type === 'buy_x_get_y_free') {
    const buy = Number(rules.buy);
    const get = Number(rules.get);
    if (!isNaN(buy) && buy > 0 && !isNaN(get) && get > 0) {
      return { buy, get };
    }
  }
  return null;
}

function parseFreeShippingPromo(promo: AgreementPromotion) {
  const rules = promo.promotions.rules;
  if (rules?.type === 'free_shipping') {
    const min_units = Number(rules.min_units);
    if (!isNaN(min_units) && min_units > 0) {
      return { min_units };
    }
  }
  return null;
}


// Función para calcular el total de bonificaciones de forma inteligente
function calculateTotalBonuses(promos: AgreementPromotion[], totalItems: number) {
    const sortedPromos = promos
      .map(p => parseBuyXGetYPromo(p))
      .filter((p): p is NonNullable<typeof p> => p !== null)
      .sort((a, b) => b.buy - a.buy); // Ordenar de mayor a menor requisito (importante)

    let remainingItems = totalItems;
    let totalBonuses = 0;

    for (const promo of sortedPromos) {
        if (remainingItems >= promo.buy) {
            const times = Math.floor(remainingItems / promo.buy);
            totalBonuses += times * promo.get;
            remainingItems %= promo.buy; // Actualizar los items restantes para la siguiente promo
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

  let shippingText = "";
  const freeShippingPromo = promotions.map(parseFreeShippingPromo).find(p => p !== null);
  if (freeShippingPromo && totalUnits >= freeShippingPromo.min_units) {
    shippingText = `*Envío Bonificado*\n`;
  }


  const messageParts = [
    "✨ NUEVO PEDIDO ✨\n",
    `👤 *Cliente:*\n${clientName}\n`,
    `📦 *Productos:* (${totalUnits} unidades)\n${itemsText}\n`,
  ];

  if (bonusText) {
    messageParts.push(`🎁 ${bonusText}\n`);
  }
    
  if(shippingText) {
    messageParts.push(`🚚 ${shippingText}\n`);
  }

  messageParts.push(`💰 *Total a Pagar:*\n$${totalPrice.toLocaleString('es-AR')}`);

  const message = messageParts.join("\n").trim();
  
  return encodeURIComponent(message);
}


export function OrderSummary({
  agreementId,
  clientName,
  availablePromotions,
}: {
  agreementId: string;
  clientName: string;
  availablePromotions: AgreementPromotion[];
}) {
  const { items, totalItems, totalPrice, clearCart, agreementId: storedAgreementId, setAgreementId } = useCartStore();
  const { toast } = useToast();
  const whatsAppNumber =
    process.env.NEXT_PUBLIC_WHATSAPP_NUMBER || "5491123456789";

  useEffect(() => {
    // Si el ID del convenio actual es diferente al guardado en el carrito, se limpia.
    if (storedAgreementId && storedAgreementId !== agreementId) {
      clearCart();
    }
    // Siempre se establece el ID del convenio actual en el store.
    setAgreementId(agreementId);
  }, [agreementId, storedAgreementId, clearCart, setAgreementId]);


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
  
  const freeShippingPromo = useMemo(() => {
    const promos = availablePromotions.map(parseFreeShippingPromo).filter((p): p is NonNullable<typeof p> => p !== null);
    return promos.length > 0 ? promos[0] : null;
  }, [availablePromotions]);
  
  const hasFreeShipping = freeShippingPromo && totalItems >= freeShippingPromo.min_units;
  const itemsForFreeShipping = freeShippingPromo ? freeShippingPromo.min_units - totalItems : 0;


  return (
    <div className="sticky top-0 z-30 bg-background/90 backdrop-blur-sm -mx-4 lg:-mx-8 mb-8">
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
                                {freeShippingPromo && hasItems && (
                                  <TooltipProvider>
                                    <Tooltip>
                                        <TooltipTrigger>
                                            <Badge variant={hasFreeShipping ? "default" : "secondary"}>
                                                <Truck className="h-4 w-4 mr-1"/>
                                                {hasFreeShipping ? "Envío Gratis" : "Envío"}
                                            </Badge>
                                        </TooltipTrigger>
                                        {!hasFreeShipping && itemsForFreeShipping > 0 && (
                                            <TooltipContent>
                                                <p>Agrega {itemsForFreeShipping} unidades más para envío gratis.</p>
                                            </TooltipContent>
                                        )}
                                    </Tooltip>
                                   </TooltipProvider>
                                )}
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
                    </div>
                </CardContent>
            </Card>
        </div>
    </div>
  );
}

