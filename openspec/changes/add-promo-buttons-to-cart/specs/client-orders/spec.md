## MODIFIED Requirements
### Requirement: Add Products to Cart
The system SHALL allow a client to add products to their shopping cart. The interface SHOULD provide controls to increment, decrement, and directly add quantities related to promotions.

#### Scenario: Client adds one item
- **GIVEN** a client is on the order page.
- **WHEN** they click the "Agregar" or "+" button on a product.
- **THEN** the quantity of that product in the cart SHALL increase by 1.
- **AND** the order summary SHALL update to reflect the new total.

#### Scenario: Client uses a promotion button
- **GIVEN** a product is part of a "Buy 10, Get 2 Free" promotion.
- **AND** a button labeled "Llevar 10" is visible on the product card.
- **WHEN** the client clicks the "Llevar 10" button.
- **THEN** the quantity of that product in the cart SHALL increase by 10.
- **AND** the order summary SHALL update, and the "Buy 10, Get 2 Free" promotion bonus SHALL be reflected.

#### Scenario: Product with no applicable promotions
- **GIVEN** a product is not part of any `buy_x_get_y_free` promotion.
- **WHEN** a client views its product card.
- **THEN** no promotional quick-add buttons SHALL be visible, only the standard quantity selector.
