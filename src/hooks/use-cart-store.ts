"use client";

import { create } from "zustand";
import { persist, createJSONStorage } from 'zustand/middleware'
import type { ProductWithPrice, AgreementPromotion, Promotion } from "@/types";

export type CartItem = {
  product: ProductWithPrice;
  quantity: number;
};

const VOLUME_THRESHOLD = 150;
const VAT_RATE = 0.21; // 21%

// Helper function to parse promotion rules safely
function parseBuyXGetYPromo(promo: Promotion) {
  const rules = promo.rules;
  if (rules?.type === 'buy_x_get_y_free') {
    const buy = Number(rules.buy);
    const get = Number(rules.get);
    if (!isNaN(buy) && buy > 0 && !isNaN(get) && get > 0) {
      return { buy, get, name: promo.name };
    }
  }
  return null;
}

type CartState = {
  items: CartItem[];
  totalItems: number;
  subtotal: number;
  vatAmount: number;
  totalPrice: number;
  bonusItems: { total: number; appliedPromos: { name: string, units: number }[] };
  agreementId: string | null;
  pricesIncludeVat: boolean;
  setAgreement: (id: string, pricesIncludeVat: boolean, promotions: AgreementPromotion[]) => void;
  addItem: (product: ProductWithPrice, quantity?: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
  availablePromotions: AgreementPromotion[];
};


// Helper function to compute totals and bonuses from a given set of items.
const calculateAll = (items: CartItem[], pricesIncludeVat: boolean, availablePromotions: AgreementPromotion[]) => {
  const totalItems = items.reduce((total, item) => total + item.quantity, 0);
  const isVolumePricing = totalItems >= VOLUME_THRESHOLD;

  let subtotal = 0;
  let totalPrice = 0;
  
  items.forEach(item => {
    const priceWithVat = (isVolumePricing && item.product.volume_price) ? item.product.volume_price : item.product.price;
    
    if (pricesIncludeVat) {
        const singleItemSubtotal = priceWithVat / (1 + VAT_RATE);
        subtotal += singleItemSubtotal * item.quantity;
        totalPrice += priceWithVat * item.quantity;
    } else {
        const singleItemSubtotal = priceWithVat;
        subtotal += singleItemSubtotal * item.quantity;
        totalPrice += singleItemSubtotal * (1 + VAT_RATE) * item.quantity;
    }
  });

  const vatAmount = totalPrice - subtotal;
  
  // Calculate Bonuses
    const buyXGetYPromos = availablePromotions
      .map(p => parseBuyXGetYPromo(p.promotions))
      .filter((p): p is NonNullable<ReturnType<typeof parseBuyXGetYPromo>> => p !== null);

    let totalBonuses = 0;
    const appliedPromos: { name: string, units: number }[] = [];

    if (buyXGetYPromos.length > 0) {
        items.forEach(item => {
            let itemBonuses = 0;
            buyXGetYPromos.forEach(promo => {
                if (item.quantity >= promo.buy) {
                    const times = Math.floor(item.quantity / promo.buy);
                    const bonusUnits = times * promo.get;
                    itemBonuses += bonusUnits;

                     const existingPromo = appliedPromos.find(p => p.name === promo.name);
                    if (existingPromo) {
                        existingPromo.units += bonusUnits;
                    } else {
                        appliedPromos.push({ name: promo.name, units: bonusUnits });
                    }
                }
            });
            totalBonuses += itemBonuses;
        });
    }
    
    const bonusItems = { total: totalBonuses, appliedPromos };

  return { totalItems, subtotal, vatAmount, totalPrice, bonusItems };
};

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],
      totalItems: 0,
      subtotal: 0,
      vatAmount: 0,
      totalPrice: 0,
      bonusItems: { total: 0, appliedPromos: [] },
      agreementId: null,
      pricesIncludeVat: true,
      availablePromotions: [],
      
      setAgreement: (id: string, pricesIncludeVat: boolean, promotions: AgreementPromotion[]) => {
        const currentAgreementId = get().agreementId;
        if (id !== currentAgreementId) {
            set({ 
                agreementId: id, 
                pricesIncludeVat: pricesIncludeVat, 
                availablePromotions: promotions,
                items: [], 
                totalItems: 0, 
                subtotal: 0, 
                vatAmount: 0, 
                totalPrice: 0,
                bonusItems: { total: 0, appliedPromos: [] }
            });
        } else {
             set({ 
                agreementId: id, 
                pricesIncludeVat: pricesIncludeVat, 
                availablePromotions: promotions,
            });
        }
      },

      addItem: (product: ProductWithPrice, quantity: number = 1) => {
        const { items, pricesIncludeVat, availablePromotions } = get();
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
        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, availablePromotions) });
      },

      removeItem: (productId: string) => {
        const { items, pricesIncludeVat, availablePromotions } = get();
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

        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, availablePromotions) });
      },

      updateQuantity: (productId: string, quantity: number) => {
        const { pricesIncludeVat, availablePromotions } = get();
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
        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, availablePromotions) });
      },

      clearCart: () => {
        set({ items: [], totalItems: 0, subtotal: 0, vatAmount: 0, totalPrice: 0, bonusItems: { total: 0, appliedPromos: [] } });
      },
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => localStorage),
      // This function runs when the store is rehydrated from localStorage
      onRehydrateStorage: () => (state, error) => {
        if (state) {
            // Recalculate everything on rehydration to ensure consistency
            const { totalItems, subtotal, vatAmount, totalPrice, bonusItems } = calculateAll(state.items, state.pricesIncludeVat, state.availablePromotions);
            state.totalItems = totalItems;
            state.subtotal = subtotal;
            state.vatAmount = vatAmount;
            state.totalPrice = totalPrice;
            state.bonusItems = bonusItems;
        }
      }
    }
  )
);
