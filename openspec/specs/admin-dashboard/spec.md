## ADDED Requirements
### Requirement: View Order Notes on Dashboard
The system SHALL allow administrators to see notes attached to pending orders on the main dashboard.

#### Scenario: Order with a note
- **GIVEN** an administrator is on the main dashboard
- **AND** there is a pending order that includes a note
- **WHEN** the list of recent orders is displayed
- **THEN** the system SHALL show a visual indicator (e.g., an icon) next to that order.

#### Scenario: Open floating note view
- **GIVEN** a pending order with a note is displayed on the dashboard
- **WHEN** the administrator clicks on the note indicator
- **THEN** the system SHALL display a floating widget on the screen containing the full text of the order note and the client's name.

#### Scenario: Close floating note view
- **GIVEN** the floating note widget is open
- **WHEN** the administrator clicks a "close" button on the widget
- **THEN** the widget SHALL disappear from the screen.

#### Scenario: Minimize floating note view
- **GIVEN** the floating note widget is open
- **WHEN** the administrator clicks a "minimize" button on the widget
- **THEN** the widget SHALL shrink to a smaller, less obtrusive state, still visible on the screen.
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

### Requirement: Search for Clients
The system SHALL allow an administrator to search for clients to filter the client list.

#### Scenario: Search by client name
- **GIVEN** an administrator is on the "Clients" page.
- **WHEN** they type a client's name (e.g., "John Doe") into the search bar.
- **THEN** the client list SHALL be filtered to show only clients whose name contains "John Doe".

#### Scenario: Search by CUIT
- **GIVEN** an administrator is on the "Clients" page.
- **WHEN** they type a client's CUIT into the search bar.
- **THEN** the client list SHALL be filtered to show the client matching that CUIT.

#### Scenario: Search with no results
- **GIVEN** an administrator is on the "Clients" page.
- **WHEN** they type a search term that does not match any client.
- **THEN** the system SHALL display a message indicating that no clients were found for that search term.
