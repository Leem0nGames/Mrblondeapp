## Context
The current process for creating promotions, price lists, and sales conditions requires administrators to manually fill out structured forms. This is effective but can be slow and repetitive. This design document outlines a new, faster method using natural language commands.

## Goals
- Allow administrators to create commercial entities (promotions, price lists, sales conditions) using free-form text commands.
- Provide a simple, intuitive interface for these commands.
- Reuse existing backend logic for data insertion to ensure consistency and security.
- The new functionality must be an addition, not a replacement for the existing forms.

## Decisions

### 1. High-Level Architecture
The flow will be as follows:
1.  **Frontend (Client Component):** A new `CommandParser.tsx` component will capture the user's text command.
2.  **AI Flow (Server-side):** The frontend component will call a new Genkit flow, `commandParserFlow`.
3.  **Interpretation:** The Genkit flow will use a Gemini model to interpret the natural language command and convert it into a structured JSON object (e.g., `{ entity: 'promotion', data: { ... } }`).
4.  **Data Mutation:** The Genkit flow will **not** directly write to the database. Instead, it will return the structured JSON to the frontend.
5.  **Server Actions:** The frontend component will then take this structured data and call the appropriate, pre-existing `upsert` server action (e.g., `upsertPromotion`, `upsertSalesCondition`).

### 2. Rationale for Architecture
- **Security & Reusability:** By reusing the existing `upsert` server actions, we inherit all their validation and security logic. The AI's role is purely to interpret and format data, not to perform critical database operations. This is a much safer pattern.
- **Modularity:** This keeps the AI logic (`commandParserFlow`) separate from the core business logic (server actions), making the system easier to maintain.
- **User Feedback:** The flow allows for clear user feedback. The frontend component can show a "Processing..." state while the AI works, and then confirm success or show an error after the `upsert` action is called.

### 3. Component and Flow Design

#### a. `src/app/admin/commercial-settings/_components/command-parser.tsx`
- A client component containing an `Input` and a `Button`.
- It will have a local state to manage the user's text input and a `isPending` state for the transition.
- On submit, it will call the `commandParserFlow` wrapper function.
- It will use a `switch` statement on the returned `entity` type to call the correct `upsert` action.
- It will use `useRouter().refresh()` to update the page's data on success.

#### b. `src/ai/flows/command-parser-flow.ts`
- A new Genkit flow file.
- **Input Schema:** `z.object({ command: z.string() })`
- **Output Schema:** A Zod schema that defines the possible structured outputs, e.g., `z.union([PromotionSchema, PriceListSchema, ...])`. It will include an `entity` field to identify the type.
- **Prompt:** A detailed prompt that instructs the model to act as a command interpreter. It will be given examples of input commands and the desired JSON output format for each entity type. This technique is called "few-shot prompting".

## Risks
- **AI Hallucination/Errors:** The AI might misinterpret a command or generate malformed JSON.
- **Mitigation:**
    - The Zod output schema in the Genkit flow provides strong validation. If the AI's output doesn't match the schema, the flow will fail gracefully and the frontend can display a "Could not understand the command" error.
    - The server actions provide a second layer of validation before writing to the database.
- **User Experience:** Users might not know what commands are possible.
- **Mitigation:** The UI will include placeholder text in the input field with examples (e.g., "crear promo 2x1 en ceras...").
