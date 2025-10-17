## 1. Environment and Dependencies
- [ ] 1.1 Add `@vis.gl/react-google-maps` to `package.json`.
- [ ] 1.2 Remind the user to create a `.env.local` file and add their `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`.

## 2. Backend and Data Structure
- [ ] 2.1 **DB Schema**: Alter the `clients` table in `src/lib/supabase/schema.sql` to include `latitude` and `longitude` columns (`float8`).
- [ ] 2.2 **Types**: Update the `Client` type in `src/types/index.ts` to include the optional `latitude` and `longitude` fields.
- [ ] 2.3 **Server Action**: Create a new server action `geocodeAddressAndSave(clientId: string, address: string)` in `src/app/admin/actions/clients.actions.ts`. This action will call the Google Geocoding API and update the client's row with the new coordinates.

## 3. Frontend Implementation
- [ ] 3.1 **Map Component**: Create a new reusable component `src/app/admin/_components/client-map.tsx`. This component will render the map and markers.
- [ ] 3.2 **Client Detail Page**:
    - Modify `src/app/admin/clients/[id]/page.tsx` and `client-details-client.tsx`.
    - Add the `ClientMap` component.
    - Implement a client-side effect that calls the `geocodeAddressAndSave` action if the client has an address but no coordinates.
- [ ] 3.3 **Dashboard Page**:
    - Modify `src/app/admin/page.tsx`.
    - Fetch all clients with coordinates.
    - Add the `ClientMap` component to display all clients.

## 4. Final Review
- [ ] 4.1 Verify that maps load correctly on both the dashboard and client detail pages.
- [ ] 4.2 Confirm that clicking a marker on the dashboard map shows the client's name.
- [ ] 4.3 Test the automatic geocoding process on a client detail page.
- [ ] 4.4 Mark this task list as complete.