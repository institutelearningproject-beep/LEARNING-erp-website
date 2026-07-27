-- ============================================================
--  LPI · Ejecuta TODO esto de una vez
--  Supabase → SQL Editor → New query → pega → Run
-- ============================================================

-- ── 1) Arregla el registro de alumnos/pagos/maestros/facturas ──
--    (el ERP usa valores como "Al corriente" que el CHECK rechazaba)
ALTER TABLE alumnos     DROP CONSTRAINT IF EXISTS alumnos_pago_check;
ALTER TABLE alumnos     DROP CONSTRAINT IF EXISTS alumnos_nivel_check;
ALTER TABLE pagos       DROP CONSTRAINT IF EXISTS pagos_estado_check;
ALTER TABLE maestros    DROP CONSTRAINT IF EXISTS maestros_estado_check;
ALTER TABLE facturas    DROP CONSTRAINT IF EXISTS facturas_estado_check;
ALTER TABLE comunicados DROP CONSTRAINT IF EXISTS comunicados_dest_check;

-- ── 2) Usuarios, roles y permisos (Configuración) ──
ALTER TABLE usuarios_sistema DROP CONSTRAINT IF EXISTS usuarios_sistema_rol_check;
ALTER TABLE usuarios_sistema ADD COLUMN IF NOT EXISTS email  TEXT;
ALTER TABLE usuarios_sistema ADD COLUMN IF NOT EXISTS acceso JSONB DEFAULT '[]'::jsonb;

-- Lista de roles personalizados (se guarda en configuracion)
INSERT INTO configuracion (clave, valor) VALUES ('roles', '[]')
ON CONFLICT (clave) DO NOTHING;

-- El admin tiene acceso total a todas las pestañas
UPDATE usuarios_sistema SET acceso = '["__all__"]'::jsonb WHERE usuario = 'admin';

-- ============================================================
--  Listo. Después: corre DEPLOY LPI.bat y recarga con Ctrl+Shift+R
-- ============================================================
