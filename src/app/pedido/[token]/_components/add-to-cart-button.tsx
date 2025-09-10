"use client";

import { Button } from "@/components/ui/button";
import { useCartStore } from "@/hooks/use-cart-store";
import type { Product } from "@/types";
import { PlusCircle } from "lucide-react";

export function AddToCartButton({ product }: { product: Product }) {
  const add = useCartStore((s) => s.addItem);

  return (
    <Button
      size="sm"
      variant="outline"
      onClick={() => add(product, 1)}
      disabled={product.stock === 0}
    >
      <PlusCircle className="mr-2 h-4 w-4" />
      Agregar
    </Button>
  );
}