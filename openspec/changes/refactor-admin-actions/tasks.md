## 1. Create New Action Files
- [x] 1.1 Create a new directory: `src/app/admin/actions/`.
- [x] 1.2 Create the following empty files inside the new directory:
  - `products.actions.ts`
  - `clients.actions.ts`
  - `agreements.actions.ts`
  - `promotions.actions.ts`
  - `sales-conditions.actions.ts`
  - `pricelists.actions.ts`
  - `dashboard.actions.ts`
  - `_helpers.ts` (for shared functions like `getSupabaseClientWithAuth`, `upsertEntity`, `deleteEntity`).

## 2. Refactor and Move Code
- [x] 2.1 Move the generic helper functions from `src/app/actions/admin.actions.ts` into `src/app/admin/actions/_helpers.ts` and ensure they are exported.
- [x] 2.2 Move product-related actions (`getProducts`, `upsertProduct`, `deleteProduct`) into `products.actions.ts`.
- [x] 2.3 Move client-related actions (`getClients`, `getClientById`, etc.) into `clients.actions.ts`.
- [x] 2.4 Move agreement-related actions (`getAgreements`, `getAgreementById`, etc.) into `agreements.actions.ts`.
- [x] 2.5 Move promotion-related actions into `promotions.actions.ts`.
- [x] 2.6 Move sales-condition-related actions into `sales-conditions.actions.ts`.
- [x] 2.7 Move price-list-related actions into `pricelists.actions.ts`.
- [x] 2.8 Move dashboard-related actions (`getDashboardStats`, `getPendingOrders`, etc.) into `dashboard.actions.ts`.
- [x] 2.9 Update all new action files to import helper functions from `./_helpers.ts` and other necessary types.

## 3. Update Import Paths in Frontend Components
- [x] 3.1 Go through all files in `src/app/admin/` and its subdirectories.
- [x] 3.2 For each file, find any import from ` "@/app/actions/admin.actions"`.
- [x] 3.3 Update the import path to point to the new, specific action file in `src/app/admin/actions/`. For example, a component using `getProducts` will now import it from ` "@/app/admin/actions/products.actions"`.

## 4. Cleanup
- [x] 4.1 Once all actions have been moved and all import paths have been updated, delete the original `src/app/actions/admin.actions.ts` file.
- [x] 4.2 Run a type check to ensure all imports are resolved and there are no errors.
