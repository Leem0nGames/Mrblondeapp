## MODIFIED Requirements
### Requirement: View Products by Category
The system SHALL display products grouped by category in an accordion interface on the order page. Category titles SHOULD be displayed in a bilingual format.

#### Scenario: Bilingual category title is displayed
- **GIVEN** a product category is named "Hairstyle" in the database.
- **AND** a translation for "Hairstyle" exists in the frontend map.
- **WHEN** the order page is rendered.
- **THEN** the accordion trigger for that category SHALL display the text "Hairstyle / Cabello".

#### Scenario: Category without translation
- **GIVEN** a product category is named "New-Category" in the database.
- **AND** no translation for "New-Category" exists in the frontend map.
- **WHEN** the order page is rendered.
- **THEN** the accordion trigger for that category SHALL display the original text "New-Category" as a fallback.
