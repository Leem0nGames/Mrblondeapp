## Why
To improve the application's perceived and measured performance, providing a faster and smoother user experience. This will lead to higher user satisfaction and a more professional feel.

## What Changes
- **Image Optimization**: Centralize all placeholder image logic into a `placeholder-images.json` file for better management and performance.
- **Font Optimization**: Align Tailwind CSS font handling with Next.js's optimized font loading (`next/font`).
- **Code Splitting**: Dynamically load large, route-specific components (like the client detail view) to reduce the initial JavaScript bundle size for the admin section.

## Impact
- **Affected Specs**: `admin-dashboard` (indirectly via performance improvements), `client-orders` (no functional change). This change is primarily performance-focused.
- **Affected Code**:
  - `src/lib/placeholder-images.ts` will be replaced.
  - `src/lib/placeholder-images.json` will be created.
  - `tailwind.config.ts` will be updated.
  - `src/app/admin/clients/[id]/page.tsx` will be modified to use `next/dynamic`.
  - All components that render product images will be updated to use the new `getImageUrl` function.
