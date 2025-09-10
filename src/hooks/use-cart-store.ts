
"use client";

import { create } from "zustand";
import type { ProductWithPrice } from "@/types";

export type CartItem = {
  product: ProductWithPrice;
  quantity: number;
};

type CartState = {
  items: CartItem[];
  addItem: (product: ProductWithPrice, quantity?: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
  totalItems: number;
  totalPrice: number;
  isHydrated: boolean;
};

const calculateTotals = (items: CartItem[]) => {
  const totalItems = items.reduce((total, item) => total + item.quantity, 0);
  const totalPrice = items.reduce(
    (total, item) => total + item.product.price * item.quantity,
    0
  );
  return { totalItems, totalPrice };
};

const CART_STORAGE_KEY = "cart-storage";

export const useCartStore = create<CartState>((set, get) => ({
  items: [],
  totalItems: 0,
  totalPrice: 0,
  isHydrated: false,
  
  addItem: (product: ProductWithPrice, quantity: number = 1) => {
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
    const totals = calculateTotals(updatedItems);
    set({ items: updatedItems, ...totals });
    localStorage.setItem(CART_STORAGE_KEY, JSON.stringify({ items: updatedItems }));
  },

  removeItem: (productId: string) => {
    const updatedItems = get().items.filter(
      (item) => item.product.id !== productId
    );
    const totals = calculateTotals(updatedItems);
    set({ items: updatedItems, ...totals });
    localStorage.setItem(CART_STORAGE_KEY, JSON.stringify({ items: updatedItems }));
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
    const totals = calculateTotals(updatedItems);
    set({ items: updatedItems, ...totals });
    localStorage.setItem(CART_STORAGE_KEY, JSON.stringify({ items: updatedItems }));
  },

  clearCart: () => {
    const totals = calculateTotals([]);
    set({ items: [], ...totals });
    localStorage.removeItem(CART_STORAGE_KEY);
  },
}));


// Hydration logic must be run on the client
if (typeof window !== 'undefined') {
    const savedState = localStorage.getItem(CART_STORAGE_KEY);
    if (savedState) {
        try {
            const parsed = JSON.parse(savedState);
            if (Array.isArray(parsed?.items)) {
                const items: CartItem[] = parsed.items;
                const totals = calculateTotals(items);
                useCartStore.setState({ items, ...totals, isHydrated: true });
            } else {
                useCartStore.setState({ isHydrated: true }); // Mark as hydrated even if data is malformed
            }
        } catch (e) {
            console.error("Could not rehydrate cart from localStorage", e);
            useCartStore.setState({ isHydrated: true }); // Mark as hydrated on error
        }
    } else {
        useCartStore.setState({ isHydrated: true }); // Mark as hydrated if no saved state
    }
}
