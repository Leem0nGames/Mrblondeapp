
"use server";
/**
 * @fileOverview Flujo de Genkit para sugerir promociones inteligentes a los clientes.
 *
 * - suggestPromotions: Analiza el carrito de un cliente y las promociones disponibles
 *   para recomendar las más ventajosas.
 * - SuggestPromotionsInput: El tipo de entrada para el flujo.
 * - SuggestPromotionsOutput: El tipo de retorno del flujo.
 */

import { ai } from "@/ai/genkit";
import { z } from "zod";
import type { SuggestPromotionsInput, SuggestPromotionsOutput } from "@/types";

// Re-exportar tipos para que puedan ser importados desde este archivo.
export type { SuggestPromotionsInput, SuggestPromotionsOutput };

const SuggestionSchema = z.object({
  name: z.string().describe("El nombre corto y llamativo de la promoción sugerida."),
  reason: z.string().describe("Una explicación breve y convincente de por qué esta promoción es una buena idea para el cliente en este momento."),
});

const IntelligentPromoOutputSchema = z.object({
  promotionSuggestions: z.array(SuggestionSchema),
});


const intelligentPromoPrompt = ai.definePrompt({
    name: "intelligentPromoSuggestion",
    input: { schema: z.any() },
    output: { schema: IntelligentPromoOutputSchema },
    prompt: `
        Eres un asistente de ventas experto para una distribuidora de productos de belleza llamada "Blonde".
        Tu objetivo es analizar el carrito de compras de un cliente y las promociones vigentes para su convenio,
        y darle sugerencias inteligentes para que aproveche al máximo las ofertas, aumentando así el valor de su pedido.

        Analiza los siguientes datos:
        - Cliente: {{nombre}}
        - Items en el carrito: {{json items}}
        - Total de unidades: {{total_unidades}}
        - Promociones disponibles para este cliente: {{json availablePromotions}}

        Tu tarea es generar un máximo de 2 sugerencias relevantes.
        - Prioriza las promociones que estén más cerca de cumplirse. Por ejemplo, si le faltan 1 o 2 productos para una bonificación.
        - Si ya cumplió una promoción, felicítalo y muéstrale la siguiente meta si existe.
        - El tono debe ser amigable, profesional y persuasivo, como un vendedor que quiere ayudar a su cliente.
        - Las razones deben ser claras y directas.

        Ejemplos de buenas sugerencias:
        - Name: "¡A 1 paso del 8+2!" Reason: "Estás a solo 1 producto de llevarte 2 de regalo. ¡No te lo pierdas!"
        - Name: "¡Envío Gratis Desbloqueado!" Reason: "Felicitaciones, ya alcanzaste el envío sin cargo para tu zona."
        - Name: "Duplica tu Regalo" Reason: "Ya tienes 2 productos de regalo, pero si sumas 8 más, ¡te llevas 4 en total!"

        Devuelve un array de sugerencias en el campo 'promotionSuggestions'. Si no hay sugerencias relevantes, devuelve un array vacío.
    `,
});

export const suggestPromotions = ai.defineFlow(
  {
    name: "suggestPromotionsFlow",
    inputSchema: z.any(),
    outputSchema: IntelligentPromoOutputSchema,
  },
  async (input: SuggestPromotionsInput): Promise<SuggestPromotionsOutput> => {
    const { output } = await intelligentPromoPrompt(input);
    return output ?? { promotionSuggestions: [] };
  }
);
