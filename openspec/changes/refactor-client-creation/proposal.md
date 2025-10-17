## Why
The current client creation process is based on an invitation-only flow, which is unnecessarily complex for an administrator who often has the client's information upfront. It requires multiple steps (generate link, send to client, client fills form, admin assigns agreement) and makes it impossible for an admin to create a client directly.

## What Changes
- **Remove Invitation Flow**: The entire concept of generating an "onboarding" link will be removed.
- **Direct Client Creation**: The "Add Client" button will now open a comprehensive form for the administrator to create a new client directly in one step.
- **Unified Form Component**: A new reusable component, `upsert-client-form.tsx`, will be created to handle both creating a new client and editing an existing one, eliminating code duplication between the old `CreateClientDialog` and `OnboardingFormDialog`.
- **Unified Server Action**: The multiple server actions (`createClientForInvitation`, `submitOnboardingForm`, `createFullClient`) will be replaced by a single, robust `upsertClient` action that handles both creation and updates.
- **UI Simplification**: The `CreateClientDialog` will be refactored to use the new unified form. The `OnboardingFormDialog` will be simplified to just be an "Edit Client" dialog, also using the unified form. All UI elements related to copying onboarding links will be removed.

## Impact
- **Affected Specs**: `admin-dashboard` (client management part).
- **Affected Code**:
  - `src/app/admin/clients/_components/create-client-dialog.tsx` (major refactor)
  - `src/app/admin/clients/[id]/_components/onboarding-form-dialog.tsx` (refactor to edit-only)
  - `src/app/admin/actions/clients.actions.ts` (major refactor of actions)
  - `src/app/onboarding/` (this entire route will be deprecated and can be removed)
  - `src/app/admin/clients/_components/clients-table.tsx` (remove "copy onboarding link" buttons)
  - `src/app/admin/clients/[id]/_components/client-header.tsx` (remove onboarding link logic)
- **New Files**: `src/app/admin/clients/_components/upsert-client-form.tsx`
- **Positive Impact**:
  - Drastically simplifies and speeds up the client creation workflow for the administrator.
  - Improves code maintainability by removing redundant components and server actions.
  - Makes the application's logic more straightforward and easier to understand.