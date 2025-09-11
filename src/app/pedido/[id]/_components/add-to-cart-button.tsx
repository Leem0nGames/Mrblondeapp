"use client";

import { Button } from "@/components/ui/button";
import { useCartStore } from "@/hooks/use-cart-store";
import type { ProductWithPrice } from "@/types";
import { Plus } from "lucide-react";

export function AddToCartButton({ product }: { product: ProductWithPrice }) {
  const add = useCartStore((s) => s.addItem);

  return (
    <Button
      size="sm"
      className="w-full"
      onClick={() => add(product, 1)}
      disabled={product.stock === 0}
    >
      <Plus className="mr-2 h-4 w-4" />
      Agregar
    </Button>
  );
}
