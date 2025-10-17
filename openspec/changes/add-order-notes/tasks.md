## 1. Database Schema
- [ ] 1.1. Modify `src/lib/supabase/schema.sql` to add a `notes TEXT` column to the `orders` table.

## 2. Client-Facing Changes
- [ ] 2.1. Update `src/types/index.ts` to include `notes` in the `Order` type.
- [ ] 2.2. Update the `submitOrder` action in `src/app/actions/user.actions.ts` to accept and save the `notes` field.
- [ ] 2.3. Modify `src/app/pedido/[id]/_components/order-summary.tsx` to include a `Textarea` for the client to write their note.
- [ ] 2.4. Pass the note from the state to the `submitOrder` action.

## 3. Admin Dashboard Changes
- [ ] 3.1. Update the `getPendingOrders` action in `src/app/actions/admin.actions.ts` to fetch the `notes` field.
- [ ] 3.2. Modify `src/app/admin/_components/recent-orders.tsx` to display a small icon or badge if an order has a note.
- [ ] 3.3. Create a new component `src/app/admin/_components/order-note-widget.tsx` for the floating, minimizable, and closable note view.
- [ ] 3.4. Integrate the `OrderNoteWidget` into `src/app/admin/_components/recent-orders.tsx`, making it appear when the note icon is clicked.
