
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
  promotions: Promotion[];
  appliedPromotions: Promotion[];
  bonusItems: number;
  agreementId: string | null;
  pricesIncludeVat: boolean;
  setAgreement: (id: string, pricesIncludeVat: boolean, promotions: Promotion[]) => void;
  addItem: (product: ProductWithPrice, quantity?: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  getItemQuantity: (productId: string) => number;
  clearCart: () => void;
};

const calculatePromotions = (items: CartItem[], promotions: Promotion[]) => {
    const totalItems = items.reduce((total, item) => total + item.quantity, 0);
    const appliedPromotions: Promotion[] = [];
    let bonusItems = 0;

    promotions.forEach(promo => {
        if (!promo.rules || !promo.rules.type) return;

        switch (promo.rules.type) {
            case 'buy_x_get_y_free':
                if (totalItems >= promo.rules.buy) {
                    const times = Math.floor(totalItems / promo.rules.buy);
                    bonusItems += times * promo.rules.get;
                    if (!appliedPromotions.find(p => p.id === promo.id)) {
                       appliedPromotions.push(promo);
                    }
                }
                break;
            case 'free_shipping':
                if (totalItems >= promo.rules.min_units) {
                     if (!appliedPromotions.find(p => p.id === promo.id)) {
                       appliedPromotions.push(promo);
                    }
                }
                break;
            default:
                break;
        }
    });

    return { appliedPromotions, bonusItems };
}


// The single source of truth for all calculations.
const calculateAll = (items: CartItem[], pricesIncludeVat: boolean, promotions: Promotion[]) => {
  const totalItems = items.reduce((total, item) => total + item.quantity, 0);
  const isVolumePricingActive = totalItems >= VOLUME_THRESHOLD;

  let subtotal = 0;
  
  items.forEach(item => {
    const basePrice = (isVolumePricingActive && item.product.volume_price != null && item.product.volume_price < item.product.price) 
        ? item.product.volume_price 
        : item.product.price;
    
    if (pricesIncludeVat) {
        const singleItemSubtotal = basePrice / (1 + VAT_RATE);
        subtotal += singleItemSubtotal * item.quantity;
    } else {
        const singleItemSubtotal = basePrice;
        subtotal += singleItemSubtotal * item.quantity;
    }
  });

  const vatAmount = subtotal * VAT_RATE;
  const totalPrice = subtotal + vatAmount;
  
  const { appliedPromotions, bonusItems } = calculatePromotions(items, promotions);

  return { totalItems, subtotal, vatAmount, totalPrice, isVolumePricingActive, appliedPromotions, bonusItems };
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
      promotions: [],
      appliedPromotions: [],
      bonusItems: 0,
      agreementId: null,
      pricesIncludeVat: true,
      
      setAgreement: (id: string, pricesIncludeVat: boolean, promotions: Promotion[]) => {
        const currentAgreementId = get().agreementId;
        if (id !== currentAgreementId) {
            set({ 
                agreementId: id, 
                pricesIncludeVat: pricesIncludeVat,
                promotions: promotions,
                items: [], 
                totalItems: 0, 
                subtotal: 0, 
                vatAmount: 0, 
                totalPrice: 0,
                isVolumePricingActive: false,
                appliedPromotions: [],
                bonusItems: 0,
            });
        } else {
             const { items } = get();
             set({ 
                pricesIncludeVat: pricesIncludeVat,
                promotions: promotions,
                ...calculateAll(items, pricesIncludeVat, promotions)
            });
        }
      },

      addItem: (product: ProductWithPrice, quantity: number = 1) => {
        const { items, pricesIncludeVat, promotions } = get();
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
        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, promotions) });
      },

      removeItem: (productId: string) => {
        const { items, pricesIncludeVat, promotions } = get();
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

        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, promotions) });
      },

      updateQuantity: (productId: string, quantity: number) => {
        const { pricesIncludeVat, promotions } = get();
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
        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, promotions) });
      },
      
      getItemQuantity: (productId: string) => {
        const item = get().items.find(item => item.product.id === productId);
        return item ? item.quantity : 0;
      },

      clearCart: () => {
        set({ items: [], totalItems: 0, subtotal: 0, vatAmount: 0, totalPrice: 0, isVolumePricingActive: false, appliedPromotions: [], bonusItems: 0 });
      },
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => localStorage),
      // Prevent persisting promotions, as they should be fetched on page load.
      partialize: (state) =>
        Object.fromEntries(
          Object.entries(state).filter(([key]) => !['promotions', 'appliedPromotions', 'bonusItems'].includes(key))
        ),
      onRehydrateStorage: () => (state, error) => {
        if (state) {
            // Recalculate totals on rehydration, but with an empty promotions array
            const { totalItems, subtotal, vatAmount, totalPrice, isVolumePricingActive } = calculateAll(state.items, state.pricesIncludeVat, []);
            state.totalItems = totalItems;
            state.subtotal = subtotal;
            state.vatAmount = vatAmount;
            state.totalPrice = totalPrice;
            state.isVolumePricingActive = isVolumePricingActive;
            state.promotions = [];
            state.appliedPromotions = [];
            state.bonusItems = 0;
        }
      }
    }
  )
);
