## Why
The application currently performs multiple, separate database queries for related data, especially in the admin layout (for notifications) and the main dashboard. This leads to unnecessary database load and can slow down page navigation. Additionally, there is duplicated logic for creating and editing clients across different components, making maintenance difficult.

## What Changes
- **Consolidate Notification Queries**: Create a single database function (`get_notification_counts`) and a single server action (`getNotificationData`) to fetch all data required for the notification bell in one go, instead of three separate queries on every admin page load.
- **Consolidate Dashboard Queries**: Create a single server action (`getDashboardData`) to fetch all statistics and lists required for the main admin dashboard, simplifying the data fetching logic on the page.
- **Refactor Client Forms**: Unify the logic for creating a new client and editing an existing one into a single, reusable form component (`upsert-client-form.tsx`). The existing dialog components (`CreateClientDialog`, `OnboardingFormDialog`) will be refactored to use this new central component, eliminating code duplication.

## Impact
- **Affected Specs**: `admin-dashboard`.
- **Affected Code**:
  - `src/lib/supabase/schema.sql`: To add the new `get_notification_counts` function.
  - `src/app/admin/layout.tsx`: To use the new `getNotificationData` action.
  - `src/app/admin/page.tsx`: To use the new `getDashboardData` action.
  - `src/app/admin/actions/dashboard.actions.ts`: Will be updated with the new consolidated actions.
  - `src/app/admin/clients/_components/`: Several components will be refactored or created to support the new unified client form.
- **Positive Impact**:
  - Reduced database load and faster page loads in the admin panel.
  - Improved code maintainability and reduced complexity by removing redundant code.
  - A more scalable and professional data fetching strategy.