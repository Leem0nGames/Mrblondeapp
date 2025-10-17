## Why
Los administradores necesitan una forma de recibir instrucciones o comentarios específicos de los clientes junto con sus pedidos. Actualmente, no hay un campo para que los clientes agreguen notas, lo que puede llevar a errores de comunicación o a la necesidad de un seguimiento manual por fuera de la plataforma.

## What Changes
- **BREAKING**: Se modificará la tabla `orders` en la base de datos para añadir una columna `notes` de tipo `TEXT`.
- Se añadirá un campo de texto en la hoja de resumen del pedido (`OrderSummarySheet`) para que los clientes puedan escribir una nota.
- La nota del pedido se guardará en la base de datos junto con el resto de los detalles del pedido.
- En el panel de administración, los pedidos con notas mostrarán un indicador visual.
- El administrador podrá ver la nota completa en un componente flotante (widget) que se podrá minimizar o cerrar.

## Impact
- **Affected Specs**: `client-orders`, `admin-dashboard` (nuevas especificaciones).
- **Affected Code**:
  - `src/lib/supabase/schema.sql`: Modificar la tabla `orders`.
  - `src/app/pedido/[id]/_components/order-summary.tsx`: Añadir campo de texto para la nota.
  - `src/app/actions/user.actions.ts`: Actualizar la acción `submitOrder` para incluir la nota.
  - `src/app/admin/page.tsx`: Obtener los pedidos con notas.
  - `src/app/admin/_components/recent-orders.tsx`: Mostrar un indicador de nota.
  - Se creará un nuevo componente para el widget de notas flotantes en el dashboard.
