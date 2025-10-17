## ADDED Requirements
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
