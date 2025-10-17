## 1. Backend
- [x] 1.1 **DB Schema**: Alter the `orders` table to include a new `TEXT` column named `notes`.
- [x] 1.2 **Types**: Update the `Order` type in `src/types/index.ts` to include the optional `notes?: string | null` field.
- [x] 1.3 **Server Action (Write)**: Modify the `submitOrder` action in `src/app/actions/user.actions.ts` to accept and save the `notes` payload.
- [x] 1.4 **Server Action (Read)**: Modify the `getPendingOrders` action in `src/app/actions/admin.actions.ts` to select and return the new `notes` field.

## 2. Frontend (Client-Side)
- [x] 2.1 **UI**: Add a `Textarea` component to the `OrderSummarySheet` in `src/app/pedido/[id]/_components/order-summary.tsx` for the user to input their note.
- [x] 2.2 **State Management**: Pass the notes content to the `submitOrder` server action.

## 3. Frontend (Admin-Side)
- [x] 3.1 **UI**: In `src/app/admin/_components/recent-orders.tsx`, add a visual indicator (e.g., a `StickyNote` icon) next to orders that have a non-empty `notes` field.
- [x] 3.2 **Floating Widget**: Create a new component `src/app/admin/_components/order-note-widget.tsx` that displays the note text and can be closed or minimized.
- [x] 3.3 **Interaction**: Implement the logic in `recent-orders.tsx` to manage the state of the floating widget (which note is active, which are minimized) when the note icon is clicked.
