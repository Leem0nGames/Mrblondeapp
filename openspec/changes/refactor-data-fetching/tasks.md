## 1. Backend Optimization
- [ ] 1.1 **DB Schema**: Add the new `get_notification_counts` function to `src/lib/supabase/schema.sql` and modify `dashboard_stats` view to include `overdue_orders_count`.
- [ ] 1.2 **Dashboard Actions**:
    - Create a new `getNotificationData` server action in `dashboard.actions.ts` that calls the new DB function.
    - Create a new `getDashboardData` server action that consolidates fetching for stats, pending orders, and pending clients.
- [ ] 1.3 **Layout Update**: Modify `src/app/admin/layout.tsx` to use the new `getNotificationData` action instead of three separate calls.
- [ ] 1.4 **Dashboard Page Update**: Modify `src/app/admin/page.tsx` to use the new `getDashboardData` action.

## 2. Client Form Refactoring
- [ ] 2.1 **Create Unified Form**: Create a new component `src/app/admin/clients/_components/upsert-client-form.tsx` that contains the entire client data form logic (based on the current `onboarding-form.tsx`).
- [ ] 2.2 **Update Onboarding/Edit Dialog**: Refactor `src/app/admin/clients/[id]/_components/onboarding-form-dialog.tsx` to be a simple wrapper around the new `upsert-client-form.tsx`.
- [ ] 2.3 **Update Create Client Dialog**: Refactor `src/app/admin/clients/_components/create-client-dialog.tsx` to use the new `upsert-client-form.tsx` for creating clients from scratch, removing the invitation-only flow.
- [ ] 2.4 **Update Client Actions**: Modify `createFullClient` and `submitOnboardingForm` actions in `clients.actions.ts` to be a single `upsertClient` action that handles both creation and updates.

## 3. Final Review
- [ ] 3.1 Verify that notifications still load correctly.
- [ ] 3.2 Verify that the admin dashboard still loads all data correctly.
- [ ] 3.3 Test creating a new client from the "Clients" page.
- [ ] 3.4 Test editing an existing client from their detail page.
- [ ] 3.5 Mark this task list as complete.
