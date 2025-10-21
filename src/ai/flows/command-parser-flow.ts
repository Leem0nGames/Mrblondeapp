
'use server';
/**
 * @fileOverview Un agente de IA que interpreta comandos en lenguaje natural para crear entidades comerciales.
 *
 * - commandParserFlow: La función principal que interpreta el comando.
 * - CommandParserInput: El tipo de entrada para el flujo.
 * - CommandParserOutput: El tipo de salida del flujo.
 */

import { ai } from '@/ai/genkit';
import { z } from 'zod';
import type { Product, PriceList } from '@/types';
import { getProducts } from '@/app/admin/actions/products.actions';
import { getPriceLists } from '@/app/admin/actions/pricelists.actions';


// --- Input Schema ---
const CommandParserInputSchema = z.object({
  command: z.string().describe('El comando en lenguaje natural ingresado por el usuario.'),
});
export type CommandParserInput = z.infer<typeof CommandParserInputSchema>;

// --- Output Schemas ---

const PromotionRuleSchema = z.object({
  type: z.enum(['buy_x_get_y_free', 'free_shipping', 'min_amount_discount']),
  buy: z.number().optional(),
  get: z.number().optional(),
  min_units: z.number().optional(),
  locations: z.array(z.string()).optional(),
  min_amount: z.number().optional(),
  percentage: z.number().optional(),
}).describe('Las reglas específicas de la promoción.');

const ParsedPromotionSchema = z.object({
  entity: z.enum(['promotion']),
  data: z.object({
    name: z.string().describe('Un nombre corto y descriptivo para la promoción.'),
    description: z.string().describe('Una descripción un poco más detallada.'),
    rules: PromotionRuleSchema,
  }),
}).describe('Una entidad de promoción, creada a partir del comando.');

const ParsedPriceListSchema = z.object({
    entity: z.enum(['pricelist']),
    data: z.object({
        name: z.string().describe('Un nombre descriptivo para la nueva lista de precios.'),
        base_price_list_id: z.string().uuid().describe('El ID de la lista de precios base sobre la cual se aplicará el descuento.'),
        discount_percentage: z.number().min(1).max(99).describe('El porcentaje de descuento a aplicar sobre la lista base.'),
        prices_include_vat: z.boolean().describe('Si los precios de la lista nueva incluyen IVA. Heredar de la lista base.'),
    }),
}).describe('Una nueva lista de precios creada con un descuento sobre una existente.');

const SalesConditionRuleSchema = z.object({
    type: z.enum(['net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery']),
    days: z.number().optional(),
    percentage: z.number().optional(),
    installments: z.number().optional(),
    initial_percentage: z.number().optional(),
    remaining_days: z.number().optional(),
}).describe('Las reglas específicas para la condición de venta.');

const ParsedSalesConditionSchema = z.object({
    entity: z.enum(['sales_condition']),
    data: z.object({
        name: z.string().describe('Un nombre corto y descriptivo para la condición de venta.'),
        description: z.string().describe('Una descripción un poco más detallada.'),
        rules: SalesConditionRuleSchema,
    }),
}).describe('Una condición de venta creada a partir del comando.');

const CommandParserOutputSchema = z.union([
    ParsedPromotionSchema,
    ParsedPriceListSchema,
    ParsedSalesConditionSchema,
]);
export type CommandParserOutput = z.infer<typeof CommandParserOutputSchema>;


// --- Main Exported Function ---
export async function commandParser(input: CommandParserInput): Promise<CommandParserOutput> {
  // Fetch dynamic data to provide context to the AI
  const [{ data: products }, { data: priceLists }] = await Promise.all([getProducts(), getPriceLists()]);

  return commandParserFlow({
      ...input,
      products: products ?? [],
      priceLists: priceLists ?? [],
  });
}

// --- Genkit Flow Definition ---
const dynamicInputSchema = CommandParserInputSchema.extend({
    products: z.array(z.any()),
    priceLists: z.array(z.any()),
});

const prompt = ai.definePrompt({
  name: 'commandParserPrompt',
  input: { schema: dynamicInputSchema },
  output: { schema: CommandParserOutputSchema },
  prompt: `
    Eres un asistente inteligente para "Mr. Blonde", una distribuidora de productos de belleza. Tu tarea es interpretar comandos en lenguaje natural de un administrador y convertirlos en objetos JSON estructurados para crear promociones, listas de precios o condiciones de venta.

    **Contexto disponible:**
    - Lista de Productos: {{{json products}}}
    - Listas de Precios existentes: {{{json priceLists}}}

    **Instrucciones:**
    1.  **Identifica la Entidad:** Determina si el comando busca crear una 'promotion', 'pricelist' o 'sales_condition'.
    2.  **Extrae los Datos:** Analiza el texto para extraer los detalles y poblar el campo 'data' del esquema correspondiente.
    3.  **Genera un Nombre y Descripción:** Crea un nombre y descripción claros y concisos basados en el comando.
    4.  **Aplica Lógica de Negocio:**
        -   Para **listas de precios**, el usuario mencionará un descuento sobre una lista existente. Debes encontrar el ID de la lista base y heredar su configuración de IVA.
        -   Para **promociones y condiciones**, extrae los parámetros numéricos y de texto para las reglas.
    5.  **Responde ÚNICAMENTE con el objeto JSON** que se adhiere a uno de los esquemas de salida. No incluyas explicaciones.

    **Ejemplos:**

    Comando: "crear promo 10+2 en Ceras The Shaving Co"
    Respuesta JSON:
    \`\`\`json
    {
      "entity": "promotion",
      "data": {
        "name": "Promo Ceras 10+2",
        "description": "Llevando 10 Ceras The Shaving Co, se bonifican 2.",
        "rules": {
          "type": "buy_x_get_y_free",
          "buy": 10,
          "get": 2
        }
      }
    }
    \`\`\`

    Comando: "nueva lista para revendedores con 15% de descuento sobre la lista 'Precios Barbería Enero 2024'"
    Respuesta JSON:
    \`\`\`json
    {
        "entity": "pricelist",
        "data": {
            "name": "Lista Revendedores (15% OFF)",
            "base_price_list_id": "uuid-de-la-lista-base",
            "discount_percentage": 15,
            "prices_include_vat": true
        }
    }
    \`\`\`

    Comando: "nueva condicion de pago a 60 dias"
    Respuesta JSON:
    \`\`\`json
    {
        "entity": "sales_condition",
        "data": {
            "name": "Pago a 60 días",
            "description": "Plazo de pago extendido a 60 días netos desde la fecha de factura.",
            "rules": {
                "type": "net_days",
                "days": 60
            }
        }
    }
    \`\`\`

    **Comando a procesar:**
    {{{command}}}
  `,
});

const commandParserFlow = ai.defineFlow(
  {
    name: 'commandParserFlow',
    inputSchema: dynamicInputSchema,
    outputSchema: CommandParserOutputSchema,
  },
  async (input) => {
    const { output } = await prompt(input);
    if (!output) {
      throw new Error("La IA no pudo interpretar el comando.");
    }
    return output;
  }
);
