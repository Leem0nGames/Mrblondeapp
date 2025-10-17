## Why
The main server action file for the admin panel, `src/app/actions/admin.actions.ts`, has become a monolith, handling the logic for numerous distinct entities (Products, Clients, Agreements, Promotions, etc.). This makes the codebase harder to navigate, maintain, and scale. A refactoring is needed to improve modularity and align with best practices for larger applications.

## What Changes
- The single `src/app/actions/admin.actions.ts` file will be broken down into smaller, domain-specific action files.
- A new directory `src/app/admin/actions/` will be created to house these new files.
- New files will be created, such as:
  - `products.actions.ts`
  - `clients.actions.ts`
  - `agreements.actions.ts`
  - `promotions.actions.ts`
  - `sales-conditions.actions.ts`
  - `pricelists.actions.ts`
  - `dashboard.actions.ts`
- The generic helper functions (`getSupabaseClientWithAuth`, `upsertEntity`, `deleteEntity`) will be moved to a shared location if necessary or kept within a general-purpose action file.
- All frontend components that import from the old `admin.actions.ts` will be updated to import from the new, specific action files.

## Impact
- **Affected Specs**: None directly, as this is a code refactoring. The external behavior of the application will not change. We will add a note to the `admin-dashboard` spec to reflect the new code structure.
- **Affected Code**:
  - `src/app/actions/admin.actions.ts` (will be removed or split).
  - All admin-side components that use server actions will need their import paths updated. This includes pages and components under `src/app/admin/`.
- **Positive Impact**: Greatly improved code organization, maintainability, and developer experience.