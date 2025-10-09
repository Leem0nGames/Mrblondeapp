
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
import { cn } from "@/lib/utils";


// Helper function to parse promotion rules safely
function parsePromoRules(promo: AgreementPromotion) {
  const rules = promo.promotions.rules;
  if (rules?.type === 'buy_x_get_y_free') {
    const buy = Number(rules.buy);
    const get = Number(rules.get);
    if (!isNaN(buy) && buy > 0 && !isNaN(get) && get > 0) {
      return { buy, get };
    }
  }
  return null;
}

// This function calculates total bonuses based on sorted promotions
function calculateTotalBonuses(promotions: AgreementPromotion[], totalItems: number) {
    const sortedPromos = promotions
      .map(parsePromoRules)
      .filter((p): p is NonNullable<typeof p> => p !== null)
      .sort((a, b) => b.buy - a.buy); // Sort from highest requirement to lowest

    if (sortedPromos.length === 0) return 0;
    
    // Find the highest-tier promotion that has been met
    const applicablePromo = sortedPromos.find(p => totalItems >= p.buy);

    if (applicablePromo) {
        // Calculate how many times the promotion is applied
        const times = Math.floor(totalItems / applicablePromo.buy);
        return times * applicablePromo.get;
    }

    return 0;
}

const VOLUME_THRESHOLD = 150;

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
  
  const totalBonuses = useMemo(() => {
    return calculateTotalBonuses(promotions, totalItems);
  }, [totalItems, promotions]);

  const isVolumePriceActive = totalItems >= VOLUME_THRESHOLD && product.volume_price;
  const displayPrice = isVolumePriceActive ? product.volume_price : product.price;
  
  const formatNumber = (num: number) => {
    // Ensure it's formatted for 'es-AR' to avoid hydration mismatch
    return new Intl.NumberFormat('es-AR', { minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(num);
  }

  const formatCurrency = (num: number) => {
     return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(num);
  }

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
            
            {totalBonuses > 0 && (
              <div className="mt-2 space-y-1">
                  <Badge variant="secondary" className="font-normal">
                    <Gift className="h-3 w-3 mr-1.5" />
                     ¡Pedido con +{totalBonuses} de regalo!
                  </Badge>
              </div>
            )}
            
            <div className="flex items-center justify-between mt-2">
              <div className="flex items-baseline gap-2">
                 <p className={cn(
                    "text-lg font-bold",
                    isVolumePriceActive && "text-primary"
                  )}>
                    {displayPrice ? formatCurrency(displayPrice) : '$0'}
                 </p>
                  {isVolumePriceActive && (
                      <p className="text-sm font-normal text-muted-foreground line-through">
                          {formatCurrency(product.price)}
                      </p>
                  )}
              </div>

              <div className="w-32 flex-shrink-0">
                 <QuantitySelector product={product} />
              </div>
            </div>
        </div>
      </CardContent>
    </Card>
  );
}
