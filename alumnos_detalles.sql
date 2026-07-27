-- ============================================================
--  LPI · Alumnos — ficha completa de inscripción
--  Supabase → SQL Editor → New query → Run
-- ============================================================
ALTER TABLE alumnos ADD COLUMN IF NOT EXISTS edad           TEXT;
ALTER TABLE alumnos ADD COLUMN IF NOT EXISTS anio_cursante  TEXT;
ALTER TABLE alumnos ADD COLUMN IF NOT EXISTS fecha_ingreso  DATE;
ALTER TABLE alumnos ADD COLUMN IF NOT EXISTS tutores        JSONB DEFAULT '[]'::jsonb;  -- [{nombre,telefono,whatsapp}]
ALTER TABLE alumnos ADD COLUMN IF NOT EXISTS historial      JSONB DEFAULT '{}'::jsonb;  -- datos clínicos
ALTER TABLE alumnos ADD COLUMN IF NOT EXISTS documentos     JSONB DEFAULT '[]'::jsonb;  -- [{nombre,tipo,archivo(base64)}]
