## Why
La herramienta actual de comandos por lenguaje natural solo permite crear promociones. Para hacerla una herramienta de gestión comercial completa, el administrador necesita poder crear también otras entidades clave, como listas de precios con descuentos y condiciones de venta, de una forma igual de rápida y flexible.

## What Changes
- Se ampliará el flujo de IA (`command-parser-flow.ts`) para que pueda interpretar comandos para crear:
  - **Listas de Precios**: Ej: "Crear lista de revendedores con 10% de descuento sobre la lista de precios de barberías".
  - **Condiciones de Venta**: Ej: "Crear nueva condición de pago a 30 días".
- Se actualizarán los esquemas de Zod en el flujo de IA para incluir las estructuras de `PriceList` y `SalesCondition`.
- El componente `CommandParser` del frontend se mantendrá igual, ya que su lógica de llamar a las `upsert actions` correspondientes ya es genérica y funcionará con las nuevas entidades.

## Impact
- **Affected Specs**: `admin-dashboard`.
- **Affected Code**:
  - `src/ai/flows/command-parser-flow.ts` (modificación principal).
  - `src/app/admin/commercial-settings/_components/command-parser.tsx` (posiblemente un ajuste menor para manejar `pricelist`).
- **New Files**: None.
- **Positive Impact**: El administrador podrá gestionar la configuración comercial de forma mucho más rápida y centralizada, usando únicamente la barra de comandos.