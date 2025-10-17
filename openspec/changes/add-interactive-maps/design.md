## Context
The application currently stores client addresses as text strings. To visually represent client locations, we need to integrate an interactive map component and convert these text addresses into geographic coordinates (latitude and longitude).

## Goals
- Display an interactive map on the client detail page, centered on that client's location.
- Display an interactive map on the main admin dashboard, showing markers for all active clients.
- Implement an efficient geocoding strategy to convert addresses to coordinates without excessive API calls.

## Decisions

### 1. Map Technology
- **Decision:** We will use the official `@vis.gl/react-google-maps` library.
- **Rationale:** It's a modern, well-supported library that integrates seamlessly with React/Next.js. It provides all the necessary components (`APIProvider`, `Map`, `AdvancedMarker`) for our use case. It also requires an API key, which aligns with standard practice for using Google Maps services.

### 2. Geocoding and Data Storage
- **Decision:** We will add `latitude` and `longitude` columns of type `float8` to the `clients` table in the database.
- **Rationale:** Storing coordinates directly in the database is the most performant and cost-effective solution. It avoids making a geocoding API call every time a map is loaded. The geocoding process will be a one-time operation per client address.
- **Implementation:**
  - A new server action, `geocodeAddressAndSave`, will be created.
  - This action will be triggered from the client detail page if that client is missing coordinates.
  - It will call the Google Maps Geocoding API, retrieve the lat/lng, and update the corresponding row in the `clients` table.

### 3. API Key Management
- **Decision:** The Google Maps API key will be managed via an environment variable `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`.
- **Rationale:** This is the standard and secure way to handle API keys in a Next.js application. Making it public (`NEXT_PUBLIC_`) is required by the Google Maps library, and access is typically controlled through API key restrictions in the Google Cloud Console.

### 4. Component Architecture
- **Decision:** A new reusable component, `src/app/admin/_components/client-map.tsx`, will be created.
- **Rationale:** This component will encapsulate the map logic, making it easy to use in different parts of the application with different props (e.g., a single marker vs. multiple markers).
- **Implementation Details:**
  - The `ClientMap` component will accept props like `clients` (an array of client objects with coordinates), `zoom`, and a `center` coordinate.
  - On the dashboard, it will be used to display all clients.
  - On the client detail page, it will be passed a single client and a higher zoom level.

### 5. Fallback and Loading States
- **Decision:** If a client's coordinates are not yet available, the map component on the detail page will show a loading state or a message indicating that the address is being geocoded.
- **Rationale:** This provides a good user experience, informing the admin that a background process is happening.

## Risks
- **Geocoding Failures:** Addresses might be malformed or too ambiguous for the Geocoding API to understand. The application logic must gracefully handle cases where geocoding fails, likely by showing an error in the UI and allowing the admin to correct the address.
- **API Key Costs:** The Google Maps Platform is a paid service. The user must be aware of the potential for costs associated with API usage (Geocoding API, Maps JavaScript API). Our strategy to store coordinates minimizes this risk.