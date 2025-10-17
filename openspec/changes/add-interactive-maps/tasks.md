## 1. Environment and Dependencies
- [x] 1.1 Add `@vis.gl/react-google-maps` to `package.json`.
- [x] 1.2 Remind the user to create a `.env.local` file and add their `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`.

## 2. Backend and Data Structure
- [x] 2.1 **DB Schema**: Alter the `clients` table in `src/lib/supabase/schema.sql` to include `latitude` and `longitude` columns (`float8`).
- [x] 2.2 **Types**: Update the `Client` type in `src/types/index.ts` to include the optional `latitude` and `longitude` fields.
- [x] 2.3 **Server Action**: Create a new server action `geocodeAddressAndSave(clientId: string, address: string)` in `src/app/admin/actions/clients.actions.ts`. This action will call the Google Geocoding API and update the client's row with the new coordinates.

## 3. Frontend Implementation
- [x] 3.1 **Map Component**: Create a new reusable component `src/app/admin/_components/client-map.tsx`. This component will render the map and markers.
- [x] 3.2 **Client Detail Page**:
    - Modify `src/app/admin/clients/[id]/page.tsx` and `client-details-client.tsx`.
    - Add the `ClientMap` component.
    - Implement a client-side effect that calls the `geocodeAddressAndSave` action if the client has an address but no coordinates.
- [x] 3.3 **Dashboard Page**:
    - Modify `src/app/admin/page.tsx`.
    - Fetch all clients with coordinates.
    - Add the `ClientMap` component to display all clients.

## 4. Final Review
- [x] 4.1 Verify that maps load correctly on both the dashboard and client detail pages.
- [x] 4.2 Confirm that clicking a marker on the dashboard map shows the client's name.
- [x] 4.3 Test the automatic geocoding process on a client detail page.
- [x] 4.4 Mark this task list as complete.
