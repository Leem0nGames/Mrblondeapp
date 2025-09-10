
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

    set({
      items: updatedItems,
      ...calculateTotals(updatedItems)
    });
  },
  removeItem: (productId: string) => {
    const updatedItems = get().items.filter(
      (item) => item.product.id !== productId
    );
    set({
      items: updatedItems,
      ...calculateTotals(updatedItems)
    });
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
    set({
      items: updatedItems,
      ...calculateTotals(updatedItems)
    });
  },
  clearCart: () => {
    set({ items: [], totalItems: 0, totalPrice: 0 });
  },
}));

// --- Persistencia Manual para evitar errores de hidratación ---

const CART_STORAGE_KEY = "cart-storage";

// Guardar en localStorage
useCartStore.subscribe((state) => {
  if (typeof window !== 'undefined' && state.isHydrated) {
    localStorage.setItem(CART_STORAGE_KEY, JSON.stringify({ items: state.items }));
  }
});

// Cargar desde localStorage
if (typeof window !== 'undefined') {
  const savedState = localStorage.getItem(CART_STORAGE_KEY);
  let items: CartItem[] = [];
  if (savedState) {
    try {
      // Ensure that parsed items is an array, default to empty array if not
      const parsed = JSON.parse(savedState);
      items = Array.isArray(parsed?.items) ? parsed.items : [];
    } catch (e) {
      console.error("Could not rehydrate cart from localStorage", e);
      // If parsing fails, items will remain an empty array
    }
  }
  
  // Set state after determining items, ensuring calculateTotals always gets an array
  useCartStore.setState({ items, ...calculateTotals(items), isHydrated: true });
}
