-- ============================================================
--  LPI · App de Padres — Pagos en línea + Avisos con lectura
--  Migración ADITIVA. No abre ninguna tabla al rol anon.
--  Proyecto Supabase: bvmeunsyhrurigtgpedz
-- ============================================================

-- ── 1. Tabla de pagos reportados / en línea ──────────────────
CREATE TABLE IF NOT EXISTS pagos_online (
  id                  SERIAL PRIMARY KEY,
  alumno_id           INT NOT NULL REFERENCES alumnos(id) ON DELETE CASCADE,
  pago_id             INT REFERENCES pagos(id) ON DELETE SET NULL,
  referencia          TEXT UNIQUE NOT NULL,
  concepto            TEXT NOT NULL,
  monto               NUMERIC(10,2) NOT NULL,
  metodo              TEXT NOT NULL DEFAULT 'transferencia'
                      CHECK (metodo IN ('transferencia','deposito','tarjeta','oxxo','mercadopago','stripe','otro')),
  estado              TEXT NOT NULL DEFAULT 'en_revision'
                      CHECK (estado IN ('iniciado','en_revision','aprobado','rechazado','cancelado')),
  comprobante         TEXT,          -- data URL del comprobante que sube el padre
  comprobante_nombre  TEXT,
  referencia_externa  TEXT,          -- id de la pasarela cuando se conecte una
  nota_padre          TEXT,
  nota_staff          TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  resuelto_at         TIMESTAMPTZ,
  resuelto_por        TEXT
);
ALTER TABLE pagos_online ENABLE ROW LEVEL SECURITY;  -- sin políticas: cerrado a anon
CREATE INDEX IF NOT EXISTS idx_pagos_online_alumno ON pagos_online(alumno_id);
CREATE INDEX IF NOT EXISTS idx_pagos_online_pago   ON pagos_online(pago_id);
CREATE INDEX IF NOT EXISTS idx_pagos_online_estado ON pagos_online(estado);

-- ── 2. Datos bancarios / de pago (configuración) ─────────────
INSERT INTO configuracion (clave, valor) VALUES
  ('pago_banco',        'Por definir'),
  ('pago_clabe',        ''),
  ('pago_beneficiario', 'LEARNING PROJECT INSTITUTE S.C.'),
  ('pago_instrucciones','Realiza tu transferencia o depósito y sube aquí tu comprobante. La escuela lo valida y tu pago queda registrado en un máximo de 24 horas hábiles.'),
  ('pago_metodos',      '{"transferencia":true,"tarjeta":false,"oxxo":false}')
ON CONFLICT (clave) DO NOTHING;

-- ── 3. Helper interno de validación del portal ───────────────
CREATE OR REPLACE FUNCTION public._portal_alumno(p_usuario text, p_pass text)
RETURNS int
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT pa.alumno_id FROM padres_acceso pa
   WHERE pa.usuario ILIKE p_usuario
     AND pa.pass = extensions.crypt(p_pass, pa.pass)
     AND pa.activo = true
   LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public._portal_alumno(text,text) FROM PUBLIC, anon, authenticated;

