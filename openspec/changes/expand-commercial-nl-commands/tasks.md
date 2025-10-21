## 1. Backend (IA Flow)
- [x] 1.1 En `src/ai/flows/command-parser-flow.ts`, actualizar el `CommandParserOutputSchema` para que sea un `z.union()` que incluya los esquemas para `PriceList` y `SalesCondition`.
- [x] 1.2 Crear los esquemas de Zod `ParsedPriceListSchema` y `ParsedSalesConditionSchema`.
- [x] 1.3 Modificar el `prompt` para que la IA entienda cómo interpretar comandos para las nuevas entidades, incluyendo ejemplos.
- [x] 1.4 Modificar la función `commandParser` para que obtenga y pase las listas de precios existentes al flujo como contexto.

## 2. Frontend
- [x] 2.1 En `src/app/admin/commercial-settings/_components/command-parser.tsx`, expandir la lógica `handleSubmit` para que el `switch` sobre `result.entity` también maneje los casos `'pricelist'` y `'sales_condition'`.
- [x] 2.2 Asegurarse de que el payload para `upsertPriceList` se maneje correctamente, ya que puede tener campos que no van directamente a la base de datos (como el nombre de la lista base).

## 3. Finalización
- [x] 3.1 Probar los tres tipos de comandos (promoción, lista de precios, condición de venta) para verificar que se creen correctamente.
- [x] 3.2 Marcar esta lista de tareas como completada.
