
"use client";

import { useEffect, useTransition } from "react";
import { useCartStore, type CartItem } from "@/hooks/use-cart-store";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { ArrowRight } from "lucide-react";
import { submitOrder } from "@/app/actions/user.actions";

function formatWhatsAppMessage(
  clientName: string,
  cartItems: CartItem[],
  totalItems: number,
  subtotal: number,
  vatAmount: number,
  totalPrice: number,
  orderId: string
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
  pricesIncludeVat,
}: {
  agreementId: string;
  clientId: string;
  clientName: string;
  pricesIncludeVat: boolean;
}) {
  const { items, totalItems, subtotal, vatAmount, totalPrice, clearCart, setAgreement } = useCartStore();
  const { toast } = useToast();
  const [isPending, startTransition] = useTransition();

  const whatsAppNumber =
    process.env.NEXT_PUBLIC_WHATSAPP_NUMBER || "5491123456789";

  useEffect(() => {
    // Set agreement details in the store, which will also trigger a cart reset if the agreement changes.
    setAgreement(agreementId, pricesIncludeVat);
  }, [agreementId, pricesIncludeVat, setAgreement]);


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
      </Card>
  );
}
