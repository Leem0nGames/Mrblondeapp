## Context
The current order page (`/pedido/[id]`) allows clients to add products to the cart one by one using a quantity selector. For "buy X, get Y free" promotions, clients have to manually click the "+" button `X` times, which is inefficient for large orders.

## Goal
To speed up the ordering process by providing quick-action buttons on product cards that correspond to available "buy X, get Y" promotions.

## Decisions

### 1. Component-Level Logic
- **Decision:** The logic to find and display promotion buttons will be handled directly within the `ProductCard.tsx` component.
- **Rationale:** This keeps the logic localized to the component that needs it. The main page component (`/pedido/[id]/page.tsx`) will pass down the list of all active promotions for the agreement, and the `ProductCard` will be responsible for filtering which promotions apply to itself.

### 2. Filtering Promotions
- **Decision:** A promotion of type `buy_x_get_y_free` will be considered applicable to a product if it meets **one** of the following criteria:
    1. The promotion's rules have a `product_ids` array that explicitly includes the current product's ID.
    2. The promotion's rules have a `category_names` array that includes the current product's category.
    3. The promotion has neither `product_ids` nor `category_names` defined, making it a "global" promotion applicable to all products.
- **Rationale:** This provides a flexible and hierarchical system for applying promotions, from specific products to entire categories to global deals.

### 3. State Management
- **Decision:** The new promotion buttons will leverage the existing `useCartStore` hook, specifically the `addItem(product, quantity)` action.
- **Rationale:** No changes are needed in the Zustand store. The buttons will simply call the existing action with the required quantity (the `buy` value from the promotion rule), making the implementation clean and reusing existing logic.

### 4. UI Implementation
- **Decision:** A new component, `PromoButton`, will be created inside `ProductCard.tsx`. This button will display the promotion quantity (e.g., "Llevar 10"). Multiple buttons will be rendered if a product is part of multiple promotions.
- **Rationale:** This encapsulates the button's appearance and logic, keeping the main `ProductCard` component cleaner. The buttons will be displayed in a small, horizontal group next to the main quantity selector.
