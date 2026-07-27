-- ============================================================
--  LPI · Acceso de Padres (login individual, uno por alumno)
--  Ejecuta este SQL en: Supabase → SQL Editor → New query → Run
-- ============================================================

CREATE TABLE IF NOT EXISTS padres_acceso (
  id          SERIAL PRIMARY KEY,
  alumno_id   INT NOT NULL REFERENCES alumnos(id) ON DELETE CASCADE,
  usuario     TEXT UNIQUE NOT NULL,
  pass        TEXT NOT NULL,           -- En producción usar hash
  activo      BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE padres_acceso ENABLE ROW LEVEL SECURITY;

-- Acceso total con la clave anon (el sitio web y el ERP validan login propio)
CREATE POLICY "acceso_total" ON padres_acceso FOR ALL USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_padres_acceso_alumno  ON padres_acceso(alumno_id);
CREATE INDEX IF NOT EXISTS idx_padres_acceso_usuario ON padres_acceso(usuario);

-- ============================================================
--  ¿Qué hace esta tabla?
--  Cada vez que se inscribe un alumno nuevo en el ERP, el sistema
--  genera automáticamente un usuario y contraseña aquí, ligados a
--  ese alumno_id. El padre/tutor usa ese usuario y contraseña para
--  entrar en "Acceso Padres" en el sitio web y ver SOLO la
--  información de su hijo/a: calificaciones, asistencia, horario
--  y avisos/comunicados.
--
--  Si una familia tiene 2+ hijos inscritos, cada hijo tiene su
--  propio acceso (login distinto), tal como ya funcionan los demás
--  módulos de alumnos en el ERP.
-- ============================================================
