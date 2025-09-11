
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
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
    <Card className="flex flex-col">
       <CardHeader className="p-4">
         <div className="relative aspect-square w-full mb-4">
            <Image
                src={getImageUrl("product_card", { id: product.id, width: 200, height: 200 })}
                alt={product.name}
                fill
                sizes="(max-width: 768px) 50vw, (max-width: 1200px) 33vw, 25vw"
                className="rounded-lg object-cover"
                data-ai-hint="product image"
            />
        </div>
        <div className="flex justify-between items-start">
          <CardTitle className="text-base leading-tight">{product.name}</CardTitle>
          <Badge variant={badgeVariant} className="w-fit shrink-0">
            {stockStatus}
          </Badge>
        </div>
        <p className="text-lg font-semibold">
          ${product.price.toLocaleString()}
        </p>
        <CardDescription className="text-xs line-clamp-2 h-8">{product.description}</CardDescription>
      </CardHeader>
      <CardContent className="p-4 pt-0 flex-grow">
        {/* Content if needed */}
      </CardContent>
      <CardFooter className="p-4 pt-0">
        <AddToCartButton product={product} />
      </CardFooter>
    </Card>
  );
}
