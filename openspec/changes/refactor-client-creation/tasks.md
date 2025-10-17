## 1. Backend & Data Layer
- [ ] 1.1 **Refactor Server Actions**: In `src/app/admin/actions/clients.actions.ts`, consolidate `createFullClient` and the logic from `submitOnboardingForm` into a single `upsertClient` action. This action should handle both creating a new client and updating an existing one based on the presence of an `id`.
- [ ] 1.2 **Cleanup Old Actions**: Remove the now-unused `createClientForInvitation` and `submitOnboardingForm` server actions from `clients.actions.ts` and `user.actions.ts`.
- [ ] 1.3 **Cleanup Onboarding Route**: Remove the `getOnboardingClient` action from `user.actions.ts` as the `/onboarding` route will no longer be used.

## 2. Frontend Component Refactoring
- [ ] 2.1 **Create Unified Form**: Create a new component `src/app/admin/clients/_components/upsert-client-form.tsx`. This component will contain the entire client data form, including fields for name, CUIT, address, contact details, fiscal status, and agreement assignment. It will be responsible for calling the new `upsertClient` action.
- [ ] 2.2 **Refactor Create Dialog**: Modify `src/app/admin/clients/_components/create-client-dialog.tsx`. Remove all logic related to generating and copying invitation links. Instead, make it a simple dialog that renders the new `upsert-client-form.tsx` in "create" mode (no initial entity).
- [ ] 2.3 **Refactor Edit Dialog**: Modify `src/app/admin/clients/[id]/_components/onboarding-form-dialog.tsx`. Rename it to `edit-client-dialog.tsx` (or similar) and refactor it to be a simple wrapper that renders `upsert-client-form.tsx` in "edit" mode, passing the existing client data to it.
- [ ] 2.4 **Update Client Table UI**: In `src/app/admin/clients/_components/clients-table.tsx`, remove all buttons and logic related to copying or managing "onboarding links".
- [ ] 2.5 **Update Client Detail UI**: In `src/app/admin/clients/[id]/_components/client-header.tsx`, remove any logic or UI elements related to the onboarding link.

## 3. Cleanup and Finalization
- [ ] 3.1 **Remove Onboarding Route**: Delete the entire `/onboarding/[token]` directory (`page.tsx`, `_components`, etc.) as it is now obsolete.
- [ ] 3.2 **Verify Flow**: Test the new end-to-end flow:
    - Create a client from the main clients page.
    - Edit that client from their detail page.
- [ ] 3.3 Mark this task list as complete.