## 1. AI Backend (Genkit Flow)
- [x] 1.1 Create the new file `src/ai/flows/command-parser-flow.ts`.
- [x] 1.2 Define Zod schemas for the input (a command string) and the possible structured outputs (one for each entity: promotion, price list, sales condition). The output schema must be a union type.
- [x] 1.3 Write the `ai.definePrompt` with instructions for the model to parse commands and generate JSON. Include a few examples in the prompt ("few-shot").
- [x] 1.4 Implement the `ai.defineFlow` that takes the command, calls the prompt, and returns the validated, structured data.
- [x] 1.5 Create and export an async wrapper function for the flow so the frontend can call it.

## 2. Frontend Implementation
- [x] 2.1 Create a new reusable client component `src/app/admin/commercial-settings/_components/command-parser.tsx`.
- [x] 2.2 This component will contain an `Input` for the text command and a `Button` to submit. It will use a local state for the input value and a `useTransition` hook for the pending state.
- [x] 2.3 Implement the `onSubmit` handler. This function will call the Genkit flow wrapper from step 1.5.
- [x] 2.4 On a successful response, use a `switch` statement on the `entity` type from the AI's response to call the correct, existing `upsert` server action (e.g., `upsertPromotion`, `upsertPriceList`).
- [x] 2.5 Use the `toast` hook to show success or error messages.
- [x] 2.6 On success, call `router.refresh()` to reload the data on the page.

## 3. Integration
- [x] 3.1 Modify `src/app/admin/commercial-settings/page.tsx` to include the new `CommandParser` component, likely within the `PageHeader`.

## 4. Final Review
- [x] 4.1 Test creating a promotion (e.g., "crear promo 10+2 en Ceras The Shaving Co").
- [x] 4.2 Test creating a sales condition (e.g., "nueva condicion de pago a 60 dias").
- [x] 4.3 Test an invalid or ambiguous command to ensure it shows a user-friendly error.
- [x] 4.4 Mark this task list as complete.
