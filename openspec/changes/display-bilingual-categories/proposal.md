## Why
Product categories on the order page are currently displayed only in English (e.g., "Hairstyle"). To improve clarity for Spanish-speaking users, these categories should be displayed in a bilingual format (e.g., "Hairstyle / Cabello").

## What Changes
- **Translation Map**: A simple key-value mapping object will be created in the order page component to associate English category names with their Spanish translations.
- **UI Update**: The order page component (`/pedido/[id]/page.tsx`) will be modified to use this map when rendering the category titles in the accordion, displaying them in a "English / Spanish" format.

## Impact
- **Affected Specs**: `client-orders`
- **Affected Code**:
  - `src/app/pedido/[id]/page.tsx`: Will be modified to include the translation logic and update the UI.
- **Positive Impact**: Improves user experience by making product categories instantly understandable to both English and Spanish speakers.
- **Database Impact**: None. The database will continue to store categories in English.