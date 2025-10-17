## MODIFIED Requirements
### Requirement: View Client Details
The system SHALL display a client's detailed information, historical orders, and key stats. The initial page load SHOULD be fast, with non-critical information or heavy components loading asynchronously.

#### Scenario: Navigate to client detail page
- **GIVEN** an administrator is on the clients list page
- **WHEN** they click on a client to view their details
- **THEN** the system SHALL navigate to the client detail page
- **AND** a loading state (e.g., skeleton UI) SHALL be displayed momentarily while the main client component is loaded.
- **AND** the full client details SHALL be rendered shortly after.
