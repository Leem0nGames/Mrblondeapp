## MODIFIED Requirements
### Requirement: Create and Manage Clients
The system SHALL allow an administrator to create, view, and manage clients directly from the admin dashboard, including their delivery preferences.

#### Scenario: Admin sets delivery time window using 24-hour format
- **GIVEN** an administrator is creating or editing a client.
- **WHEN** they access the "Ventana Horaria de Entrega" section of the form.
- **THEN** the "Desde" and "Hasta" fields SHALL be presented as dropdown selectors.
- **AND** the options within these selectors SHALL be in a 24-hour format (e.g., "09:00", "14:00", "18:00").
