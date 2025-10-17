## Context
The project relies on a single `schema.sql` file to set up and reset the Supabase database. This script needs to be idempotent, meaning it can be run multiple times without causing errors. We have encountered several syntax and dependency errors while iterating on this script, which slows down development and creates frustration.

## Goal
To establish a clear, robust, and error-resistant structure and set of best practices for writing and maintaining SQL scripts for the Supabase SQL Editor in this project.

## Decisions and Best Practices

### 1. Script Structure: The Idempotent "Cleanup-First" Pattern
The `schema.sql` script MUST follow a strict order of operations to ensure it can be run safely on a fresh or existing database.

```sql
-- 1. Cleanup and Reset
-- Drop existing objects in reverse order of creation.
-- ALWAYS use DROP ... CASCADE to handle dependencies automatically.

DROP FUNCTION IF EXISTS public.my_function(int) CASCADE;
DROP VIEW IF EXISTS public.my_view CASCADE;
DROP TABLE IF EXISTS public.my_table CASCADE;
DROP TYPE IF EXISTS public.my_enum CASCADE;
DROP POLICY IF EXISTS "My Policy" ON storage.objects;
-- ... and so on for all objects ...

-- 2. Create Types (Enums)
-- Enums should be created before tables that use them.
CREATE TYPE public.my_enum AS ENUM ('a', 'b', 'c');

-- 3. Create Tables
-- Define all tables with their columns, constraints, and foreign keys.
CREATE TABLE public.my_table (
    id uuid PRIMARY KEY,
    status my_enum NOT NULL
    -- ...
);

-- 4. Create Views and Functions
-- Views and functions depend on tables, so they are created after.
CREATE OR REPLACE VIEW public.my_view AS SELECT ...;
CREATE OR REPLACE FUNCTION public.my_function(int) RETURNS int AS $$ ... $$;

-- 5. Enable Row-Level Security (RLS)
-- Enable RLS on all tables that require it.
ALTER TABLE public.my_table ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS Policies
-- Define access policies for each table.
CREATE POLICY "Allow all for admins" ON public.my_table FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- 7. Storage Policies
-- Define policies for file storage buckets.
CREATE POLICY "Allow read on avatars" ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- 8. (Optional) Initial Data Seeding
-- Only for essential, non-example data. Use seed.sql for test data.
INSERT INTO public.app_meta (key, value) VALUES ('version', '"1.0.0"')
ON CONFLICT(key) DO NOTHING;
```

### 2. Key Rule: `DROP ... CASCADE` is Mandatory
- **Problem:** `DROP TABLE my_table;` will fail if a view, function, or foreign key from another table depends on it.
- **Solution:** **ALWAYS** use `DROP TABLE IF EXISTS my_table CASCADE;`. The `CASCADE` option automatically removes any dependent objects, making the cleanup process robust and avoiding dependency errors. The same applies to `DROP VIEW`, `DROP FUNCTION`, etc.

### 3. Key Rule: Avoid `psql`-Specific Commands
- **Problem:** Commands like `\set ON_ERROR_STOP on` are specific to the `psql` command-line tool. They are **not** valid SQL and will cause a syntax error in the Supabase SQL Editor.
- **Solution:** Do not include any commands that start with a backslash (`\`). The Supabase editor handles transactions automatically, so these commands are unnecessary.

### 4. Key Rule: Correct `CREATE POLICY` Syntax
- **Problem:** The syntax for creating RLS policies is strict. The `ON table_name` clause must come before the `FOR command` clause.
- **Incorrect:** `CREATE POLICY "My Policy" FOR SELECT ON public.my_table ...`
- **Correct:** `CREATE POLICY "My Policy" ON public.my_table FOR SELECT ...`

### 5. Key Rule: Do Not Use SQL Reserved Words as Aliases
- **Problem:** Using a reserved SQL keyword like `ASC`, `ORDER`, or `GROUP` as a table or column alias will cause a syntax error.
- **Incorrect:** `... FROM public.my_table asc WHERE asc.id = ...`
- **Solution:** Use descriptive, non-reserved aliases. A good practice is to use a short, unique abbreviation.
- **Correct:** `... FROM public.agreements agr WHERE agr.id = ...`

## Risks and Mitigation
- **Risk:** `CASCADE` could unintentionally drop an object if dependencies are not fully understood.
- **Mitigation:** Since our `schema.sql` is designed to be a complete, self-contained definition of the database, this risk is minimal. We *want* to drop all dependent objects because we are about to recreate them correctly in the subsequent steps of the same script. This is the core of the idempotent pattern.
