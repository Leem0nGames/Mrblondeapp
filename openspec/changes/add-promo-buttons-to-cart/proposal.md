## Why
The current process of adding items to the cart is slow for clients placing large orders, especially when they want to take advantage of volume-based promotions (e.g., "Buy 10, Get 2 Free"). They have to click the quantity increment button many times.

## What Changes
- **Add "Promo Buttons"**: On the client order page (`/pedido/[id]`), each product card will display small, quick-action buttons for any applicable "buy X, get Y" promotions.
- **Quick Add**: For a "Buy 10, Get 2 Free" promo, a button labeled "Llevar 10" will appear. Clicking it will instantly add 10 units of that product to the cart.
- **Dynamic Display**: The buttons will only appear on products that are part of an active `buy_x_get_y_free` promotion. A product can have multiple promo buttons if it's part of multiple deals.

## Impact
- **Affected Specs**: `client-orders`
- **Affected Code**:
  - `src/app/pedido/[id]/_components/product-card.tsx`: This component will be modified to include the new buttons and the logic to display them.
  - No changes are expected in the cart's state management (`use-cart-store.ts`) as the buttons will use the existing `addItem` action.
- **Positive Impact**: Significantly improves the speed and user experience for clients placing large or promotion-driven orders.
