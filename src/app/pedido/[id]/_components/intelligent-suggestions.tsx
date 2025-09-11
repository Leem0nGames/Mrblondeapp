
"use client";

import { useEffect, useMemo } from "react";
import { useCartStore } from "@/hooks/use-cart-store";
import type { AgreementPromotion, SuggestPromotionsInput } from "@/types";
import { suggestPromotions } from "@/ai/flows/intelligent-promo-suggestions";
import { useActionState } from "react";
import { Skeleton } from "@/components/ui/skeleton";
import { Lightbulb } from "lucide-react";

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

export default function IntelligentSuggestions({
  clientName,
  availablePromotions,
}: {
  clientName: string;
  availablePromotions: AgreementPromotion[];
}) {
  const { items, totalItems } = useCartStore();
  
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
    const handler = setTimeout(() => {
      if (totalItems > 0) {
        formAction(intelligentSuggestionsInput);
      }
    }, 500);

    return () => {
      clearTimeout(handler);
    };
  }, [intelligentSuggestionsInput, formAction, totalItems]);


  if (totalItems === 0) {
    return null;
  }
  
  return (
    <div className="mt-6">
        <h3 className="text-lg font-medium mb-2 flex items-center gap-2">
          <Lightbulb className="text-primary"/>
          Sugerencias Inteligentes
        </h3>
        {isPending && (
          <div className="space-y-2 p-4 border rounded-lg">
              <Skeleton className="h-4 w-3/4" />
              <Skeleton className="h-4 w-1/2" />
          </div>
      )}
      {state.error && <p className="text-sm text-destructive p-4 border-destructive/50 border rounded-lg">{state.error}</p>}
      
      {state.suggestions && state.suggestions.length > 0 && !isPending && (
          <ul className="space-y-3 text-sm">
              {state.suggestions.map(sugg => (
                  <li key={sugg.name} className="p-3 bg-secondary/50 rounded-lg border">
                      <p className="font-semibold">{sugg.name}</p>
                      <p className="text-muted-foreground">{sugg.reason}</p>
                  </li>
              ))}
          </ul>
      )}
    </div>
  );
}

