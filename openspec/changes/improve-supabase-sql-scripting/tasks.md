## 1. Fix and Refactor SQL Schema
- [x] 1.1 In `src/lib/supabase/schema.sql`, change all `DROP TABLE IF EXISTS ...;` commands to `DROP TABLE IF EXISTS ... CASCADE;`.
- [x] 1.2 Do the same for other `DROP` commands (`DROP VIEW`, `DROP FUNCTION`, etc.) to ensure all dependencies are handled.
- [x] 1.3 Verify the entire `schema.sql` script is correctly ordered according to the new `design.md` guidelines.

## 2. Document Best Practices
- [x] 2.1 Create the `design.md` file within this change proposal.
- [x] 2.2 Document the idempotent script structure, the mandatory use of `CASCADE`, the prohibition of `psql` commands, and other learned best practices.

## 3. Final Review
- [x] 3.1 Run the updated `schema.sql` script in the Supabase SQL Editor to confirm it executes without any errors.
- [x] 3.2 Mark this task list as complete.

