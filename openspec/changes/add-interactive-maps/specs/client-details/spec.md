## ADDED Requirements
### Requirement: Display Client Location on Map
The system SHALL display an interactive map on the client detail page, centered on the client's specific address.

#### Scenario: View map for a client with coordinates
- **GIVEN** an administrator is viewing the detail page for a client with a valid, geocoded address.
- **WHEN** the page loads.
- **THEN** a map SHALL be displayed, zoomed in and centered on the client's latitude and longitude.
- **AND** a marker SHALL be visible at the client's location.

#### Scenario: Geocode address for a client without coordinates
- **GIVEN** an administrator is viewing the detail page for a client that has an address but no latitude/longitude coordinates.
- **WHEN** the page loads.
- **THEN** the system SHALL automatically attempt to geocode the client's address in the background.
- **AND** upon successful geocoding, the map SHALL appear centered on the new coordinates.
- **AND** the new coordinates SHALL be saved to the database for future use.

#### Scenario: Client with no address
- **GIVEN** an administrator is viewing the detail page for a client with no address.
- **WHEN** the page loads.
- **THEN** a placeholder or message SHALL be displayed instead of a map, indicating that no address is available.