"use client";

import { useMemo } from "react";
import type { AgreementPromotion } from "@/types";
import { Progress } from "@/components/ui/progress";
import { Gift, TrendingUp } from "lucide-react";

export function PromotionFeedback({
  promotions,
  totalItems,
}: {
  promotions: AgreementPromotion[];
  totalItems: number;
}) {
  // Find the best "buy X get Y free" promotion (the one with the highest "buy" threshold)
  const bestPromo = useMemo(() => {
    return promotions
      .filter((p) => p.promotions.rules?.type === "buy_x_get_y_free")
      .sort((a, b) => (b.promotions.rules.buy || 0) - (a.promotions.rules.buy || 0))[0];
  }, [promotions]);

  if (!bestPromo) {
    return null;
  }

  const { buy, get } = bestPromo.promotions.rules;
  const progress = Math.min((totalItems / buy) * 100, 100);
  const isPromoActive = totalItems >= buy;
  const itemsRemaining = buy - totalItems;

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 text-sm font-medium">
        {isPromoActive ? (
          <Gift className="h-4 w-4 text-primary" />
        ) : (
          <TrendingUp className="h-4 w-4 text-muted-foreground" />
        )}
        <p>
          {bestPromo.promotions.name} ({buy} + {get})
        </p>
      </div>

      <Progress value={progress} className="h-2" />

      <p className="text-xs text-muted-foreground">
        {isPromoActive ? (
          `¡Promo aplicada! Tienes ${Math.floor(totalItems / buy) * get} unidad(es) de regalo.`
        ) : (
          `Agrega ${itemsRemaining} unidad(es) más para activar la promoción.`
        )}
      </p>
    </div>
  );
}
