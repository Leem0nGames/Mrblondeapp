"use client";

import { useEffect, useState, useTransition } from "react";
import { Lightbulb } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { useCartStore } from "@/hooks/use-cart-store";
import { suggestPromotions, type SuggestPromotionsInput, type SuggestPromotionsOutput } from "@/ai/flows/intelligent-promo-suggestions";
import { Skeleton } from "@/components/ui/skeleton";
import type { AgreementPromotion } from "@/types";

type IntelligentSuggestionsProps = {
    clientName: string;
    availablePromotions: AgreementPromotion[];
}

export function IntelligentSuggestions({ clientName, availablePromotions }: IntelligentSuggestionsProps) {
  const { items, totalItems, isHydrated } = useCartStore();
  const [suggestions, setSuggestions] = useState<SuggestPromotionsOutput | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    // Only run suggestions logic on the client-side after hydration
    if (!isHydrated) {
      return;
    }

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

      const promotionsForAI = availablePromotions.map(ap => ({
        name: ap.promotions.name,
        description: ap.promotions.description || '',
        rules: ap.promotions.rules,
      }));

      const input: SuggestPromotionsInput = {
        items: cartItems,
        total_unidades: totalItems,
        nombre: clientName,
        availablePromotions: promotionsForAI,
      };

      const result = await suggestPromotions(input);
      setSuggestions(result);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [totalItems, isHydrated, clientName, availablePromotions]); // Rerun when totalItems or hydration status changes

  // Don't render anything until the cart is hydrated to avoid mismatch
  if (!isHydrated) {
    return null;
  }

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