-- ── 4. Estado de cuenta del alumno ───────────────────────────
CREATE OR REPLACE FUNCTION public.portal_estado_cuenta(p_usuario text, p_pass text)
RETURNS TABLE(pago_id int, concepto text, monto numeric, fecha date, estado text,
              dias_vencido int, reporte_estado text, reporte_referencia text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_alumno int;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso inválido'; END IF;
  RETURN QUERY
    SELECT p.id, p.concepto, p.monto, p.fecha, p.estado,
           GREATEST(0, (CURRENT_DATE - p.fecha))::int,
           po.estado, po.referencia
      FROM pagos p
      LEFT JOIN LATERAL (
        SELECT o.estado, o.referencia FROM pagos_online o
         WHERE o.pago_id = p.id AND o.estado <> 'cancelado'
         ORDER BY o.created_at DESC LIMIT 1
      ) po ON true
     WHERE p.alumno_id = v_alumno
       AND COALESCE(p.estado,'Pendiente') IN ('Pendiente','Vencido')
     ORDER BY p.fecha ASC NULLS LAST, p.id ASC;
END $$;
GRANT EXECUTE ON FUNCTION public.portal_estado_cuenta(text,text) TO anon, authenticated;

-- ── 5. Historial de pagos ya aplicados ───────────────────────
CREATE OR REPLACE FUNCTION public.portal_historial_pagos(p_usuario text, p_pass text)
RETURNS TABLE(pago_id int, concepto text, monto numeric, fecha date, estado text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_alumno int;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso inválido'; END IF;
  RETURN QUERY
    SELECT p.id, p.concepto, p.monto, p.fecha, p.estado
      FROM pagos p
     WHERE p.alumno_id = v_alumno AND p.estado = 'Pagado'
     ORDER BY p.fecha DESC NULLS LAST, p.id DESC
     LIMIT 60;
END $$;
GRANT EXECUTE ON FUNCTION public.portal_historial_pagos(text,text) TO anon, authenticated;

-- ── 6. Datos para pagar (lista blanca de configuración) ──────
CREATE OR REPLACE FUNCTION public.portal_datos_pago(p_usuario text, p_pass text)
RETURNS TABLE(clave text, valor text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_alumno int;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso inválido'; END IF;
  RETURN QUERY
    SELECT c.clave, c.valor FROM configuracion c
     WHERE c.clave IN ('pago_banco','pago_clabe','pago_beneficiario','pago_instrucciones',
                       'pago_metodos','nombre_instituto','dia_vencimiento','ciclo_escolar');
END $$;
GRANT EXECUTE ON FUNCTION public.portal_datos_pago(text,text) TO anon, authenticated;

-- ── 7. El padre reporta un pago (sube comprobante) ───────────
CREATE OR REPLACE FUNCTION public.portal_reportar_pago(
  p_usuario text, p_pass text, p_pago_id int, p_metodo text,
  p_comprobante text, p_comprobante_nombre text, p_nota text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_alumno int; v_concepto text; v_monto numeric; v_ref text;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso inválido'; END IF;

  SELECT p.concepto, p.monto INTO v_concepto, v_monto
    FROM pagos p
   WHERE p.id = p_pago_id AND p.alumno_id = v_alumno
     AND COALESCE(p.estado,'Pendiente') IN ('Pendiente','Vencido');
  IF v_concepto IS NULL THEN
    RAISE EXCEPTION 'El cargo no existe, ya está pagado o no pertenece a este alumno';
  END IF;

  IF EXISTS (SELECT 1 FROM pagos_online o
              WHERE o.pago_id = p_pago_id AND o.estado IN ('iniciado','en_revision','aprobado')) THEN
    RAISE EXCEPTION 'Ya hay un pago reportado para este cargo';
  END IF;

  IF p_comprobante IS NOT NULL AND length(p_comprobante) > 3500000 THEN
    RAISE EXCEPTION 'El comprobante es demasiado grande (máximo ~2.5 MB)';
  END IF;

  IF COALESCE(p_metodo,'') NOT IN ('transferencia','deposito','tarjeta','oxxo','mercadopago','stripe','otro') THEN
    p_metodo := 'transferencia';
  END IF;

  v_ref := 'PO-' || to_char(now(),'YYMMDD') || '-' || lpad((floor(random()*10000))::text, 4, '0')
           || '-' || p_pago_id::text;

  INSERT INTO pagos_online (alumno_id, pago_id, referencia, concepto, monto, metodo,
                            estado, comprobante, comprobante_nombre, nota_padre)
  VALUES (v_alumno, p_pago_id, v_ref, v_concepto, v_monto, p_metodo,
          'en_revision', p_comprobante, left(COALESCE(p_comprobante_nombre,''),120), left(COALESCE(p_nota,''),400));

  RETURN v_ref;
END $$;
GRANT EXECUTE ON FUNCTION public.portal_reportar_pago(text,text,int,text,text,text,text) TO anon, authenticated;

-- ── 8. Mis pagos reportados ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.portal_pagos_reportados(p_usuario text, p_pass text)
RETURNS TABLE(id int, referencia text, concepto text, monto numeric, metodo text,
              estado text, nota_staff text, created_at timestamptz, resuelto_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_alumno int;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso inválido'; END IF;
  RETURN QUERY
    SELECT o.id, o.referencia, o.concepto, o.monto, o.metodo, o.estado,
           o.nota_staff, o.created_at, o.resuelto_at
      FROM pagos_online o
     WHERE o.alumno_id = v_alumno
     ORDER BY o.created_at DESC
     LIMIT 40;
END $$;
GRANT EXECUTE ON FUNCTION public.portal_pagos_reportados(text,text) TO anon, authenticated;

-- ── 9. Avisos con marca de leído ─────────────────────────────
DROP FUNCTION IF EXISTS public.portal_avisos(text,text);
CREATE OR REPLACE FUNCTION public.portal_avisos(p_usuario text, p_pass text)
RETURNS TABLE(id int, titulo text, preview text, fecha date, dest text, leido boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_alumno int; v_nivel text;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso inválido'; END IF;
  SELECT a.nivel INTO v_nivel FROM alumnos a WHERE a.id = v_alumno;
  RETURN QUERY
    SELECT c.id, c.titulo, c.preview, c.fecha, c.dest,
           (l.id IS NOT NULL)
      FROM comunicados c
      LEFT JOIN comunicados_lecturas l
             ON l.comunicado_id = c.id AND l.alumno_id = v_alumno
     WHERE (c.dest IS NULL OR c.dest = '' OR c.dest ILIKE '%todos%'
            OR (v_nivel IS NOT NULL AND c.dest ILIKE '%' || v_nivel || '%'))
     ORDER BY c.fecha DESC NULLS LAST, c.id DESC
     LIMIT 30;
END $$;
GRANT EXECUTE ON FUNCTION public.portal_avisos(text,text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.portal_marcar_aviso_leido(p_usuario text, p_pass text, p_comunicado_id int)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_alumno int;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso inválido'; END IF;
  IF NOT EXISTS (SELECT 1 FROM comunicados WHERE id = p_comunicado_id) THEN
    RETURN false;
  END IF;
  INSERT INTO comunicados_lecturas (comunicado_id, alumno_id, leido_at)
  VALUES (p_comunicado_id, v_alumno, now())
  ON CONFLICT (comunicado_id, alumno_id) DO NOTHING;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.portal_marcar_aviso_leido(text,text,int) TO anon, authenticated;

-- ── 10. Resumen para la pantalla de inicio de la app ─────────
CREATE OR REPLACE FUNCTION public.portal_resumen(p_usuario text, p_pass text)
RETURNS TABLE(adeudo_total numeric, cargos_pendientes int, cargos_vencidos int,
              avisos_no_leidos int, promedio numeric, asistencia_pct int,
              pagos_en_revision int, ciclo text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_alumno int; v_nivel text;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso inválido'; END IF;
  SELECT a.nivel INTO v_nivel FROM alumnos a WHERE a.id = v_alumno;
  RETURN QUERY
  SELECT
    COALESCE((SELECT SUM(p.monto) FROM pagos p
               WHERE p.alumno_id = v_alumno
                 AND COALESCE(p.estado,'Pendiente') IN ('Pendiente','Vencido')), 0)::numeric,
    COALESCE((SELECT COUNT(*) FROM pagos p
               WHERE p.alumno_id = v_alumno
                 AND COALESCE(p.estado,'Pendiente') IN ('Pendiente','Vencido')), 0)::int,
    COALESCE((SELECT COUNT(*) FROM pagos p
               WHERE p.alumno_id = v_alumno
                 AND (p.estado = 'Vencido'
                      OR (COALESCE(p.estado,'Pendiente') = 'Pendiente' AND p.fecha < CURRENT_DATE))), 0)::int,
    COALESCE((SELECT COUNT(*) FROM comunicados c
               LEFT JOIN comunicados_lecturas l
                      ON l.comunicado_id = c.id AND l.alumno_id = v_alumno
              WHERE l.id IS NULL
                AND (c.dest IS NULL OR c.dest = '' OR c.dest ILIKE '%todos%'
                     OR (v_nivel IS NOT NULL AND c.dest ILIKE '%' || v_nivel || '%'))), 0)::int,
    (SELECT ROUND(AVG(k.calificacion), 1) FROM calificaciones k WHERE k.alumno_id = v_alumno),
    (SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                 ELSE ROUND(100.0 * SUM(CASE WHEN s.estado = 'A' THEN 1 ELSE 0 END) / COUNT(*))::int END
       FROM asistencia s WHERE s.alumno_id = v_alumno),
    COALESCE((SELECT COUNT(*) FROM pagos_online o
               WHERE o.alumno_id = v_alumno AND o.estado IN ('iniciado','en_revision')), 0)::int,
    (SELECT c.valor FROM configuracion c WHERE c.clave = 'ciclo_escolar');
END $$;
GRANT EXECUTE ON FUNCTION public.portal_resumen(text,text) TO anon, authenticated;

-- ── 11. Lado ERP: revisar y conciliar los pagos reportados ───
CREATE OR REPLACE FUNCTION public.staff_listar_pagos_online(p_usuario text, p_pass text)
RETURNS TABLE(id int, referencia text, alumno_id int, alumno text, pago_id int,
              concepto text, monto numeric, metodo text, estado text,
              comprobante_nombre text, tiene_comprobante boolean, nota_padre text,
              nota_staff text, created_at timestamptz, resuelto_at timestamptz, resuelto_por text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v usuarios_sistema;
BEGIN
  v := public._staff_valida(p_usuario, p_pass);
  IF NOT public._staff_tiene_acceso(v, 'pagos') THEN
    RAISE EXCEPTION 'Sin permiso para el módulo Pagos';
  END IF;
  RETURN QUERY
    SELECT o.id, o.referencia, o.alumno_id, a.nombre, o.pago_id, o.concepto, o.monto,
           o.metodo, o.estado, o.comprobante_nombre, (o.comprobante IS NOT NULL),
           o.nota_padre, o.nota_staff, o.created_at, o.resuelto_at, o.resuelto_por
      FROM pagos_online o
      LEFT JOIN alumnos a ON a.id = o.alumno_id
     WHERE a.id IS NULL OR public._staff_tiene_seccion(v, a.nivel)
     ORDER BY (o.estado = 'en_revision') DESC, o.created_at DESC;
END $$;
GRANT EXECUTE ON FUNCTION public.staff_listar_pagos_online(text,text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.staff_ver_comprobante(p_usuario text, p_pass text, p_id int)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v usuarios_sistema; v_doc text;
BEGIN
  v := public._staff_valida(p_usuario, p_pass);
  IF NOT public._staff_tiene_acceso(v, 'pagos') THEN
    RAISE EXCEPTION 'Sin permiso para el módulo Pagos';
  END IF;
  SELECT o.comprobante INTO v_doc FROM pagos_online o WHERE o.id = p_id;
  RETURN v_doc;
END $$;
GRANT EXECUTE ON FUNCTION public.staff_ver_comprobante(text,text,int) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.staff_resolver_pago_online(
  p_usuario text, p_pass text, p_id int, p_estado text, p_nota text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v usuarios_sistema; v_pago_id int; v_alumno_id int;
BEGIN
  v := public._staff_valida(p_usuario, p_pass);
  IF NOT public._staff_tiene_acceso(v, 'pagos') THEN
    RAISE EXCEPTION 'Sin permiso para el módulo Pagos';
  END IF;
  IF p_estado NOT IN ('aprobado','rechazado','cancelado','en_revision') THEN
    RAISE EXCEPTION 'Estado no válido';
  END IF;

  SELECT o.pago_id, o.alumno_id INTO v_pago_id, v_alumno_id FROM pagos_online o WHERE o.id = p_id;
  IF v_alumno_id IS NULL THEN RAISE EXCEPTION 'Reporte de pago no encontrado'; END IF;

  UPDATE pagos_online
     SET estado = p_estado,
         nota_staff = left(COALESCE(p_nota,''),400),
         resuelto_at = CASE WHEN p_estado = 'en_revision' THEN NULL ELSE now() END,
         resuelto_por = CASE WHEN p_estado = 'en_revision' THEN NULL ELSE v.usuario END
   WHERE id = p_id;

  IF p_estado = 'aprobado' AND v_pago_id IS NOT NULL THEN
    UPDATE pagos SET estado = 'Pagado' WHERE id = v_pago_id;
    UPDATE alumnos SET pago = 'Pagado'
     WHERE id = v_alumno_id
       AND NOT EXISTS (SELECT 1 FROM pagos p2
                        WHERE p2.alumno_id = v_alumno_id
                          AND COALESCE(p2.estado,'Pendiente') IN ('Pendiente','Vencido'));
  END IF;

  RETURN p_estado;
END $$;
GRANT EXECUTE ON FUNCTION public.staff_resolver_pago_online(text,text,int,text,text) TO anon, authenticated;

-- ── 12. Lado ERP: quién leyó cada comunicado ─────────────────
CREATE OR REPLACE FUNCTION public.staff_lecturas_comunicado(p_usuario text, p_pass text, p_comunicado_id int)
RETURNS TABLE(alumno_id int, alumno text, nivel text, leido_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v usuarios_sistema;
BEGIN
  v := public._staff_valida(p_usuario, p_pass);
  IF NOT public._staff_tiene_acceso(v, 'comunicados') THEN
    RAISE EXCEPTION 'Sin permiso para el módulo Comunicados';
  END IF;
  RETURN QUERY
    SELECT a.id, a.nombre, a.nivel, l.leido_at
      FROM comunicados_lecturas l
      JOIN alumnos a ON a.id = l.alumno_id
     WHERE l.comunicado_id = p_comunicado_id
       AND public._staff_tiene_seccion(v, a.nivel)
     ORDER BY l.leido_at DESC;
END $$;
GRANT EXECUTE ON FUNCTION public.staff_lecturas_comunicado(text,text,int) TO anon, authenticated;

-- ============================================================
--  FIN — ninguna tabla nueva queda accesible al rol anon.
-- ============================================================
