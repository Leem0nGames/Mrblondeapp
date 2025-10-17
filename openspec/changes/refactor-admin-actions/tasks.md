## 1. Create New Action Files
- [ ] 1.1 Create a new directory: `src/app/admin/actions/`.
- [ ] 1.2 Create the following empty files inside the new directory:
  - `products.actions.ts`
  - `clients.actions.ts`
  - `agreements.actions.ts`
  - `promotions.actions.ts`
  - `sales-conditions.actions.ts`
  - `pricelists.actions.ts`
  - `dashboard.actions.ts`
  - `_helpers.ts` (for shared functions like `getSupabaseClientWithAuth`, `upsertEntity`, `deleteEntity`).

## 2. Refactor and Move Code
- [ ] 2.1 Move the generic helper functions from `src/app/actions/admin.actions.ts` into `src/app/admin/actions/_helpers.ts` and ensure they are exported.
- [ ] 2.2 Move product-related actions (`getProducts`, `upsertProduct`, `deleteProduct`) into `products.actions.ts`.
- [ ] 2.3 Move client-related actions (`getClients`, `getClientById`, etc.) into `clients.actions.ts`.
- [ ] 2.4 Move agreement-related actions (`getAgreements`, `getAgreementById`, etc.) into `agreements.actions.ts`.
- [ ] 2.5 Move promotion-related actions into `promotions.actions.ts`.
- [ ] 2.6 Move sales-condition-related actions into `sales-conditions.actions.ts`.
- [ ] 2.7 Move price-list-related actions into `pricelists.actions.ts`.
- [ ] 2.8 Move dashboard-related actions (`getDashboardStats`, `getPendingOrders`, etc.) into `dashboard.actions.ts`.
- [ ] 2.9 Update all new action files to import helper functions from `./_helpers.ts` and other necessary types.

## 3. Update Import Paths in Frontend Components
- [ ] 3.1 Go through all files in `src/app/admin/` and its subdirectories.
- [ ] 3.2 For each file, find any import from ` "@/app/actions/admin.actions"`.
- [ ] 3.3 Update the import path to point to the new, specific action file in `src/app/admin/actions/`. For example, a component using `getProducts` will now import it from ` "@/app/admin/actions/products.actions"`.

## 4. Cleanup
- [ ] 4.1 Once all actions have been moved and all import paths have been updated, delete the original `src/app/actions/admin.actions.ts` file.
- [ ] 4.2 Run a type check to ensure all imports are resolved and there are no errors.