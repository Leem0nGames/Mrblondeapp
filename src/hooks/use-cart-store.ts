
"use client";

import { create } from "zustand";
import { persist, createJSONStorage } from 'zustand/middleware'
import type { ProductWithPrice, Promotion } from "@/types";

export type CartItem = {
  product: ProductWithPrice;
  quantity: number;
};

const VOLUME_THRESHOLD = 150;
const VAT_RATE = 0.21; // 21%

type CartState = {
  items: CartItem[];
  totalItems: number;
  subtotal: number;
  vatAmount: number;
  totalPrice: number;
  isVolumePricingActive: boolean;
  agreementId: string | null;
  pricesIncludeVat: boolean;
  setAgreement: (id: string, pricesIncludeVat: boolean) => void;
  addItem: (product: ProductWithPrice, quantity?: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
};

// The single source of truth for all calculations.
const calculateAll = (items: CartItem[], pricesIncludeVat: boolean) => {
  const totalItems = items.reduce((total, item) => total + item.quantity, 0);
  const isVolumePricingActive = totalItems >= VOLUME_THRESHOLD;

  let subtotal = 0;
  
  // This is the core logic fix: The final price calculation must respect the volume pricing.
  items.forEach(item => {
    const basePrice = (isVolumePricingActive && item.product.volume_price) 
        ? item.product.volume_price 
        : item.product.price;
    
    if (pricesIncludeVat) {
        // If the price from the DB already has VAT, we need to extract the subtotal.
        const singleItemSubtotal = basePrice / (1 + VAT_RATE);
        subtotal += singleItemSubtotal * item.quantity;
    } else {
        // If the price from the DB is pre-tax, it's our subtotal.
        const singleItemSubtotal = basePrice;
        subtotal += singleItemSubtotal * item.quantity;
    }
  });

  const vatAmount = subtotal * VAT_RATE;
  const totalPrice = subtotal + vatAmount;

  return { totalItems, subtotal, vatAmount, totalPrice, isVolumePricingActive };
};

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],
      totalItems: 0,
      subtotal: 0,
      vatAmount: 0,
      totalPrice: 0,
      isVolumePricingActive: false,
      agreementId: null,
      pricesIncludeVat: true,
      
      setAgreement: (id: string, pricesIncludeVat: boolean) => {
        const currentAgreementId = get().agreementId;
        if (id !== currentAgreementId) {
            set({ 
                agreementId: id, 
                pricesIncludeVat: pricesIncludeVat, 
                items: [], 
                totalItems: 0, 
                subtotal: 0, 
                vatAmount: 0, 
                totalPrice: 0,
                isVolumePricingActive: false,
            });
        } else if (pricesIncludeVat !== get().pricesIncludeVat) {
             const { items } = get();
             set({ 
                pricesIncludeVat: pricesIncludeVat, 
                ...calculateAll(items, pricesIncludeVat)
            });
        }
      },

      addItem: (product: ProductWithPrice, quantity: number = 1) => {
        const { items, pricesIncludeVat } = get();
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
        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat) });
      },

      removeItem: (productId: string) => {
        const { items, pricesIncludeVat } = get();
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

        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat) });
      },

      updateQuantity: (productId: string, quantity: number) => {
        const { pricesIncludeVat } = get();
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
        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat) });
      },

      clearCart: () => {
        set({ items: [], totalItems: 0, subtotal: 0, vatAmount: 0, totalPrice: 0, isVolumePricingActive: false });
      },
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => localStorage),
      onRehydrateStorage: () => (state, error) => {
        if (state) {
            const { totalItems, subtotal, vatAmount, totalPrice, isVolumePricingActive } = calculateAll(state.items, state.pricesIncludeVat);
            state.totalItems = totalItems;
            state.subtotal = subtotal;
            state.vatAmount = vatAmount;
            state.totalPrice = totalPrice;
            state.isVolumePricingActive = isVolumePricingActive;
        }
      }
    }
  )
);
