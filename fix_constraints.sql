-- ============================================================
--  LPI · FIX — Quita las restricciones CHECK que bloquean
--  el registro de alumnos, pagos, maestros y facturas.
--  Causa del error "Error al registrar alumno":
--  el ERP envía pago='Al corriente'/'Parcial', pero la tabla
--  solo aceptaba 'Pagado'/'Pendiente'/'Vencido'.
--
--  Ejecuta TODO esto en: Supabase → SQL Editor → New query → Run
-- ============================================================

ALTER TABLE alumnos   DROP CONSTRAINT IF EXISTS alumnos_pago_check;
ALTER TABLE alumnos   DROP CONSTRAINT IF EXISTS alumnos_nivel_check;
ALTER TABLE pagos     DROP CONSTRAINT IF EXISTS pagos_estado_check;
ALTER TABLE maestros  DROP CONSTRAINT IF EXISTS maestros_estado_check;
ALTER TABLE facturas  DROP CONSTRAINT IF EXISTS facturas_estado_check;
ALTER TABLE comunicados DROP CONSTRAINT IF EXISTS comunicados_dest_check;

-- Listo. Ahora el ERP puede registrar con cualquiera de sus valores.
