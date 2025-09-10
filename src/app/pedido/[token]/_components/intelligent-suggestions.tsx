"use client";

import { useEffect, useState, useTransition } from "react";
import { Lightbulb } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { useCartStore } from "@/hooks/use-cart-store";
import { suggestPromotions, type SuggestPromotionsInput, type SuggestPromotionsOutput } from "@/ai/flows/intelligent-promo-suggestions";
import { Skeleton } from "@/components/ui/skeleton";
import type { AccessToken } from "@/types";

export function IntelligentSuggestions({ agreement: agreementProp }: { agreement: SuggestPromotionsInput }) {
  const { items, totalItems } = useCartStore();
  const [suggestions, setSuggestions] = useState<SuggestPromotionsOutput | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    // We only want to show suggestions if there are items in the cart
    if (totalItems > 0) {
      startTransition(async () => {
        const cartItems = items.map(item => ({
          id: item.product.id,
          quantity: item.quantity,
          name: item.product.name,
        }));

        const result = await suggestPromotions({
          ...agreementProp,
          items: cartItems,
          total_unidades: totalItems
        });
        setSuggestions(result);
      });
    } else {
      setSuggestions(null);
    }
  }, [totalItems, items, agreementProp]);

  if (isPending) {
    return (
        <div className="space-y-2">
            <Skeleton className="h-4 w-1/4" />
            <Skeleton className="h-10 w-full" />
        </div>
    )
  }

  if (!suggestions || suggestions.promotionSuggestions.length === 0) {
    return null;
  }

  return (
    <Alert>
        <Lightbulb className="h-4 w-4" />
        <AlertTitle>¡Sugerencia Inteligente!</AlertTitle>
        <AlertDescription>
            <ul className="list-disc pl-5 space-y-1 mt-2">
            {suggestions.promotionSuggestions.map((promo) => (
                <li key={promo.name}>
                    <strong>{promo.name}:</strong> {promo.reason}
                </li>
            ))}
            </ul>
      </AlertDescription>
    </Alert>
  );
}
