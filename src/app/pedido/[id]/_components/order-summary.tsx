
"use client";

import { useEffect, useTransition } from "react";
import { useCartStore, type CartItem, type BonusInfo } from "@/hooks/use-cart-store";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { ArrowRight, Gift, Truck } from "lucide-react";
import { submitOrder } from "@/app/actions/user.actions";
import type { Promotion } from "@/types";

function formatWhatsAppMessage(
  clientName: string,
  cartItems: CartItem[],
  totalItems: number,
  subtotal: number,
  vatAmount: number,
  totalPrice: number,
  orderId: string,
  appliedPromotions: Promotion[],
  bonusInfo: BonusInfo,
) {
  const itemsText = cartItems
    .map((item) => `- ${item.quantity}x ${item.product.name}`)
    .join("\n");

  const formatCurrency = (value: number) => `$${new Intl.NumberFormat('es-AR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value)}`;

  const messageParts = [
    `✨ NUEVO PEDIDO #${orderId.slice(-4)} ✨\n`,
    `👤 *Cliente:*\n${clientName}\n`,
    `📦 *Productos:* (${totalItems} unidades)\n${itemsText}\n`,
  ];
  
  if (appliedPromotions.length > 0) {
    const bonusText = Object.values(bonusInfo).map(info => 
        `+${info.bonusQuantity} un. de ${info.productName}`
    ).join('\n');

    const promotionsText = appliedPromotions.map(promo => {
        if (promo.rules.type === 'buy_x_get_y_free' && bonusText) {
            return `🎁 *Bonificaciones:*\n${bonusText}`;
        }
        if (promo.rules.type === 'free_shipping') {
            return `🚚 Envío Gratis.`;
        }
        return ``;
    }).filter(Boolean).join('\n\n');

    if (promotionsText) {
      messageParts.push(`${promotionsText}\n`);
    }
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

function AppliedPromotions() {
    const { appliedPromotions, bonusInfo } = useCartStore();

    if (appliedPromotions.length === 0) {
        return null;
    }

    const bonusEntries = Object.values(bonusInfo);

    return (
        <div className="space-y-4 w-full">
            {appliedPromotions.map(promo => {
                if (promo.rules.type === 'buy_x_get_y_free' && bonusEntries.length > 0) {
                    return (
                        <div key={promo.id} className="p-3 bg-primary/10 border border-primary/20 rounded-lg">
                            <div className="flex items-start gap-3">
                                <Gift className="h-6 w-6 text-primary flex-shrink-0 mt-1" />
                                <div>
                                    <p className="font-semibold text-primary">{promo.name}</p>
                                    <p className="text-sm text-muted-foreground">Bonificación aplicada:</p>
                                    <ul className="mt-2 list-disc list-inside text-sm space-y-1">
                                        {bonusEntries.map(info => (
                                            <li key={info.productName}>
                                                <span className="font-bold">+{info.bonusQuantity} un.</span> de {info.productName}
                                            </li>
                                        ))}
                                    </ul>
                                </div>
                            </div>
                        </div>
                    )
                }
                 if (promo.rules.type === 'free_shipping') {
                    return (
                        <div key={promo.id} className="flex items-center gap-3 p-3 bg-primary/10 border border-primary/20 rounded-lg">
                            <Truck className="h-8 w-8 text-primary" />
                            <div>
                                <p className="font-semibold text-primary">{promo.name}</p>
                                <p className="text-sm text-muted-foreground">{promo.description}</p>
                            </div>
                        </div>
                    )
                 }
                return null;
            })}
        </div>
    )
}


export function OrderSummary({
  agreementId,
  clientId,
  clientName,
  pricesIncludeVat,
  promotions,
}: {
  agreementId: string;
  clientId: string;
  clientName: string;
  pricesIncludeVat: boolean;
  promotions: Promotion[];
}) {
  const { items, totalItems, subtotal, vatAmount, totalPrice, clearCart, setAgreement, appliedPromotions, bonusInfo } = useCartStore();
  const { toast } = useToast();
  const [isPending, startTransition] = useTransition();

  const whatsAppNumber =
    process.env.NEXT_PUBLIC_WHATSAPP_NUMBER || "5491123456789";

  useEffect(() => {
    // Set agreement details in the store, which will also trigger a cart reset if the agreement changes.
    setAgreement(agreementId, pricesIncludeVat, promotions);
  }, [agreementId, pricesIncludeVat, promotions, setAgreement]);


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
            result.data.orderId,
            appliedPromotions,
            bonusInfo
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
                      </div>
                  </div>

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
           {hasItems && appliedPromotions.length > 0 && (
            <>
              <Separator />
              <CardFooter className="flex-col items-start gap-4 p-6">
                  <h3 className="font-semibold text-foreground">Promociones Aplicadas</h3>
                  <AppliedPromotions />
              </CardFooter>
            </>
          )}
      </Card>
  );
}
