-- ============================================================
--  LPI · Alumnos — foto y folio/matrícula por nivel
--  Supabase → SQL Editor → New query → Run
-- ============================================================
ALTER TABLE alumnos ADD COLUMN IF NOT EXISTS foto      TEXT;  -- imagen en base64
ALTER TABLE alumnos ADD COLUMN IF NOT EXISTS matricula TEXT;  -- ej: PRI-26-001
