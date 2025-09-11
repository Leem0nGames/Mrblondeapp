'use server';
/**
 * @fileOverview An AI agent that intelligently suggests the most advantageous promotions
 * or bundled offers based on a user's cart items, quantities, and a list of available promotions
 * for their specific agreement.
 *
 * - suggestPromotions - A function that handles the promotion suggestion process.
 * - SuggestPromotionsInput - The input type for the suggestPromotions function.
 * - SuggestPromotionsOutput - The return type for the suggestPromotions function.
 */

import {ai} from '@/ai/genkit';
import {z} from 'genkit';

const SuggestPromotionsInputSchema = z.object({
  items: z.array(
    z.object({
      id: z.string().describe('The ID of the product.'),
      quantity: z.number().int().positive().describe('The quantity of the product in the cart.'),
      name: z.string().describe('The name of the product.'),
    })
  ).describe('The items in the user cart.'),
  total_unidades: z.number().int().nonnegative().describe('The total number of units in the cart.'),
  nombre: z.string().optional().describe('The name of the client, if any.'),
  availablePromotions: z.array(
    z.object({
      name: z.string().describe('The name of the promotion.'),
      description: z.string().describe('A brief description of how the promotion works.'),
      rules: z.any().describe('A JSON object defining the rules of the promotion.')
    })
  ).describe('A list of promotions available under the current agreement.')
});

export type SuggestPromotionsInput = z.infer<typeof SuggestPromotionsInputSchema>;

const SuggestPromotionsOutputSchema = z.object({
  promotionSuggestions: z.array(
    z.object({
      name: z.string().describe('The name of the promotion.'),
      description: z.string().describe('A detailed description of the promotion and its benefits for the client.'),
      reason: z.string().describe('The reason why this promotion is suggested for the user, potentially suggesting to add more items to qualify.'),
    })
  ).describe('A list of promotion suggestions for the user.'),
});

export type SuggestPromotionsOutput = z.infer<typeof SuggestPromotionsOutputSchema>;

export async function suggestPromotions(input: SuggestPromotionsInput): Promise<SuggestPromotionsOutput> {
  // If there are no items or no promotions, no need to call the AI.
  if (input.total_unidades === 0 || input.availablePromotions.length === 0) {
    return { promotionSuggestions: [] };
  }
  return suggestPromotionsFlow(input);
}

const prompt = ai.definePrompt({
  name: 'suggestPromotionsPrompt',
  input: {schema: SuggestPromotionsInputSchema},
  output: {schema: SuggestPromotionsOutputSchema},
  prompt: `You are an expert sales advisor for a beauty products company. Your goal is to analyze a client's shopping cart and suggest the most advantageous promotions available to them under their specific agreement. Be precise, proactive, and encouraging.

  **ANALYSIS CONTEXT:**
  - Client Name: {{nombre}}
  - Total Units in Cart: {{total_unidades}}
  - Cart Items:
  {{#each items}}
  - {{name}} (Quantity: {{quantity}})
  {{/each}}

  **AVAILABLE PROMOTIONS FOR THIS CLIENT:**
  Here are the promotions this client is eligible for. Analyze them against the cart items.
  {{#each availablePromotions}}
  - **Promotion Name:** {{name}}
    - **Description:** {{description}}
    - **Rules (JSON):** {{{json stringify=rules}}}
  {{/each}}

  **YOUR TASK:**
  Based on the client's cart and the list of available promotions, generate a list of promotion suggestions.
  - For each suggestion, provide a 'name', a detailed 'description' of how it works and its benefits, and a clear 'reason' explaining why it's a good deal for them.
  - **BE PROACTIVE AND SPECIFIC:** If the client is close to qualifying for a better promotion (like "buy_x_get_y_free" or "free_shipping"), your 'reason' must explicitly tell them what to do. For example: "Estás a solo 1 unidad de conseguir 2 productos gratis con la promo 8+2!" or "¡Agrega solo 2 unidades más y tu envío a CABA será gratis!".
  - If a promotion's conditions are already met, highlight it as an active benefit they are already enjoying. For example: "¡Excelente! Ya calificaste para la promo 8+2 y te llevas 2 productos gratis."
  - If no promotions from the list are applicable or beneficial given the cart, return an empty array for 'promotionSuggestions'.
  - Ensure the output strictly adheres to the 'SuggestPromotionsOutputSchema' JSON format. Do not add any extra text or explanations.
  - Your suggestions should be encouraging and guide the user to optimize their order. Focus on the most impactful promotions first.`, 
});

const suggestPromotionsFlow = ai.defineFlow(
  {
    name: 'suggestPromotionsFlow',
    inputSchema: SuggestPromotionsInputSchema,
    outputSchema: SuggestPromotionsOutputSchema,
  },
  async input => {
    const {output} = await prompt(input);
    return output!;
  }
);
