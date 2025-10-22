## 1. Backend & Data Layer
- [ ] 1.1 **SQL Schema**: Modify the `promotions` table in `src/lib/supabase/schema.sql` to allow `rules` to optionally contain `product_ids` (array of UUIDs) or `category_names` (array of text).
- [ ] 1.2 **Types**: Update the `Promotion` type in `src/types/index.ts` to reflect the new optional fields in the `rules` JSONB.

## 2. Frontend Implementation
- [ ] 2.1 **Product Card Logic**: In `src/app/pedido/[id]/_components/product-card.tsx`, modify the component to accept the list of all agreement promotions as a prop.
- [ ] 2.2 **Filtering Logic**: Inside `ProductCard`, implement the logic to filter and find `buy_x_get_y_free` promotions that apply specifically to that product (based on product ID, category, or global application).
- [ ] 2.3 **UI - Promo Buttons**: Create and render a new `PromoButton` sub-component within the product card for each applicable promotion. This button will display the required quantity (e.g., "Llevar X").
- [ ] 2.4 **Action**: Wire the `onClick` event of the `PromoButton` to call the `addItem` action from the `useCartStore` with the correct promotion quantity.
- [ ] 2.5 **Page Integration**: In `src/app/pedido/[id]/page.tsx`, ensure the fetched `promotions` are passed down to each `ProductCard` component.

## 3. Final Review
- [ ] 3.1 Verify that promo buttons only appear for products matching promotion rules.
- [ ] 3.2 Test clicking a promo button adds the correct quantity to the cart.
- [ ] 3.3 Test that products in multiple promotions show multiple buttons.
- [ ] 3.4 Confirm that the order summary and applied promotions update correctly after using a promo button.
- [ ] 3.5 Mark this task list as complete.
