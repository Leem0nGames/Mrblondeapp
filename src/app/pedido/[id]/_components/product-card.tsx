
import {
  Card,
  CardContent,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import type { ProductWithPrice } from "@/types";
import Image from "next/image";
import { AddToCartButton } from "./add-to-cart-button";
import { getImageUrl } from "@/lib/placeholder-images";

export function ProductCard({ product }: { product: ProductWithPrice }) {
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
            
            <div className="flex items-center justify-between mt-2">
              <p className="text-lg font-bold">
                ${product.price.toLocaleString()}
              </p>
              <div className="w-28 flex-shrink-0">
                 <AddToCartButton product={product} />
              </div>
            </div>
        </div>
      </CardContent>
    </Card>
  );
}
