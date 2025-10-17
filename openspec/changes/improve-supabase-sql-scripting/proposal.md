## Why
The main database schema script (`schema.sql`) has been a recurring source of errors during development. These errors, caused by issues like object dependencies, incorrect syntax for the Supabase editor, and use of reserved words, slow down development and require manual intervention to fix. A more robust and well-documented approach is needed.

## What Changes
- **Fix Immediate Error**: Correct the current SQL error by using `DROP TABLE ... CASCADE` to automatically resolve dependency issues when resetting the schema.
- **Standardize Script Structure**: Refactor the entire `schema.sql` to follow a strict, logical order: Cleanup, Type Creation, Table Creation, View/Function Creation, RLS Policies, and Storage Policies.
- **Document Best Practices**: Create a new `design.md` document that serves as a definitive guide for writing SQL for this project's Supabase instance. This guide will capture the lessons learned from previous errors. It will explicitly forbid `psql`-only commands, mandate the use of `CASCADE`, clarify correct policy syntax, and warn against using SQL reserved words as aliases.

## Impact
- **Affected Specs**: None. This is a developer-experience and process-improvement change.
- **Affected Code**: `src/lib/supabase/schema.sql` will be refactored.
- **New Files**: `openspec/changes/improve-supabase-sql-scripting/design.md` will be created.
- **Positive Impact**:
  - Eliminates a class of recurring SQL errors.
  - Makes the database setup process reliable and idempotent.
  - Provides clear documentation for any developer working on the database schema, improving maintainability.
