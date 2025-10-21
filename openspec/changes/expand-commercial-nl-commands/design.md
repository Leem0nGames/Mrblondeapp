## Context
El sistema tiene un flujo de Genkit (`command-parser-flow`) que interpreta comandos de texto para crear promociones. Esta propuesta busca expandir esa capacidad para incluir listas de precios y condiciones de venta.

## Decisions

### 1. Extender el Flujo de IA
- **Decision:** Se modificará el `commandParserFlow` existente en `src/ai/flows/command-parser-flow.ts`.
- **Rationale:** Es más eficiente y mantenible tener un único flujo intérprete de comandos que pueda discernir la intención del usuario, en lugar de crear flujos separados para cada entidad.

### 2. Esquema de Salida Unificado (Union)
- **Decision:** La salida del flujo de IA será un `z.union()` de esquemas de Zod. Cada esquema representará una entidad posible (`ParsedPromotionSchema`, `ParsedPriceListSchema`, `ParsedSalesConditionSchema`).
- **Rationale:** Esto permite a la IA decidir qué estructura devolver y nos da una validación de tipo estricta en el frontend para manejar la respuesta. Cada esquema tendrá un campo `entity` (`promotion`, `pricelist`, `sales_condition`) que actuará como un discriminador.

### 3. Contexto Dinámico para la IA
- **Decision:** Antes de llamar al flujo de Genkit, la función `commandParser` obtendrá las listas de precios existentes y se las pasará a la IA como contexto.
- **Rationale:** Esto es crucial para que la IA pueda cumplir con comandos como "crear lista con 15% de descuento sobre la lista 'Precios Enero'". La IA necesita saber qué listas existen para encontrar el `base_price_list_id` correcto.

### 4. Lógica de Frontend
- **Decision:** El componente `CommandParser.tsx` recibirá el objeto JSON del flujo y usará un `switch` en el campo `entity` para determinar a qué `server action` de `upsert` debe llamar.
- **Rationale:** Esto mantiene la lógica de escritura en las `server actions` dedicadas y seguras, mientras que el frontend actúa como un orquestador. No se necesitan cambios mayores en el frontend, ya que este patrón ya está implementado para las promociones.
