
"use client";

import { useMemo } from "react";
import {
  Card,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import type { ProductWithPrice } from "@/types";
import Image from "next/image";
import { QuantitySelector } from "./add-to-cart-button";
import { getImageUrl } from "@/lib/placeholder-images";
import { useCartStore } from "@/hooks/use-cart-store";
import { cn } from "@/lib/utils";

export function ProductCard({ product }: { product: ProductWithPrice }) {
  const { isVolumePricingActive } = useCartStore();
  
  const isVolumePriceApplicable = isVolumePricingActive && product.volume_price && product.volume_price < product.price;
  const displayPrice = isVolumePriceApplicable ? product.volume_price : product.price;
  
  const formatCurrency = (num: number) => {
     return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS' }).format(num);
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
              {product.category && <Badge variant="secondary" className="w-fit shrink-0">{product.category}</Badge>}
            </div>
            
            <p className="text-muted-foreground text-sm line-clamp-2 sm:h-10">{product.description}</p>
            
            <div className="flex items-center justify-between mt-2">
              <div className="flex items-baseline gap-2">
                 <p className={cn(
                    "text-lg font-bold",
                    isVolumePriceApplicable && "text-primary"
                  )}>
                    {displayPrice ? formatCurrency(displayPrice) : '$0'}
                 </p>
                  {isVolumePriceApplicable && (
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
