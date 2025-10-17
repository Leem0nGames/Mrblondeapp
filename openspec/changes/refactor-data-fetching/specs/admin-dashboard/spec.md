## MODIFIED Requirements
### Requirement: Efficient Data Loading
The system SHALL employ efficient data loading strategies to minimize database load and improve page rendering times. This includes consolidating multiple related queries into a single database call where possible.

#### Scenario: Loading notifications
- **GIVEN** an administrator navigates to any page within the `/admin` section.
- **WHEN** the main admin layout is rendered.
- **THEN** the system SHALL fetch all data required for notifications (pending orders, pending clients, overdue orders) in a single, consolidated server action.

#### Scenario: Loading the main dashboard
- **GIVEN** an administrator navigates to the main dashboard page (`/admin`).
- **WHEN** the page is rendered.
- **THEN** the system SHALL fetch all primary dashboard data (statistics, recent orders, pending clients) in a single, consolidated server action.

### Requirement: Code Reusability
The system SHALL avoid code duplication by using shared, reusable components for similar functionality.

#### Scenario: Creating and editing a client
- **GIVEN** a developer needs to modify the client data form.
- **WHEN** they inspect the codebase.
- **THEN** they SHALL find a single, unified form component (`upsert-client-form.tsx`) that is used for both creating a new client and editing an existing one, rather than two separate implementations.
