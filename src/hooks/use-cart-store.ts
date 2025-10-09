"use client";

import { create } from "zustand";
import { persist, createJSONStorage } from 'zustand/middleware'
import type { ProductWithPrice } from "@/types";

export type CartItem = {
  product: ProductWithPrice;
  quantity: number;
};

type CartState = {
  items: CartItem[];
  totalItems: number;
  totalPrice: number;
  agreementId: string | null;
  setAgreementId: (id: string) => void;
  addItem: (product: ProductWithPrice, quantity?: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
};

// Helper function to compute totals from a given set of items.
const calculateTotals = (items: CartItem[]) => {
  const totalItems = items.reduce((total, item) => total + item.quantity, 0);
  const totalPrice = items.reduce(
    (total, item) => total + item.product.price * item.quantity,
    0
  );
  return { totalItems, totalPrice };
};

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],
      totalItems: 0,
      totalPrice: 0,
      agreementId: null,
      
      setAgreementId: (id: string) => {
        set({ agreementId: id });
      },

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
        set({ items: updatedItems, ...calculateTotals(updatedItems) });
      },

      removeItem: (productId: string) => {
        const { items } = get();
        const existingItem = items.find(item => item.product.id === productId);

        if (!existingItem) return;

        let updatedItems;
        if (existingItem.quantity > 1) {
            updatedItems = items.map(item => 
                item.product.id === productId 
                    ? { ...item, quantity: item.quantity - 1 } 
                    : item
            );
        } else {
            updatedItems = items.filter(item => item.product.id !== productId);
        }

        set({ items: updatedItems, ...calculateTotals(updatedItems) });
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
        set({ items: updatedItems, ...calculateTotals(updatedItems) });
      },

      clearCart: () => {
        set({ items: [], totalItems: 0, totalPrice: 0 });
      },
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => localStorage),
      // This function runs when the store is rehydrated from localStorage
      onRehydrateStorage: () => (state) => {
        if (state) {
          const { totalItems, totalPrice } = calculateTotals(state.items);
          state.totalItems = totalItems;
          state.totalPrice = totalPrice;
        }
      }
    }
  )
);
