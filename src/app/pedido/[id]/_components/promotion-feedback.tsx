"use client";

import { useMemo } from "react";
import type { AgreementPromotion } from "@/types";
import { Progress } from "@/components/ui/progress";
import { Gift, TrendingUp } from "lucide-react";

// Helper function to parse promotion rules safely
function parsePromoRules(promo: AgreementPromotion) {
  const rules = promo.promotions.rules;
  if (rules?.type === 'buy_x_get_y_free') {
    const buy = Number(rules.buy);
    const get = Number(rules.get);
    if (!isNaN(buy) && buy > 0 && !isNaN(get)) {
      return { ...promo, buy, get };
    }
  }
  return null;
}


// Función para obtener la próxima promoción objetivo
function getNextPromoGoal(promos: AgreementPromotion[], totalItems: number) {
  const sortedPromos = promos
    .map(parsePromoRules)
    .filter((p): p is NonNullable<typeof p> => p !== null)
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
      .map(parsePromoRules)
      .filter((p): p is NonNullable<typeof p> => p !== null)
      .sort((a, b) => b.buy - a.buy); // Ordenar de mayor a menor requisito

    let remainingItems = totalItems;
    let totalBonuses = 0;

    for (const promo of sortedPromos) {
        if (remainingItems >= promo.buy) {
            const times = Math.floor(remainingItems / promo.buy);
            totalBonuses += times * promo.get;
            remainingItems %= promo.buy; // Actualizar los items restantes para la siguiente promo
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
    promotions.filter(p => p.promotions.rules?.type === 'buy_x_get_y_free'), 
  [promotions]);

  const totalBonuses = useMemo(() => calculateTotalBonuses(validPromos, totalItems), [validPromos, totalItems]);
  const nextPromoGoal = useMemo(() => getNextPromoGoal(validPromos, totalItems), [validPromos, totalItems]);

  if (!nextPromoGoal) {
    return null;
  }

  const { buy, get } = nextPromoGoal;
  
  const isAnyPromoActive = totalBonuses > 0;
  const itemsRemaining = buy - totalItems;
  const progress = totalItems < buy ? Math.max(0, (totalItems / buy) * 100) : 100;
  
  const showProgressBar = itemsRemaining > 0 && totalItems < buy;

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
                <strong>{nextPromoGoal.promotions.name} ({buy} + {get})</strong>.
            </p>
        </>
      )}
    </div>
  );
}
