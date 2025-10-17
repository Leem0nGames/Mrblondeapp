## ADDED Requirements
### Requirement: Add Note to Order
The system SHALL allow a client to add a text note to their order before submitting it.

#### Scenario: Client adds a note
- **GIVEN** a client is reviewing their order in the order summary sheet
- **WHEN** they type a message into the "Notes" text area
- **AND** they click "Submit Order"
- **THEN** the system SHALL save the note along with the order details in the database.

#### Scenario: Client submits order without a note
- **GIVEN** a client is reviewing their order
- **WHEN** they do not enter any text in the "Notes" text area
- **AND** they click "Submit Order"
- **THEN** the system SHALL save the order without a note (the notes field should be null or empty).
