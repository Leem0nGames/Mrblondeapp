## ADDED Requirements
### Requirement: Client Location Overview Map
The system SHALL display an interactive map on the main dashboard showing the geographical location of all active clients.

#### Scenario: View clients on map
- **GIVEN** an administrator is on the main dashboard page (`/admin`).
- **WHEN** the page loads.
- **THEN** a map SHALL be displayed.
- **AND** the map SHALL show markers (pins) for each client that has valid address coordinates.
- **AND** clicking on a marker SHALL display the name of the client.

#### Scenario: No clients with coordinates
- **GIVEN** an administrator is on the main dashboard page.
- **WHEN** there are no clients with valid address coordinates.
- **THEN** the map SHALL be displayed, centered on Argentina, without any markers.