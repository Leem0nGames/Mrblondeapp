## ADDED Requirements
### Requirement: Create Commercial Entities via Natural Language
The system SHALL provide an input field for administrators to create promotions, price lists, and sales conditions by typing commands in natural language.

#### Scenario: Successfully create a promotion
- **GIVEN** an administrator is on the "Commercial Management" page.
- **WHEN** they type "Crear promoción 2x1 en todos los productos" into the command bar and submit.
- **THEN** the system SHALL interpret the command, create a new promotion record in the database with the corresponding rules.
- **AND** a success message SHALL be displayed.
- **AND** the list of promotions on the page SHALL be updated to show the new promotion.

#### Scenario: Command is ambiguous or invalid
- **GIVEN** an administrator is on the "Commercial Management" page.
- **WHEN** they type a command that the system cannot understand (e.g., "hacer algo copado").
- **THEN** the system SHALL NOT create any new records.
- **AND** an error message SHALL be displayed, indicating that the command could not be interpreted.
