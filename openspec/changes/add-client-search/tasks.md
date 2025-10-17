## 1. Backend Logic
- [ ] 1.1 **Update Server Action**: Modify the `getClients` function in `src/app/admin/actions/clients.actions.ts` to accept an optional `query: string` parameter.
- [ ] 1.2 **Update Database Query**: Inside `getClients`, use the `query` parameter to add a `.or()` filter to the Supabase query, searching for matches in `contact_name`, `cuit`, and `address` using the `ilike` operator for case-insensitive matching.

## 2. Frontend Implementation
- [ ] 2.1 **Create Search Component**: Create a new client component `src/app/admin/clients/_components/search-clients.tsx`. This component will render an `Input` with a search icon.
- [ ] 2.2 **Implement Search Logic**: In `search-clients.tsx`, use the `useRouter`, `usePathname`, and `useSearchParams` hooks to update the URL's query string as the user types, debouncing the input to avoid excessive re-renders.
- [ ] 2.3 **Update Clients Page**: Modify `src/app/admin/clients/page.tsx` to:
    - Read the search query from its `searchParams` prop.
    - Pass the query to the `getClients` server action.
    - Render the new `SearchClients` component in the `PageHeader`.

## 3. Final Review
- [ ] 3.1 Verify that searching by name, CUIT, and parts of an address filters the client list correctly.
- [ ] 3.2 Confirm that clearing the search bar displays the full list of clients again.
- [ ] 3.3 Ensure the empty state message is shown when a search yields no results.
- [ ] 3.4 Mark this task list as complete.
