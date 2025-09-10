"use client";

import { useState, useEffect } from "react";
import { useCartStore, type CartItem } from "@/hooks/use-cart-store";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import {
  ShoppingCart,
  Trash2,
  Plus,
  Minus,
} from "lucide-react";
import { ScrollArea } from "@/components/ui/scroll-area";
import Image from "next/image";
import { OrderSummarySheet } from "./order-summary-sheet";
import type { AgreementPromotion } from "@/types";
import { getImageUrl } from "@/lib/placeholder-images";
import { Skeleton } from "@/components/ui/skeleton";

export function CartWidget({ 
  clientName, 
  availablePromotions 
}: { 
  clientName: string, 
  availablePromotions: AgreementPromotion[] 
}) {
  const { items, totalItems } = useCartStore();
  const [isSummaryOpen, setIsSummaryOpen] = useState(false);
  const [hasMounted, setHasMounted] = useState(false);

  useEffect(() => {
    setHasMounted(true);
  }, []);

  return (
    <>
      <Sheet>
        <SheetTrigger asChild>
          <Button variant="outline" className="fixed bottom-4 right-4 z-50 h-14 rounded-full shadow-lg">
            <ShoppingCart className="mr-2" />
            Ver Pedido ({hasMounted ? totalItems : 0})
          </Button>
        </SheetTrigger>
        <SheetContent className="flex flex-col">
          <SheetHeader>
            <SheetTitle>Tu Pedido</SheetTitle>
            <SheetDescription>
              Revisa los productos en tu carrito de compras.
            </SheetDescription>
          </SheetHeader>
          {!hasMounted ? (
             <div className="flex-1 space-y-4 py-4">
                <Skeleton className="h-24 w-full" />
                <Skeleton className="h-24 w-full" />
                <Skeleton className="h-24 w-full" />
             </div>
          ) : items.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center gap-4 text-center">
              <ShoppingCart className="h-16 w-16 text-muted-foreground" />
              <p className="text-muted-foreground">Tu carrito está vacío</p>
              <p className="text-sm text-muted-foreground">
                Agrega productos para comenzar tu pedido.
              </p>
            </div>
          ) : (
            <>
              <ScrollArea className="flex-1 -mx-6">
                <div className="px-6 divide-y">
                  {items.map((item) => (
                    <CartItemComponent key={item.product.id} item={item} />
                  ))}
                </div>
              </ScrollArea>
              <Button 
                size="lg" 
                className="w-full mt-4"
                onClick={() => setIsSummaryOpen(true)}
              >
                Continuar
              </Button>
            </>
          )}
        </SheetContent>
      </Sheet>
      <OrderSummarySheet 
        isOpen={isSummaryOpen}
        onOpenChange={setIsSummaryOpen}
        clientName={clientName}
        availablePromotions={availablePromotions}
      />
    </>
  );
}

function CartItemComponent({ item }: { item: CartItem }) {
  const { updateQuantity } = useCartStore();

  return (
    <div className="flex items-center justify-between gap-4 py-4">
      <div className="flex items-center gap-4">
        <Image
          src={getImageUrl("cart_item", { id: item.product.id, width: 64, height: 64 })}
          alt={item.product.name}
          width={64}
          height={64}
          className="rounded-md object-cover"
          data-ai-hint="product image"
        />
        <div>
          <p className="font-medium">{item.product.name}</p>
          <p className="text-sm text-muted-foreground">
            ${item.product.price.toLocaleString()}
          </p>
        </div>
      </div>
      <div className="flex items-center gap-2">
        <Button
          variant="outline"
          size="icon"
          className="h-8 w-8"
          onClick={() => updateQuantity(item.product.id, item.quantity - 1)}
        >
          <Minus className="h-4 w-4" />
        </Button>
        <span className="w-8 text-center">{item.quantity}</span>
        <Button
          variant="outline"
          size="icon"
          className="h-8 w-8"
          onClick={() => updateQuantity(item.product.id, item.quantity + 1)}
        >
          <Plus className="h-4 w-4" />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8 text-destructive"
          onClick={() => updateQuantity(item.product.id, 0)}
        >
          <Trash2 className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
}
