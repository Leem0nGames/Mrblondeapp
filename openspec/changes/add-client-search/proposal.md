## Why
To allow administrators to quickly find specific clients in a potentially long list, improving administrative efficiency. Searching by name, CUIT, or locality provides flexible ways to locate a client record.

## What Changes
- **Search UI**: A search input field will be added to the "Clients" page (`/admin/clients`).
- **Backend Logic**: The `getClients` server action will be updated to accept a search query string. It will use this query to filter clients in the database, searching for partial matches in the `contact_name`, `cuit`, and `address` fields.
- **Client-Side Component**: A new interactive client component (`search-clients.tsx`) will be created to handle user input in the search bar. This component will update the URL with the search query, triggering a re-render of the server component with the filtered results.

## Impact
- **Affected Specs**: `admin-dashboard`
- **Affected Code**:
  - `src/app/admin/actions/clients.actions.ts`: To modify the `getClients` function.
  - `src/app/admin/clients/page.tsx`: To add the search component and pass the query.
  - `src/app/admin/clients/_components/clients-table.tsx`: No functional change, but will receive filtered data.
- **New Files**:
  - `src/app/admin/clients/_components/search-clients.tsx`: The new search input component.
- **Positive Impact**: Significantly improves the usability and efficiency of the client management page.