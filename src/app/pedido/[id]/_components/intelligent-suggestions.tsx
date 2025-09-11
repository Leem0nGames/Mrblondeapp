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
  const { items, totalItems } = useCartStore();
  const [suggestions, setSuggestions] = useState<SuggestPromotionsOutput | null>(null);
  const [isPending, startTransition] = useTransition();
  const [isClient, setIsClient] = useState(false);

  useEffect(() => {
    setIsClient(true);
  }, []);

  useEffect(() => {
    if (!isClient) return;

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
  }, [totalItems, isClient, clientName]);

  if (!isClient && totalItems > 0) { // Only show skeleton on client if cart has items
    return (
      <div className="space-y-2 rounded-lg border bg-background p-4">
        <Skeleton className="h-5 w-1/3" />
        <Skeleton className="h-4 w-full" />
        <Skeleton className="h-4 w-4/5" />
      </div>
    );
  }

  if (isPending) {
    return (
        <div className="space-y-2 rounded-lg border bg-background p-4">
            <div className="flex items-center gap-2">
                <Skeleton className="h-5 w-5 rounded-full" />
                <Skeleton className="h-5 w-1/3" />
            </div>
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-4/5" />
        </div>
    )
  }

  if (!suggestions || suggestions.promotionSuggestions.length === 0) {
    return null;
  }

  return (
    <Alert className="bg-primary/10 border-primary/20">
        <Lightbulb className="h-4 w-4 text-primary" />
        <AlertTitle className="text-primary font-bold">¡Sugerencias para tu Pedido!</AlertTitle>
        <AlertDescription>
            <ul className="list-disc pl-5 mt-2 space-y-3">
            {suggestions.promotionSuggestions.map((promo, index) => (
                <li key={index}>
                    <strong className="font-semibold">{promo.name}:</strong> {promo.reason}
                    <p className="text-xs text-muted-foreground pl-1 italic">({promo.description})</p>
                </li>
            ))}
            </ul>
      </AlertDescription>
    </Alert>
  );
}
