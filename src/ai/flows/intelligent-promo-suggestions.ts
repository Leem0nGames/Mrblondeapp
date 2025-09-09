// intelligent-promo-suggestions.ts
'use server';

/**
 * @fileOverview An AI agent that intelligently suggests the most advantageous promotions
 * or bundled offers based on a user's cart items and quantities, with an explanation
 * of why each offer is recommended.
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
  type: z.enum(['barberia', 'distribuidor']).describe('The type of the client.'),
  agreement_id: z.string().optional().describe('The ID of the agreement, if any.'),
  total_unidades: z.number().int().positive().describe('The total number of units in the cart.'),
  ciudad: z.string().optional().describe('The city of the client, if any.'),
  direccion: z.string().optional().describe('The address of the client, if any.'),
  nombre: z.string().optional().describe('The name of the client, if any.'),
});

export type SuggestPromotionsInput = z.infer<typeof SuggestPromotionsInputSchema>;

const SuggestPromotionsOutputSchema = z.object({
  promotionSuggestions: z.array(
    z.object({
      name: z.string().describe('The name of the promotion.'),
      description: z.string().describe('A detailed description of the promotion and its benefits.'),
      reason: z.string().describe('The reason why this promotion is suggested for the user.'),
    })
  ).describe('A list of promotion suggestions for the user.'),
});

export type SuggestPromotionsOutput = z.infer<typeof SuggestPromotionsOutputSchema>;

export async function suggestPromotions(input: SuggestPromotionsInput): Promise<SuggestPromotionsOutput> {
  return suggestPromotionsFlow(input);
}

const prompt = ai.definePrompt({
  name: 'suggestPromotionsPrompt',
  input: {schema: SuggestPromotionsInputSchema},
  output: {schema: SuggestPromotionsOutputSchema},
  prompt: `You are an expert in sales promotions and marketing. Based on the items in the user's cart, their client type, and any applicable agreements, suggest the most advantageous promotions or bundled offers for the user.

  Consider the following promotions:
  - Barberias: If quantity >=8, applies 8+2 (paga 8, lleva 10). If >=6, 6+1 (paga 6, lleva 7). Envío gratis si total_unidades >12 Y ciudad in ['CABA', 'Córdoba capital', 'Rosario'].
  - Distribuidores: If total_unidades >100, price_unit -=100; if <100, price_unit +=100 (or use adjustment de convenio). If >100u, 10+1 (agrega 10% extra gratis); si <100 y >=5, 5+1 similar. Convenio override.

  Provide a clear explanation of why each promotion is recommended, focusing on how it benefits the user by maximizing savings and benefits the business by maximizing revenue.

  User Cart Items:
  {{#each items}}
  - {{name}} (Quantity: {{quantity}})
  {{/each}}

  Client Type: {{type}}
  Agreement ID: {{agreement_id}}
  Total Units: {{total_unidades}}
  City: {{ciudad}}

  Output should be a JSON array of promotion suggestions, each with a name, description, and reason.
  Ensure the output adheres to the SuggestPromotionsOutputSchema.`, 
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
