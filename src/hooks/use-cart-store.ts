"use client";

import { create } from "zustand";
import { Product } from "@/types";

export type CartItem = {
  product: Product;
  quantity: number;
};

type CartState = {
  items: CartItem[];
  addItem: (product: Product, quantity: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
  totalItems: number;
  totalPrice: number;
};

export const useCartStore = create<CartState>((set, get) => ({
  items: [],
  totalItems: 0,
  totalPrice: 0,
  addItem: (product: Product, quantity: number) => {
    const { items } = get();
    const existingItem = items.find(
      (item) => item.product.id === product.id
    );

    let updatedItems;
    if (existingItem) {
      updatedItems = items.map((item) =>
        item.product.id === product.id
          ? { ...item, quantity: Math.max(0, item.quantity + quantity) }
          : item
      );
    } else {
      updatedItems = [...items, { product, quantity }];
    }

    updatedItems = updatedItems.filter(item => item.quantity > 0);

    set((state) => ({
      items: updatedItems,
      ...calculateTotals(updatedItems)
    }));
  },
  removeItem: (productId: string) => {
    const updatedItems = get().items.filter(
      (item) => item.product.id !== productId
    );
    set((state) => ({
      items: updatedItems,
      ...calculateTotals(updatedItems)
    }));
  },
  updateQuantity: (productId: string, quantity: number) => {
    let updatedItems;
    if (quantity <= 0) {
      updatedItems = get().items.filter(
        (item) => item.product.id !== productId
      );
    } else {
      updatedItems = get().items.map((item) =>
        item.product.id === productId ? { ...item, quantity } : item
      );
    }
    set((state) => ({
      items: updatedItems,
      ...calculateTotals(updatedItems)
    }));
  },
  clearCart: () => {
    set({ items: [], totalItems: 0, totalPrice: 0 });
  },
}));

function calculateTotals(items: CartItem[]) {
  const totalItems = items.reduce((total, item) => total + item.quantity, 0);
  const totalPrice = items.reduce(
    (total, item) => total + item.product.base_price * item.quantity,
    0
  );
  return { totalItems, totalPrice };
}
