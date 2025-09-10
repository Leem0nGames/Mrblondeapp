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
  type: z.enum(['barberia', 'distribuidor', 'especial']).describe('The type of the client.'),
  agreement_id: z.string().optional().describe('The ID of the agreement, if any.'),
  total_unidades: z.number().int().nonnegative().describe('The total number of units in the cart.'),
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
  // If there are no items, no need to call the AI.
  if (input.total_unidades === 0) {
    return { promotionSuggestions: [] };
  }
  return suggestPromotionsFlow(input);
}

const prompt = ai.definePrompt({
  name: 'suggestPromotionsPrompt',
  input: {schema: SuggestPromotionsInputSchema},
  output: {schema: SuggestPromotionsOutputSchema},
  prompt: `You are an expert in sales promotions for a beauty products company. Your goal is to analyze a client's shopping cart and suggest the most advantageous promotions. Be precise and proactive.

  Here are the configurable rules based on client type:

  **RULESET 1: For 'barberia' client type:**
  - Promotion "Comprá 6, llevá 7": If the cart has 6 or 7 units of a single product, suggest adding units to reach exactly 6 and pay for 6, getting 1 free. They effectively pay for 6 and get 7.
  - Promotion "Comprá 8, llevá 10": If the cart has 8, 9 or 10 units of a single product, suggest adding units to reach 8 and pay for 8, getting 2 free. This is a better deal than 6+1.
  - Free Shipping: If 'total_unidades' is greater than 12 AND the 'ciudad' is one of ['CABA', 'Córdoba capital', 'Rosario'], suggest "Envío Gratis".
  - Always prioritize the best deal. If a user has 7 items, they are close to the 8+2 promo, so you should mention it as a potential upgrade.

  **RULESET 2: For 'distribuidor' client type:**
  - Promotion "Promo 5+1": If 'total_unidades' is between 5 and 99, they get a "5+1" deal (for every 5 units, they get 1 free, applied proportionally).
  - Promotion "Promo 10+1": If 'total_unidades' is 100 or more, they get a "10+1" deal (for every 10 units, they get 1 free, applied proportionally). This also comes with a special unit price reduction of $100 per unit.
  - An 'agreement' with 'price_adjustment' can override these base prices.
  
  **RULESET 3: For 'especial' client type:**
  - These are special cases. Analyze the cart and offer a custom, appealing suggestion based on the products. For example, if they have multiple units of one product, suggest a bulk discount. If they have different products, suggest a bundle. Be creative.

  **ANALYSIS CONTEXT:**
  - Client Name: {{nombre}}
  - Client Type: {{type}}
  - Total Units in Cart: {{total_unidades}}
  - Client City: {{ciudad}}
  - Cart Items:
  {{#each items}}
  - {{name}} (Quantity: {{quantity}})
  {{/each}}

  **YOUR TASK:**
  Based on the rules for the given client type and their cart, generate a list of promotion suggestions.
  - For each suggestion, provide a 'name', a 'description' of how it works, and a clear 'reason' explaining why it's a good deal for them.
  - If the cart is empty or no promotions apply, return an empty array.
  - Ensure the output strictly adheres to the 'SuggestPromotionsOutputSchema' JSON format.
  - If multiple promotions apply, list them all.
  - Your suggestions should be encouraging and guide the user to optimize their order. For example: "Estás a solo 1 unidad de conseguir 2 productos gratis con la promo 8+2!".`, 
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
