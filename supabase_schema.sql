-- ============================================================
--  LPI · ERP — Esquema de base de datos para Supabase
--  Learning Project Institute
--  Generado: 2026-06-14
-- ============================================================
-- Ejecuta este SQL completo en:
--   Supabase → SQL Editor → New query → Paste → Run
-- ============================================================

-- ── EXTENSIONES ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── USUARIOS DEL SISTEMA ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuarios_sistema (
  id          SERIAL PRIMARY KEY,
  usuario     TEXT UNIQUE NOT NULL,
  pass        TEXT NOT NULL,           -- En producción usar hash
  nombre      TEXT NOT NULL,
  rol         TEXT NOT NULL DEFAULT 'Maestro'
              CHECK (rol IN ('Dueño / Director General','Director','Coordinador','Supervisor','Maestro')),
  last_acceso TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Usuario admin por defecto
INSERT INTO usuarios_sistema (usuario, pass, nombre, rol)
VALUES ('admin', '1234', 'Administrador', 'Dueño / Director General')
ON CONFLICT (usuario) DO NOTHING;

-- ── ALUMNOS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS alumnos (
  id          SERIAL PRIMARY KEY,
  nombre      TEXT NOT NULL,
  nivel       TEXT NOT NULL
              CHECK (nivel IN ('Maternal','Preescolar','Primaria','Secundaria','Bachillerato')),
  grado       TEXT,
  tutor       TEXT,
  tel         TEXT,
  email       TEXT,
  nacimiento  DATE,
  curp        TEXT,
  pago        TEXT DEFAULT 'Pendiente'
              CHECK (pago IN ('Pagado','Pendiente','Vencido')),
  asist       TEXT DEFAULT '100%',
  notas       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── MAESTROS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS maestros (
  id          SERIAL PRIMARY KEY,
  nombre      TEXT NOT NULL,
  materia     TEXT,
  nivel       TEXT,
  tel         TEXT,
  email       TEXT,
  estado      TEXT DEFAULT 'Activo'
              CHECK (estado IN ('Activo','Inactivo')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── PAGOS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pagos (
  id          SERIAL PRIMARY KEY,
  alumno_id   INT REFERENCES alumnos(id) ON DELETE SET NULL,
  alumno      TEXT NOT NULL,
  concepto    TEXT NOT NULL,
  monto       NUMERIC(10,2) NOT NULL,
  estado      TEXT DEFAULT 'Pendiente'
              CHECK (estado IN ('Pagado','Pendiente','Vencido')),
  fecha       DATE DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── FACTURAS (CFDI 4.0) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS facturas (
  id          TEXT PRIMARY KEY,           -- LPI-00001
  alumno      TEXT NOT NULL,
  tutor       TEXT,
  rfc         TEXT,
  razon       TEXT,
  cp          TEXT,
  regimen     TEXT,
  uso_cfdi    TEXT DEFAULT 'D10',
  correo      TEXT,
  concepto    TEXT,
  monto       NUMERIC(10,2),
  folio_sat   TEXT,                        -- UUID del SAT
  estado      TEXT DEFAULT 'Pendiente'
              CHECK (estado IN ('Timbrada','Pendiente','Cancelada')),
  fecha       DATE DEFAULT CURRENT_DATE,
  xml_cfdi    TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── COMUNICADOS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comunicados (
  id          SERIAL PRIMARY KEY,
  titulo      TEXT NOT NULL,
  dest        TEXT DEFAULT 'Todos los padres',
  preview     TEXT,
  enviado     BOOLEAN DEFAULT FALSE,
  fecha       DATE DEFAULT CURRENT_DATE,
  fecha_envio TIMESTAMPTZ,
  canal_envio TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── CALIFICACIONES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS calificaciones (
  id          SERIAL PRIMARY KEY,
  alumno_id   INT NOT NULL REFERENCES alumnos(id) ON DELETE CASCADE,
  grupo       TEXT NOT NULL,
  periodo     TEXT NOT NULL,
  materia     TEXT NOT NULL,
  calificacion NUMERIC(4,1) CHECK (calificacion >= 0 AND calificacion <= 10),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (alumno_id, grupo, periodo, materia)
);

-- ── ASISTENCIA ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS asistencia (
  id          SERIAL PRIMARY KEY,
  alumno_id   INT NOT NULL REFERENCES alumnos(id) ON DELETE CASCADE,
  grupo       TEXT NOT NULL,
  fecha       DATE NOT NULL,
  estado      TEXT DEFAULT 'A'
              CHECK (estado IN ('A','F','T')),  -- A=Asistió F=Faltó T=Tarde
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (alumno_id, fecha)
);

-- ── HORARIOS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS horarios (
  id          SERIAL PRIMARY KEY,
  grupo       TEXT NOT NULL,
  dia         TEXT NOT NULL
              CHECK (dia IN ('Lunes','Martes','Miércoles','Jueves','Viernes')),
  franja      INT NOT NULL CHECK (franja BETWEEN 0 AND 5),
  materia     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (grupo, dia, franja)
);

-- ── CONFIGURACIÓN ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS configuracion (
  clave       TEXT PRIMARY KEY,
  valor       TEXT,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Valores por defecto
INSERT INTO configuracion (clave, valor) VALUES
  ('nombre_instituto',  'Learning Project Institute'),
  ('cct',               '15PES0042H'),
  ('ciclo_escolar',     '2024-2025'),
  ('direccion',         'Adolfo López Mateos 438, Metepec, Edo. Méx.'),
  ('telefono',          '52-1-722 648 9373'),
  ('email',             'informes@learningproject.mx'),
  ('sitio_web',         'https://www.learningprojectinstitute.com'),
  ('rfc_emisor',        'LPI250101XXX'),
  ('razon_social',      'LEARNING PROJECT INSTITUTE S.C.'),
  ('regimen_fiscal',    '601'),
  ('cp_expedicion',     '52140'),
  ('dia_vencimiento',   '10'),
  ('dias_gracia',       '5')
ON CONFLICT (clave) DO NOTHING;

-- ── ROW LEVEL SECURITY (RLS) ─────────────────────────────────
-- Habilitamos RLS en todas las tablas
ALTER TABLE usuarios_sistema  ENABLE ROW LEVEL SECURITY;
ALTER TABLE alumnos           ENABLE ROW LEVEL SECURITY;
ALTER TABLE maestros          ENABLE ROW LEVEL SECURITY;
ALTER TABLE pagos             ENABLE ROW LEVEL SECURITY;
ALTER TABLE facturas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE comunicados       ENABLE ROW LEVEL SECURITY;
ALTER TABLE calificaciones    ENABLE ROW LEVEL SECURITY;
ALTER TABLE asistencia        ENABLE ROW LEVEL SECURITY;
ALTER TABLE horarios          ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracion     ENABLE ROW LEVEL SECURITY;

-- Política: acceso total con la clave anon (el ERP valida login propio)
-- En producción reemplazar por políticas basadas en Supabase Auth
CREATE POLICY "acceso_total" ON usuarios_sistema  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON alumnos           FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON maestros          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON pagos             FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON facturas          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON comunicados       FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON calificaciones    FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON asistencia        FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON horarios          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON configuracion     FOR ALL USING (true) WITH CHECK (true);

-- ── ÍNDICES ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_pagos_alumno_id    ON pagos(alumno_id);
CREATE INDEX IF NOT EXISTS idx_pagos_estado       ON pagos(estado);
CREATE INDEX IF NOT EXISTS idx_calif_alumno       ON calificaciones(alumno_id);
CREATE INDEX IF NOT EXISTS idx_asist_alumno       ON asistencia(alumno_id);
CREATE INDEX IF NOT EXISTS idx_asist_fecha        ON asistencia(fecha);
CREATE INDEX IF NOT EXISTS idx_horarios_grupo     ON horarios(grupo);

-- ============================================================
--  FIN DEL ESQUEMA
--  Tablas creadas: 10
--  usuarios_sistema · alumnos · maestros · pagos · facturas
--  comunicados · calificaciones · asistencia · horarios · configuracion
-- ============================================================
