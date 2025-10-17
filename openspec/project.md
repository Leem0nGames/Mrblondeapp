# Project Context: Blonde Orders

## Purpose
"Blonde Orders" is a streamlined B2B order management system for beauty product suppliers. Its primary goal is to provide a simple, modern, and personalized ordering experience for clients (salons, distributors) while offering a comprehensive dashboard for administrators to manage products, clients, pricing, and promotions.

## Tech Stack
- **Framework**: Next.js (App Router)
- **Language**: TypeScript
- **Backend & Database**: Supabase (PostgreSQL, Auth, Storage)
- **UI Framework**: Tailwind CSS with shadcn/ui
- **Client-side State**: Zustand (for the shopping cart)
- **Form Management**: React Hook Form with Zod for validation
- **AI/Generative Features**: Genkit with Google AI (Gemini models)

## Project Conventions

### Code Style
- Adherence to modern React best practices: Functional Components and Hooks.
- TypeScript is used for all new code, with a preference for strict type safety.
- File and component naming follows PascalCase (`MyComponent.tsx`).
- Server Actions are named descriptively (e.g., `upsertProduct`, `getAgreements`) and co-located in `src/app/actions/`.
- Code is formatted using Prettier defaults.

### Architecture Patterns
- **Next.js App Router**: The application uses the App Router for routing, layouts, and server-side rendering. Server Components are the default.
- **Server Actions**: All backend logic (database mutations, queries) is handled through Server Actions. There are no traditional API endpoints.
- **Supabase Integration**: A series of helper clients (`client.ts`, `server.ts`, `admin.ts`, `middleware.ts`) are used to interact with Supabase securely from different contexts.
- **Component-Based UI**: The UI is built with reusable components from `shadcn/ui` and custom components located in `src/components/`.
- **Centralized State for Cart**: The shopping cart state is managed globally on the client-side using Zustand to provide a responsive user experience.
- **AI Flows**: All generative AI logic is encapsulated within Genkit flows in the `src/ai/flows/` directory.

### Testing Strategy
- Currently, no formal testing strategy is implemented in the codebase.
- **Ideal future strategy**:
  - **Unit/Integration Tests**: Use Jest or Vitest to test individual components, Server Actions, and utility functions.
  - **End-to-End (E2E) Tests**: Use Playwright or Cypress to test critical user flows, such as admin login, creating a product, and a client placing an order.

### Git Workflow
- A standard feature-branch workflow is assumed.
- 1. Create a new branch from `main` for each new feature or bugfix (e.g., `feature/add-client-search` or `fix/login-error`).
- 2. Commit changes with clear, descriptive messages.
- 3. Push the branch and open a Pull Request against `main`.
- 4. Once reviewed and approved, merge the PR into `main`.

## Domain Context
The core of the application revolves around the concept of a **Convenio (Agreement)**.

- **Clients**: The end-users of the ordering portal (e.g., beauty salons, distributors). They don't have login credentials; they access the system via a unique link.
- **Agreements (Convenios)**: The central entity. An agreement connects a **Client Type** to a specific **Price List**, a set of **Promotions**, and a set of **Sales Conditions**. Admins generate a unique ordering link (`/pedido/[agreement_id]`) for each agreement.
- **Price Lists**: Reusable collections of products with specific prices. A single price list can be attached to multiple agreements.
- **Promotions**: Special deals, like "Buy X, Get Y Free" or "Free Shipping", that are assigned to an agreement.
- **Sales Conditions**: Commercial terms, such as payment deadlines (`Net 30 days`) or financing options, also assigned to an agreement.
- **Order Flow**: The client receives the unique link, adds products to their cart, and submits the order. This action saves the order in the database and generates a pre-formatted WhatsApp message for the client to send to the company's contact number.

## Important Constraints
- **Admin Authentication**: The admin login relies on a standard email/password, not a dynamic PIN. The initial "super admin" is created on the first run of the application.
- **Client Access**: Clients do not log in. Their access is entirely dependent on the unique, shareable `/pedido/[id]` link provided by the administrator.
- **Database Schema**: The application is tightly coupled to the Supabase database schema defined in `src/lib/supabase/schema.sql`. Changes to the schema must be reflected in the Server Actions and TypeScript types.

## External Dependencies
- **Supabase**: The project is entirely dependent on a Supabase project for its database, authentication, and file storage (`product_images`).
- **WhatsApp**: The final step of the order submission relies on redirecting the user to `wa.me` with a pre-formatted message. It does not use the WhatsApp Business API.
