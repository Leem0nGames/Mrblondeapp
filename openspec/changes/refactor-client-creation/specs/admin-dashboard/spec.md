## MODIFIED Requirements
### Requirement: Create and Manage Clients
The system SHALL allow an administrator to create, view, and manage clients directly from the admin dashboard.

#### Scenario: Admin creates a new client directly
- **GIVEN** an administrator is on the "Clients" page.
- **WHEN** they click the "Add Client" button.
- **THEN** a dialog SHALL open containing a form to enter all of the new client's details (name, CUIT, address, contact info, etc.) and optionally assign an existing agreement.
- **AND** upon submitting the form, the new client SHALL be created with an "active" or "pending_agreement" status and appear in the clients list.

#### Scenario: Admin edits an existing client
- **GIVEN** an administrator is on a client's detail page.
- **WHEN** they click the "Edit Data" button.
- **THEN** a dialog SHALL open, pre-filled with the client's current information.
- **AND** upon submitting the form, the client's data SHALL be updated in the database.

## REMOVED Requirements
### Requirement: Create Client via Invitation Link
**Reason**: This flow is overly complex for the primary user (admin) and is being replaced by a direct creation flow.
**Migration**: The functionality is superseded by the direct client creation form. The `/onboarding` route is no longer necessary.