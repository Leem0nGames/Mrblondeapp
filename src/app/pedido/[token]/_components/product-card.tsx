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

export function ProductCard({ product }: { product: ProductWithPrice }) {
  const stockStatus =
    product.stock > 10
      ? "In Stock"
      : product.stock > 0
      ? "Low Stock"
      : "Out of Stock";
  const badgeVariant =
    product.stock > 10
      ? "outline"
      : product.stock > 0
      ? "default"
      : "destructive";

  return (
    <Card className="flex flex-col">
      <CardHeader>
        <div className="relative aspect-[4/3] w-full mb-4">
            <Image
                src={`https://picsum.photos/seed/${product.id}/600/400`}
                alt={product.name}
                fill
                className="rounded-t-lg object-cover"
                data-ai-hint="product image"
            />
        </div>
        <CardTitle className="text-xl">{product.name}</CardTitle>
        <Badge variant={badgeVariant} className="w-fit">
          {stockStatus}
        </Badge>
        <CardDescription className="line-clamp-2 h-10">{product.description}</CardDescription>
      </CardHeader>
      <CardContent className="flex-grow">
        {/* Content if needed */}
      </CardContent>
      <CardFooter className="flex justify-between items-center mt-auto pt-4">
        <p className="text-lg font-semibold">
          ${product.price.toLocaleString()}
        </p>
        <AddToCartButton product={product} />
      </CardFooter>
    </Card>
  );
}
