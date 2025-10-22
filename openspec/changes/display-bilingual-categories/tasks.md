## 1. Frontend Implementation
- [ ] 1.1 **Create Translation Map**: In `src/app/pedido/[id]/page.tsx`, define a constant object `categoryTranslations` to map English category names to Spanish.
- [ ] 1.2 **Update Accordion Trigger**: Modify the JSX for the `AccordionTrigger` inside the `map` function. Instead of rendering `category` directly, use the translation map to construct the bilingual string (e.g., `${category} / ${categoryTranslations[category]}`).
- [ ] 1.3 **Add Fallback**: Ensure that if a category is not found in the map, it defaults to showing just the original category name.

## 2. Final Review
- [ ] 2.1 Verify that categories with translations appear in the "English / Spanish" format.
- [ ] 2.2 Verify that a category without a translation appears normally.
- [ ] 2.3 Mark this task list as complete.
