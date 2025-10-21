## Why
El administrador necesita una forma más rápida y flexible de crear promociones, listas de precios y condiciones de venta usando comandos en lenguaje natural.  
Actualmente, el sistema solo permite formularios manuales, lo que puede ser lento y propenso a errores de tipeo.

## What Changes
- Se añade un flujo de **comandos en lenguaje natural** para crear:  
  - promociones (“2x1”, “descuento %”, “envío gratis”),  
  - listas de precios con descuento aplicado,  
  - condiciones de venta (“net 30 días”, “entrega semanal”),  
- Se implementa un intérprete que parsea el texto libre → datos estructurados.  
- Se conecta con la base de datos (Supabase) para insertar registros automáticamente.  
- **No se eliminan** los formularios manuales existentes; esta es una **funcionalidad adicional**, opcional para los administradores.

## Impact
- Afecta los componentes del admin: productos, promociones, listas de precios, condiciones de venta.  
- Afecta archivos y rutas: `src/app/admin/promotions`, `src/app/admin/price-lists`, `src/app/admin/sale-conditions`, `src/ai/flows/commandParser.ts`.  
- Afecta la base de datos: tablas `promotions`, `price_lists`, `sale_conditions`.
