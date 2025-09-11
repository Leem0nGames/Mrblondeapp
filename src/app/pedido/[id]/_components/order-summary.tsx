
"use client";

import { useEffect, useMemo } from "react";
import { useCartStore, type CartItem } from "@/hooks/use-cart-store";
import type { AgreementPromotion, SuggestPromotionsInput } from "@/types";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { AlertCircle, ArrowRight, ShoppingCart } from "lucide-react";
import { suggestPromotions } from "@/ai/flows/intelligent-promo-suggestions";
import { useActionState } from "react";
import { Skeleton } from "@/components/ui/skeleton";

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

async function getSuggestions(
  prevState: any,
  formData: SuggestPromotionsInput
) {
  try {
    const result = await suggestPromotions(formData);
    return { suggestions: result.promotionSuggestions, error: null };
  } catch (e: any) {
    console.error("Error fetching suggestions:", e.message);
    return {
      suggestions: [],
      error: "No se pudieron cargar las sugerencias de la IA.",
    };
  }
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

  const [state, formAction, isPending] = useActionState(getSuggestions, {
    suggestions: [],
    error: null,
  });

  const intelligentSuggestionsInput = useMemo<SuggestPromotionsInput>(() => ({
      items: items.map(item => ({
          id: item.product.id,
          quantity: item.quantity,
          name: item.product.name,
      })),
      total_unidades: totalItems,
      nombre: clientName,
      availablePromotions: availablePromotions.map(ap => ap.promotions)
  }), [items, totalItems, clientName, availablePromotions]);


  useEffect(() => {
    // Debounce the call to the AI to avoid too many requests
    const handler = setTimeout(() => {
      if (totalItems > 0) {
        formAction(intelligentSuggestionsInput);
      }
    }, 500); // 500ms delay

    return () => {
      clearTimeout(handler);
    };
  }, [intelligentSuggestionsInput, formAction, totalItems]);


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
                    {!hasItems && (
                        <CardDescription>
                            Comienza a agregar productos para ver el resumen aquí.
                        </CardDescription>
                    )}
                </CardHeader>
                <CardContent>
                    {hasItems ? (
                        <>
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                                <div className="md:col-span-2 space-y-4">
                                    <h3 className="font-semibold text-lg">Sugerencias Inteligentes</h3>
                                     {isPending && (
                                        <div className="space-y-2">
                                            <Skeleton className="h-4 w-3/4" />
                                            <Skeleton className="h-4 w-1/2" />
                                        </div>
                                    )}
                                    {state.error && <p className="text-sm text-destructive">{state.error}</p>}
                                    
                                    {state.suggestions && state.suggestions.length > 0 ? (
                                        <ul className="space-y-3 text-sm">
                                            {state.suggestions.map(sugg => (
                                                <li key={sugg.name} className="p-3 bg-secondary/50 rounded-lg">
                                                    <p className="font-semibold">{sugg.name}</p>
                                                    <p className="text-muted-foreground">{sugg.reason}</p>
                                                </li>
                                            ))}
                                        </ul>
                                    ) : !isPending && (
                                        <p className="text-sm text-muted-foreground">No hay sugerencias por el momento.</p>
                                    )}
                                </div>
                                <div className="space-y-4">
                                    <div className="space-y-2">
                                        <div className="flex justify-between">
                                            <span className="text-muted-foreground">Total de Unidades:</span>
                                            <span className="font-bold">{totalItems}</span>
                                        </div>
                                        <Separator />
                                        <div className="flex justify-between text-xl">
                                            <span className="font-semibold">Total a Pagar:</span>
                                            <span className="font-bold">${totalPrice.toLocaleString()}</span>
                                        </div>
                                    </div>
                                     <Button
                                        onClick={handleSend}
                                        size="lg"
                                        className="w-full"
                                    >
                                        <span>Enviar Pedido por WhatsApp</span>
                                        <ArrowRight className="ml-2 h-4 w-4" />
                                    </Button>
                                </div>
                            </div>
                        </>
                    ) : (
                         <div className="text-center py-8 text-muted-foreground">
                            <ShoppingCart className="mx-auto h-12 w-12" />
                            <p className="mt-4 font-semibold">Tu pedido está vacío</p>
                        </div>
                    )}
                </CardContent>
            </Card>
        </div>
    </div>
  );
}

