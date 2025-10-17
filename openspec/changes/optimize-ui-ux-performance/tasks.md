## 1. Image Optimization
- [ ] 1.1 Create the new `src/lib/placeholder-images.json` file with a centralized structure for image seeds.
- [ ] 1.2 Replace the logic in `src/lib/placeholder-images.ts` to read from the new JSON file.
- [ ] 1.3 Update all components that use `getImageUrl` to ensure they are compatible with the new structure (e.g., `product-card.tsx`, `products-table.tsx`, etc.).

## 2. Font Optimization
- [ ] 2.1 Modify `tailwind.config.ts` to define the `fontFamily` using the CSS variables provided by `next/font` in `layout.tsx`.

## 3. Code Splitting
- [ ] 3.1 In `src/app/admin/clients/[id]/page.tsx`, import the `ClientDetailsClient` component using `next/dynamic`.
- [ ] 3.2 Provide a `Skeleton` component as the loading fallback for the dynamic import to prevent layout shifts and provide a better UX.

## 4. Final Review
- [ ] 4.1 Verify that all images, fonts, and dynamic components load correctly in the application.
- [ ] 4.2 Mark this task list as complete.
