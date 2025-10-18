
"use client";

import { create } from "zustand";
import { persist, createJSONStorage } from 'zustand/middleware'
import type { ProductWithPrice, Promotion, CartItem as CartItemType } from "@/types";

export type BonusInfo = {
    [productId: string]: {
        productName: string;
        bonusQuantity: number;
    }
}
const VOLUME_THRESHOLD = 150;

type CartState = {
  items: CartItemType[];
  totalItems: number;
  subtotal: number;
  subtotalWithDiscount: number;
  discountApplied: number;
  vatAmount: number;
  totalPrice: number;
  isVolumePricingActive: boolean;
  promotions: Promotion[];
  appliedPromotions: Promotion[];
  bonusInfo: BonusInfo;
  agreementId: string | null;
  pricesIncludeVat: boolean;
  vatPercentage: number;
  setAgreement: (id: string, pricesIncludeVat: boolean, promotions: Promotion[], vatPercentage: number) => void;
  addItem: (product: ProductWithPrice, quantity?: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  getItemQuantity: (productId: string) => number;
  clearCart: () => void;
};

const calculatePromotions = (items: CartItemType[], subtotal: number, promotions: Promotion[]) => {
    const totalItems = items.reduce((total, item) => total + item.quantity, 0);
    const appliedPromotions: Promotion[] = [];
    const bonusInfo: BonusInfo = {};
    let discountPercentage = 0;

    promotions.forEach(promo => {
        if (!promo.rules || !promo.rules.type) return;

        switch (promo.rules.type) {
            case 'buy_x_get_y_free':
                items.forEach(item => {
                    if (item.quantity >= promo.rules.buy) {
                        const times = Math.floor(item.quantity / promo.rules.buy);
                        const bonusQuantity = times * promo.rules.get;
                        if (bonusQuantity > 0) {
                            bonusInfo[item.product.id] = {
                                productName: item.product.name,
                                bonusQuantity: bonusQuantity
                            };
                            if (!appliedPromotions.find(p => p.id === promo.id)) {
                                appliedPromotions.push(promo);
                            }
                        }
                    }
                });
                break;
            case 'free_shipping':
                if (totalItems >= promo.rules.min_units) {
                     if (!appliedPromotions.find(p => p.id === promo.id)) {
                       appliedPromotions.push(promo);
                    }
                }
                break;
            case 'min_amount_discount':
                 if (subtotal >= promo.rules.min_amount) {
                    discountPercentage = Math.max(discountPercentage, promo.rules.percentage);
                    if (!appliedPromotions.find(p => p.id === promo.id)) {
                       appliedPromotions.push(promo);
                    }
                }
                break;
            default:
                break;
        }
    });
    return { appliedPromotions, bonusInfo, discountPercentage };
}


// The single source of truth for all calculations.
const calculateAll = (items: CartItemType[], pricesIncludeVat: boolean, promotions: Promotion[], vatPercentage: number) => {
  const totalItems = items.reduce((total, item) => total + item.quantity, 0);
  const isVolumePricingActive = totalItems >= VOLUME_THRESHOLD;
  const vatRate = vatPercentage / 100;

  let subtotal = 0;
  
  items.forEach(item => {
    const basePrice = (isVolumePricingActive && item.product.volume_price != null && item.product.volume_price < item.product.price) 
        ? item.product.volume_price 
        : item.product.price;
    
    if (pricesIncludeVat) {
        const singleItemSubtotal = basePrice / (1 + vatRate);
        subtotal += singleItemSubtotal * item.quantity;
    } else {
        const singleItemSubtotal = basePrice;
        subtotal += singleItemSubtotal * item.quantity;
    }
  });

  const { appliedPromotions, bonusInfo, discountPercentage } = calculatePromotions(items, subtotal, promotions);

  const discountApplied = subtotal * (discountPercentage / 100);
  const subtotalWithDiscount = subtotal - discountApplied;
  const vatAmount = subtotalWithDiscount * vatRate;
  const totalPrice = subtotalWithDiscount + vatAmount;

  return { totalItems, subtotal, subtotalWithDiscount, discountApplied, vatAmount, totalPrice, isVolumePricingActive, appliedPromotions, bonusInfo };
};

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],
      totalItems: 0,
      subtotal: 0,
      subtotalWithDiscount: 0,
      discountApplied: 0,
      vatAmount: 0,
      totalPrice: 0,
      isVolumePricingActive: false,
      promotions: [],
      appliedPromotions: [],
      bonusInfo: {},
      agreementId: null,
      pricesIncludeVat: true,
      vatPercentage: 21,
      
      setAgreement: (id: string, pricesIncludeVat: boolean, promotions: Promotion[], vatPercentage: number) => {
        const currentAgreementId = get().agreementId;
        if (id !== currentAgreementId) {
            set({ 
                agreementId: id, 
                pricesIncludeVat: pricesIncludeVat,
                promotions: promotions,
                vatPercentage: vatPercentage,
                items: [], 
                totalItems: 0, 
                subtotal: 0, 
                subtotalWithDiscount: 0,
                discountApplied: 0,
                vatAmount: 0, 
                totalPrice: 0,
                isVolumePricingActive: false,
                appliedPromotions: [],
                bonusInfo: {},
            });
        } else {
             const { items } = get();
             set({ 
                pricesIncludeVat: pricesIncludeVat,
                promotions: promotions,
                vatPercentage: vatPercentage,
                ...calculateAll(items, pricesIncludeVat, promotions, vatPercentage)
            });
        }
      },

      addItem: (product: ProductWithPrice, quantity: number = 1) => {
        const { items, pricesIncludeVat, promotions, vatPercentage } = get();
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
        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, promotions, vatPercentage) });
      },

      removeItem: (productId: string) => {
        const { items, pricesIncludeVat, promotions, vatPercentage } = get();
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

        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, promotions, vatPercentage) });
      },

      updateQuantity: (productId: string, quantity: number) => {
        const { pricesIncludeVat, promotions, vatPercentage } = get();
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
        set({ items: updatedItems, ...calculateAll(updatedItems, pricesIncludeVat, promotions, vatPercentage) });
      },
      
      getItemQuantity: (productId: string) => {
        const item = get().items.find(item => item.product.id === productId);
        return item ? item.quantity : 0;
      },

      clearCart: () => {
        set({ items: [], totalItems: 0, subtotal: 0, subtotalWithDiscount: 0, discountApplied: 0, vatAmount: 0, totalPrice: 0, isVolumePricingActive: false, appliedPromotions: [], bonusInfo: {} });
      },
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => localStorage),
      // Prevent persisting promotions, as they should be fetched on page load.
      partialize: (state) =>
        Object.fromEntries(
          Object.entries(state).filter(([key]) => !['promotions', 'appliedPromotions', 'bonusInfo'].includes(key))
        ),
      onRehydrateStorage: () => (state, error) => {
        if (state) {
            // Recalculate totals on rehydration, but with an empty promotions array
            const { totalItems, subtotal, subtotalWithDiscount, discountApplied, vatAmount, totalPrice, isVolumePricingActive } = calculateAll(state.items, state.pricesIncludeVat, [], state.vatPercentage);
            state.totalItems = totalItems;
            state.subtotal = subtotal;
            state.subtotalWithDiscount = subtotalWithDiscount;
            state.discountApplied = discountApplied;
            state.vatAmount = vatAmount;
            state.totalPrice = totalPrice;
            state.isVolumePricingActive = isVolumePricingActive;
            state.promotions = [];
            state.appliedPromotions = [];
            state.bonusInfo = {};
        }
      }
    }
  )
);
