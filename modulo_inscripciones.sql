-- ============================================================
--  LPI · Módulo Inscripciones (preinscripción en línea)
--  Supabase → SQL Editor → New query → Run
-- ============================================================
CREATE TABLE IF NOT EXISTS inscripciones (
  id          SERIAL PRIMARY KEY,
  alumno      TEXT NOT NULL,
  nivel       TEXT,
  grado       TEXT,
  tutor       TEXT,
  tel         TEXT,
  email       TEXT,
  estado      TEXT DEFAULT 'Preinscrito',
  notas       TEXT,
  fecha       DATE DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE inscripciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "acceso_total" ON inscripciones;
CREATE POLICY "acceso_total" ON inscripciones FOR ALL USING (true) WITH CHECK (true);
