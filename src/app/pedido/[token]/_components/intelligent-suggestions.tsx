"use client";

import { useEffect, useState, useTransition } from "react";
import { Lightbulb } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { useCartStore } from "@/hooks/use-cart-store";
import { suggestPromotions, type SuggestPromotionsInput, type SuggestPromotionsOutput } from "@/ai/flows/intelligent-promo-suggestions";
import { Skeleton } from "@/components/ui/skeleton";
import type { Agreement } from "@/types";

type IntelligentSuggestionsProps = {
    agreement: Pick<Agreement, "client_type" | "id">,
    clientName: string,
}

export function IntelligentSuggestions({ agreement, clientName }: IntelligentSuggestionsProps) {
  const { items, totalItems } = useCartStore();
  const [suggestions, setSuggestions] = useState<SuggestPromotionsOutput | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    startTransition(async () => {
      const cartItems = items.map(item => ({
        id: item.product.id,
        quantity: item.quantity,
        name: item.product.name,
      }));

      const input: SuggestPromotionsInput = {
        items: cartItems,
        type: agreement.client_type,
        agreement_id: agreement.id,
        total_unidades: totalItems,
        nombre: clientName,
        // Hardcoded for now, as we removed the address form.
        // In a real app, this could come from the client's profile.
        ciudad: "CABA",
      };

      const result = await suggestPromotions(input);
      setSuggestions(result);
    });
  }, [totalItems, items, agreement, clientName]);

  if (isPending && totalItems > 0) {
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
