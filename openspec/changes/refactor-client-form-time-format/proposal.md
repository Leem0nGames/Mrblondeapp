## Why
The current client form uses a standard HTML time input, which can default to an AM/PM format in some browsers. This leads to inconsistent data entry and potential confusion. Switching to an explicit 24-hour format selector will standardize the data and improve the user experience for setting delivery windows.

## What Changes
- **Replace Time Inputs with Selects**: The `<Input type="time">` fields for `delivery_time_from` and `delivery_time_to` in the client forms will be replaced with `<Select>` components from shadcn/ui.
- **24-Hour Options**: A utility function will be created to generate an array of time options in 24-hour format (e.g., "08:00", "09:00", ..., "20:00") to populate the new select dropdowns.
- **Consistent UI**: The same change will be applied to both the admin-facing `upsert-client-form.tsx` and the client-facing `onboarding-form.tsx` to ensure a consistent experience across the application.

## Impact
- **Affected Specs**: `admin-dashboard` (client management part).
- **Affected Code**:
  - `src/app/admin/clients/_components/upsert-client-form.tsx`
  - `src/app/onboarding/[token]/_components/onboarding-form.tsx`
- **Positive Impact**:
  - Standardizes time data entry into a 24-hour format.
  - Provides a clearer and more controlled UI for selecting times.
  - Eliminates browser inconsistencies with time inputs.
