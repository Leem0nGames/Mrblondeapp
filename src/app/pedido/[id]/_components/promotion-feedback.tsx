"use client";

import { useMemo } from "react";
import type { AgreementPromotion } from "@/types";
import { Progress } from "@/components/ui/progress";
import { Gift, TrendingUp } from "lucide-react";

// Función para obtener la próxima promoción objetivo
function getNextPromoGoal(promos: AgreementPromotion[], totalItems: number) {
  const sortedPromos = promos
    .filter(p => p.promotions.rules?.type === 'buy_x_get_y_free' && Number(p.promotions.rules.buy) > 0)
    .map(p => ({
        ...p,
        buy: Number(p.promotions.rules.buy),
        get: Number(p.promotions.rules.get)
    }))
    .sort((a, b) => a.buy - b.buy);

  // Encontrar la promoción más cercana que el usuario aún no ha alcanzado
  const nextGoal = sortedPromos.find(p => totalItems < p.buy);
  
  // Si no hay un próximo objetivo (el usuario ha superado todas las promos),
  // devolver la promoción más alta como referencia.
  return nextGoal || sortedPromos[sortedPromos.length - 1] || null;
}

// Función para calcular el total de bonificaciones
function calculateTotalBonuses(promos: AgreementPromotion[], totalItems: number) {
    const sortedPromos = promos
      .filter(p => p.promotions.rules?.type === 'buy_x_get_y_free' && Number(p.promotions.rules.buy) > 0)
      .map(p => ({
          buy: Number(p.promotions.rules.buy),
          get: Number(p.promotions.rules.get)
      }))
      .sort((a, b) => b.buy - a.buy); // Ordenar de mayor a menor requisito

    let remainingItems = totalItems;
    let totalBonuses = 0;

    for (const promo of sortedPromos) {
        if (remainingItems >= promo.buy) {
            const times = Math.floor(remainingItems / promo.buy);
            totalBonuses += times * promo.get;
            remainingItems %= promo.buy;
        }
    }
    return totalBonuses;
}

export function PromotionFeedback({
  promotions,
  totalItems,
}: {
  promotions: AgreementPromotion[];
  totalItems: number;
}) {
  const validPromos = useMemo(() => 
    promotions.filter(p => p.promotions.rules?.type === 'buy_x_get_y_free' && Number(p.promotions.rules.buy) > 0), 
  [promotions]);

  const totalBonuses = useMemo(() => calculateTotalBonuses(validPromos, totalItems), [validPromos, totalItems]);
  const nextPromoGoal = useMemo(() => getNextPromoGoal(validPromos, totalItems), [validPromos, totalItems]);

  if (!nextPromoGoal) {
    return null;
  }

  const { buy, get } = nextPromoGoal.promotions.rules;
  const numBuy = Number(buy);
  
  const isAnyPromoActive = totalBonuses > 0;
  const itemsRemaining = numBuy - totalItems;
  const progress = totalItems < numBuy ? Math.max(0, (totalItems / numBuy) * 100) : 100;
  
  const showProgressBar = itemsRemaining > 0 && totalItems < numBuy;

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 text-sm font-medium">
        {isAnyPromoActive ? (
          <Gift className="h-4 w-4 text-primary" />
        ) : (
          <TrendingUp className="h-4 w-4 text-muted-foreground" />
        )}
        <p>
          {isAnyPromoActive 
              ? `¡Felicidades! Llevas ${totalBonuses} unidad(es) de regalo.`
              : `Alcanza la próxima promoción`
          }
        </p>
      </div>
      
      {showProgressBar && (
        <>
            <Progress value={progress} className="h-2" />
            <p className="text-xs text-muted-foreground">
                Agrega <strong>{itemsRemaining}</strong> unidad(es) más para activar la promo{" "}
                <strong>{nextPromoGoal.promotions.name} ({numBuy} + {Number(get)})</strong>.
            </p>
        </>
      )}
    </div>
  );
}
