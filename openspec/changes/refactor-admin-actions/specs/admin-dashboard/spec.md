## MODIFIED Requirements
### Requirement: Code Modularity and Organization
The system's backend logic, specifically Server Actions, SHALL be organized into modular, domain-specific files. A single, monolithic file for all admin actions is not desirable.

#### Scenario: Location of product actions
- **GIVEN** a developer needs to modify the logic for creating a product.
- **WHEN** they look for the server action.
- **THEN** they SHALL find it within a file dedicated to product-related actions (e.g., `products.actions.ts`), not in a generic `admin.actions.ts`.

#### Scenario: Location of client actions
- **GIVEN** a developer needs to modify the logic for fetching client data.
- **WHEN** they look for the server action.
- **THEN** they SHALL find it within a file dedicated to client-related actions (e.g., `clients.actions.ts`).