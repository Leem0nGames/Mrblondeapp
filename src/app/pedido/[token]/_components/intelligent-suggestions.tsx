
"use client";

import { useEffect, useState, useTransition } from "react";
import { Lightbulb } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { useCartStore } from "@/hooks/use-cart-store";
import { suggestPromotions, type SuggestPromotionsInput, type SuggestPromotionsOutput } from "@/ai/flows/intelligent-promo-suggestions";
import { Skeleton } from "@/components/ui/skeleton";
import type { AgreementPromotion, AccessToken } from "@/types";

type IntelligentSuggestionsProps = {
    accessToken: AccessToken
}

export function IntelligentSuggestions({ accessToken }: IntelligentSuggestionsProps) {
  const { items, totalItems } = useCartStore();
  const [suggestions, setSuggestions] = useState<SuggestPromotionsOutput | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    // No need to run on initial mount if cart is empty
    if (totalItems === 0) {
      setSuggestions(null); // Clear previous suggestions
      return;
    };
    
    startTransition(async () => {
      const cartItems = items.map(item => ({
        id: item.product.id,
        quantity: item.quantity,
        name: item.product.name,
      }));

      const availablePromotions = accessToken.agreement.agreement_promotions.map(ap => ({
        name: ap.promotions.name,
        description: ap.promotions.description || '',
        rules: ap.promotions.rules,
      }));

      const input: SuggestPromotionsInput = {
        items: cartItems,
        total_unidades: totalItems,
        nombre: accessToken.client_name,
        availablePromotions,
      };

      const result = await suggestPromotions(input);
      setSuggestions(result);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [totalItems, accessToken]); // Rerun when totalItems or accessToken changes.

  if (isPending) {
    return (
        <div className="space-y-2 rounded-lg border bg-background p-4">
            <Skeleton className="h-5 w-1/3" />
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-4/5" />
        </div>
    )
  }

  if (!suggestions || suggestions.promotionSuggestions.length === 0) {
    return null;
  }

  return (
    <Alert className="bg-primary/10 border-primary/50">
        <Lightbulb className="h-4 w-4 text-primary" />
        <AlertTitle className="text-primary">¡Sugerencias para tu Pedido!</AlertTitle>
        <AlertDescription>
            <ul className="list-disc pl-5 space-y-2 mt-2">
            {suggestions.promotionSuggestions.map((promo) => (
                <li key={promo.name}>
                    <strong className="font-semibold">{promo.name}:</strong> {promo.reason}
                    <p className="text-xs text-muted-foreground pl-1">{promo.description}</p>
                </li>
            ))}
            </ul>
      </AlertDescription>
    </Alert>
  );
}

    