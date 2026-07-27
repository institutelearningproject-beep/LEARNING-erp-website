-- ============================================================
--  LPI · Configuración — Usuarios, Roles y Permisos
--  Ejecuta en: Supabase → SQL Editor → New query → Run
-- ============================================================

-- El rol ahora es personalizado (lo crea el admin), quitamos la restricción fija
ALTER TABLE usuarios_sistema DROP CONSTRAINT IF EXISTS usuarios_sistema_rol_check;

-- Correo y permisos (pestañas que maneja cada usuario)
ALTER TABLE usuarios_sistema ADD COLUMN IF NOT EXISTS email  TEXT;
ALTER TABLE usuarios_sistema ADD COLUMN IF NOT EXISTS acceso JSONB DEFAULT '[]'::jsonb;

-- Los roles personalizados se guardan en la tabla configuracion (clave='roles')
INSERT INTO configuracion (clave, valor) VALUES ('roles', '[]')
ON CONFLICT (clave) DO NOTHING;

-- Asegurar que el admin exista y tenga acceso total
UPDATE usuarios_sistema SET acceso = '["__all__"]'::jsonb WHERE usuario = 'admin';
