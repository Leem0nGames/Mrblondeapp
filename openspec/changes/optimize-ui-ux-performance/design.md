## Context
The application currently has good performance but can be further optimized by adhering to modern web performance best practices. Key areas for improvement include image loading, font handling, and client-side JavaScript bundle size.

## Goals
- Improve the Largest Contentful Paint (LCP) metric by optimizing image and font loading.
- Reduce the initial JavaScript payload for the admin section by code-splitting large, page-specific components.
- Centralize and streamline the management of placeholder assets.

## Decisions

### 1. Centralize Placeholder Images
- **Decision:** We will create and use a single `src/lib/placeholder-images.json` file to define all placeholder images used in the application.
- **Rationale:** This centralizes image definitions, making them easier to manage, update, and eventually replace with real assets. It decouples the image logic from the components.
- **Implementation:**
  - A new `getImageUrl` function will read from this JSON file.
  - All components using placeholder images (`ProductCard`, `ProductsTable`, etc.) will be updated to use this new function.

### 2. Optimize Font Loading with Tailwind CSS
- **Decision:** We will update `tailwind.config.ts` to use the CSS variables (`--font-body`, `--font-headline`) defined by `next/font` in the root layout.
- **Rationale:** This ensures that Tailwind's utility classes and Next.js's optimized font loading mechanism are perfectly synchronized. It's the most efficient way to use custom fonts with this stack and prevents layout shifts or flashes of unstyled text.

### 3. Code-Split Heavy Client Components
- **Decision:** The `ClientDetailsClient` component, which is a large component used only on the `admin/clients/[id]` page, will be loaded asynchronously using `next/dynamic`.
- **Rationale:** This component and its dependencies are not needed on any other page in the admin dashboard. By code-splitting it, we remove it from the main client-side bundle for the `/admin` section, making other pages like the main dashboard, products list, etc., load faster.
- **Implementation:**
  - In `src/app/admin/clients/[id]/page.tsx`, we will replace the static import of `ClientDetailsClient` with a dynamic one.
  - A simple `Skeleton` component will be shown as a loading fallback.

## Risks
- **Image URLs:** The new JSON-based image system assumes a consistent URL structure. Any deviation will require updates to the `getImageUrl` utility. This risk is low as we control the structure.
- **Dynamic Load Times:** On very slow connections, users might see the skeleton loader for a moment before the client details appear. This is an acceptable trade-off for the overall performance gain on all other pages.

## Open Questions
- None at this time. The plan is straightforward and uses standard Next.js and web development patterns.
