
"use client";

import { useMemo } from "react";
import {
  Card,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import type { ProductWithPrice, AgreementPromotion } from "@/types";
import Image from "next/image";
import { QuantitySelector } from "./add-to-cart-button";
import { getImageUrl } from "@/lib/placeholder-images";
import { useCartStore } from "@/hooks/use-cart-store";
import { Gift } from "lucide-react";


// Helper function to parse promotion rules safely
function parsePromoRules(promo: AgreementPromotion) {
  const rules = promo.promotions.rules;
  if (rules?.type === 'buy_x_get_y_free') {
    const buy = Number(rules.buy);
    const get = Number(rules.get);
    if (!isNaN(buy) && buy > 0 && !isNaN(get) && get > 0) {
      return { ...promo, buy, get };
    }
  }
  return null;
}

function calculateBonusesForPromo(
  promo: NonNullable<ReturnType<typeof parsePromoRules>>,
  totalItems: number,
) {
  if (totalItems >= promo.buy) {
      const times = Math.floor(totalItems / promo.buy);
      return times * promo.get;
  }
  return 0;
}


export function ProductCard({ product, promotions }: { product: ProductWithPrice, promotions: AgreementPromotion[] }) {
  const { totalItems } = useCartStore();

  const stockStatus =
    product.stock > 10
      ? "En Stock"
      : product.stock > 0
      ? "Poco Stock"
      : "Agotado";
  const badgeVariant =
    product.stock > 10
      ? "default"
      : product.stock > 0
      ? "secondary"
      : "destructive";
  
  const applicablePromos = useMemo(() => {
    return promotions
      .map(parsePromoRules)
      .filter((p): p is NonNullable<typeof p> => p !== null)
      .sort((a, b) => b.buy - a.buy);
  }, [promotions]);

  const bonusesByPromo = useMemo(() => {
    let remainingItems = totalItems;
    const bonuses: { name: string; bonus: number }[] = [];

    for (const promo of applicablePromos) {
      if (remainingItems >= promo.buy) {
        const times = Math.floor(remainingItems / promo.buy);
        bonuses.push({ name: promo.promotions.name, bonus: times * promo.get });
        remainingItems %= promo.buy;
      }
    }
    return bonuses;
  }, [totalItems, applicablePromos]);


  return (
    <Card className="flex flex-col sm:flex-row w-full overflow-hidden">
      <CardContent className="p-0 flex flex-col sm:flex-row items-center gap-4 p-4 w-full">
         <div className="relative aspect-square w-full sm:w-24 sm:h-24 flex-shrink-0">
            <Image
                src={getImageUrl("product_card", { id: product.id, width: 200, height: 200 })}
                alt={product.name}
                fill
                sizes="(max-width: 640px) 90vw, 200px"
                className="rounded-lg object-cover"
                data-ai-hint="product image"
            />
        </div>

        <div className="flex flex-col justify-between w-full gap-2">
            <div className="flex flex-col sm:flex-row justify-between sm:items-start gap-2">
              <h3 className="font-semibold text-base leading-tight">{product.name}</h3>
              <Badge variant={badgeVariant} className="w-fit shrink-0">
                {stockStatus}
              </Badge>
            </div>
            
            <p className="text-muted-foreground text-sm line-clamp-2 sm:h-10">{product.description}</p>
            
            {bonusesByPromo.length > 0 && (
              <div className="mt-2 space-y-1">
                {bonusesByPromo.map(p => (
                  <Badge variant="secondary" key={p.name} className="font-normal">
                    <Gift className="h-3 w-3 mr-1.5" />
                     +{p.bonus} de Regalo ({p.name})
                  </Badge>
                ))}
              </div>
            )}
            
            <div className="flex items-center justify-between mt-2">
              <p className="text-lg font-bold">
                ${product.price.toLocaleString()}
              </p>
              <div className="w-32 flex-shrink-0">
                 <QuantitySelector product={product} />
              </div>
            </div>
        </div>
      </CardContent>
    </Card>
  );
}
