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
