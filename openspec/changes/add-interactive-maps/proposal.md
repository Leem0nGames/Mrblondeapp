## Why
To provide a visual and interactive way for administrators to understand the geographical distribution and location of their clients, improving operational planning and client management.

## What Changes
- **Interactive Maps**: Introduce interactive maps into the admin panel.
- **Client Location on Dashboard**: The main admin dashboard will feature a map of Argentina with pins indicating the location of all active clients.
- **Zoomed Map on Client Profile**: The client detail page will feature a map zoomed in on that specific client's address.
- **Database Enhancement**: The `clients` table will be updated to store latitude and longitude coordinates.
- **Geocoding Logic**: A new server action will be implemented to convert text addresses into coordinates using the Google Maps Geocoding API.
- **New Dependency**: The `@vis.gl/react-google-maps` package will be added to the project.

## Impact
- **Affected Specs**: `admin-dashboard`, `client-details` (a new spec will be created for this).
- **Affected Code**:
  - `src/lib/supabase/schema.sql`: To add `latitude` and `longitude` to the `clients` table.
  - `src/types/index.ts`: To update the `Client` type.
  - `src/app/admin/actions/clients.actions.ts`: To add the geocoding server action.
  - `src/app/admin/page.tsx`: To add the overview map.
  - `src/app/admin/clients/[id]/page.tsx`: To add the detailed map.
  - `package.json`: To add the new map library dependency.
- **Configuration**: Requires the user to obtain a Google Maps API Key and set it as `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` in their `.env.local` file.