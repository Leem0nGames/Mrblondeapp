
"use client";

import { useEffect, useMemo, useTransition } from "react";
import { useCartStore, type CartItem } from "@/hooks/use-cart-store";
import type { AgreementPromotion } from "@/types";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { ArrowRight, Truck, Gift } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { submitOrder } from "@/app/actions/user.actions";


// Helper function to parse promotion rules safely
function parseBuyXGetYPromo(promo: AgreementPromotion) {
  const rules = promo.promotions.rules;
  if (rules?.type === 'buy_x_get_y_free') {
    const buy = Number(rules.buy);
    const get = Number(rules.get);
    if (!isNaN(buy) && buy > 0 && !isNaN(get) && get > 0) {
      return { buy, get, name: promo.promotions.name };
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


// This function calculates total bonuses based on sorted promotions for each item
function calculateTotalBonuses(promos: AgreementPromotion[], items: CartItem[]): { total: number; cheapestItem: CartItem | null, appliedPromos: { name: string, units: number }[] } {
    const buyXGetYPromos = promos
      .map(parseBuyXGetYPromo)
      .filter((p): p is NonNullable<ReturnType<typeof parseBuyXGetYPromo>> => p !== null)
      .sort((a, b) => b.buy - a.buy); // Highest requirement first

    if (buyXGetYPromos.length === 0 || items.length === 0) {
      return { total: 0, cheapestItem: null, appliedPromos: [] };
    }

    let totalBonuses = 0;
    const appliedPromos: { name: string, units: number }[] = [];
    
    // Calculate bonuses for each item line
    items.forEach(item => {
        const applicablePromo = buyXGetYPromos.find(p => item.quantity >= p.buy);
        if (applicablePromo) {
            const times = Math.floor(item.quantity / applicablePromo.buy);
            const bonusUnits = times * applicablePromo.get;
            totalBonuses += bonusUnits;

            const existingPromo = appliedPromos.find(p => p.name === applicablePromo.name);
            if (existingPromo) {
                existingPromo.units += bonusUnits;
            } else {
                appliedPromos.push({ name: applicablePromo.name, units: bonusUnits });
            }
        }
    });

    const cheapestItem = [...items].sort((a, b) => a.product.price - b.product.price)[0];

    return { total: totalBonuses, cheapestItem, appliedPromos };
}

function formatWhatsAppMessage(
  clientName: string,
  cartItems: CartItem[],
  totalItems: number,
  subtotal: number,
  vatAmount: number,
  totalPrice: number,
  promotions: AgreementPromotion[],
  orderId: string
) {
  const itemsText = cartItems
    .map((item) => `- ${item.quantity}x ${item.product.name}`)
    .join("\n");

  let bonusText = "";
  const { total: totalBonuses, cheapestItem } = calculateTotalBonuses(promotions, cartItems);

  if (totalBonuses > 0 && cheapestItem) {
      bonusText = `*Bonificaciones de Regalo:*\n- ${totalBonuses}x ${cheapestItem.product.name}`;
  }

  let shippingText = "";
  const freeShippingPromo = promotions.map(parseFreeShippingPromo).find(p => p !== null);
  if (freeShippingPromo && totalItems >= freeShippingPromo.min_units) {
    shippingText = `*Envío Bonificado*\n`;
  }

  const formatCurrency = (value: number) => `$${new Intl.NumberFormat('es-AR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value)}`;

  const messageParts = [
    `✨ NUEVO PEDIDO #${orderId.slice(-4)} ✨\n`,
    `👤 *Cliente:*\n${clientName}\n`,
    `📦 *Productos:* (${totalItems} unidades)\n${itemsText}\n`,
  ];

  if (bonusText) {
    messageParts.push(`🎁 ${bonusText}\n`);
  }
    
  if(shippingText) {
    messageParts.push(`🚚 ${shippingText}\n`);
  }
  
  messageParts.push(
    `*Resumen de Pago:*\n` +
    `Subtotal: ${formatCurrency(subtotal)}\n` +
    `IVA (21%): ${formatCurrency(vatAmount)}\n` +
    `*Total a Pagar: ${formatCurrency(totalPrice)}*`
  );

  const message = messageParts.join("\n").trim();
  
  return encodeURIComponent(message);
}


export function OrderSummary({
  agreementId,
  clientId,
  clientName,
  availablePromotions,
  pricesIncludeVat,
}: {
  agreementId: string;
  clientId: string;
  clientName: string;
  availablePromotions: AgreementPromotion[];
  pricesIncludeVat: boolean;
}) {
  const { items, totalItems, subtotal, vatAmount, totalPrice, clearCart, agreementId: storedAgreementId, setAgreement } = useCartStore();
  const { toast } = useToast();
  const [isPending, startTransition] = useTransition();

  const whatsAppNumber =
    process.env.NEXT_PUBLIC_WHATSAPP_NUMBER || "5491123456789";

  useEffect(() => {
    if (storedAgreementId !== agreementId) {
      clearCart();
    }
    setAgreement(agreementId, pricesIncludeVat);
  }, [agreementId, pricesIncludeVat, storedAgreementId, clearCart, setAgreement]);


  const handleSend = () => {
    if (items.length === 0) {
      toast({
        title: "Carrito vacío",
        description: "Agrega productos antes de enviar el pedido.",
        variant: "destructive",
      });
      return;
    }

    startTransition(async () => {
        const result = await submitOrder({
            cart: items,
            total: totalPrice,
            agreementId,
            clientId,
            clientName
        });

        if (result.error || !result.data) {
            toast({
                title: "Error al guardar el pedido",
                description: result.error.message,
                variant: "destructive",
            });
            return;
        }

        const message = formatWhatsAppMessage(
            clientName,
            items,
            totalItems,
            subtotal,
            vatAmount,
            totalPrice,
            availablePromotions,
            result.data.orderId
        );
        const whatsappUrl = `https://wa.me/${whatsAppNumber}?text=${message}`;
        window.open(whatsappUrl, "_blank");

        // Clear cart on success
        clearCart();
        toast({
            title: "Pedido enviado!",
            description: "Tu pedido se ha registrado y enviado por WhatsApp.",
        });
    });
  };

  const hasItems = items.length > 0;
  
  const freeShippingPromo = useMemo(() => {
    const promos = availablePromotions.map(parseFreeShippingPromo).filter((p): p is NonNullable<typeof p> => p !== null);
    return promos.length > 0 ? promos[0] : null;
  }, [availablePromotions]);

  const bonuses = useMemo(() => {
    return calculateTotalBonuses(availablePromotions, items);
  }, [availablePromotions, items]);
  
  const hasFreeShipping = freeShippingPromo && totalItems >= freeShippingPromo.min_units;
  const itemsForFreeShipping = freeShippingPromo ? freeShippingPromo.min_units - totalItems : 0;
  
  const formatCurrency = (value: number) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS' }).format(value);

  return (
    <Card>
          <CardHeader>
              <CardTitle>Resumen de Pedido</CardTitle>
              {hasItems && <CardDescription>Revisa tu pedido y envíalo cuando estés listo.</CardDescription>}
          </CardHeader>
          <CardContent>
              {hasItems ? (
              <div className="flex flex-col gap-4">
                  <div className="space-y-2 text-sm">
                      <div className="flex justify-between">
                          <span className="text-muted-foreground">Subtotal</span>
                          <span>{formatCurrency(subtotal)}</span>
                      </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">IVA (21%)</span>
                          <span>{formatCurrency(vatAmount)}</span>
                      </div>
                      <Separator />
                      <div className="flex justify-between font-bold text-base">
                          <span>Total</span>
                          <span>{formatCurrency(totalPrice)}</span>
                      </div>
                        <div className="flex justify-between items-center text-sm">
                          <span className="text-muted-foreground">{totalItems} Unidades</span>
                          {freeShippingPromo && (
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
                  </div>

                  {bonuses.appliedPromos.length > 0 && (
                    <>
                      <Separator />
                      <div className="space-y-2">
                        <h4 className="text-sm font-medium flex items-center gap-2">
                            <Gift className="h-4 w-4 text-primary" />
                            Bonificaciones Obtenidas
                        </h4>
                        <div className="space-y-1 text-sm text-muted-foreground">
                            {bonuses.appliedPromos.map(promo => (
                                <div key={promo.name} className="flex justify-between">
                                    <span>{promo.name}</span>
                                    <span className="font-medium text-foreground">+{promo.units} un. de regalo</span>
                                </div>
                            ))}
                        </div>
                      </div>
                    </>
                  )}


                  <Separator />
                  <Button
                      onClick={handleSend}
                      size="lg"
                      className="w-full"
                      disabled={isPending}
                  >
                      {isPending ? "Procesando..." : "Enviar Pedido por WhatsApp"}
                      <ArrowRight className="ml-2 h-4 w-4" />
                  </Button>
              </div>
                ) : (
                  <p className="text-center text-muted-foreground py-4">Tu carrito está vacío.</p>
              )}
          </CardContent>
      </Card>
  );
}
