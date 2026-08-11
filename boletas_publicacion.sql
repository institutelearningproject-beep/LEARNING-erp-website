-- ─────────────────────────────────────────────────────────────
-- Boletas de calificaciones: paso de "publicar" + corrección de
-- permisos en staff_calificaciones_alumno
-- Aplicado 2026-08-09 vía Supabase MCP (proyecto bvmeunsyhrurigtgpedz)
-- ─────────────────────────────────────────────────────────────
--
-- Qué hace:
--   - Antes: guardar una calificación la hacía visible al padre al instante.
--   - Ahora: existe una tabla boletas_publicadas (grupo+periodo). El padre
--     (portal_calificaciones, y el promedio en portal_resumen) solo ve
--     calificaciones de combinaciones grupo+periodo ya publicadas.
--   - staff_publicar_boleta / staff_despublicar_boleta / staff_estado_boleta:
--     controlan y consultan ese estado desde el ERP (valen los mismos
--     permisos de módulo+sección que ya tenía Calificaciones).
--   - Fix de seguridad: staff_calificaciones_alumno no validaba el nivel/
--     sección del alumno consultado (sí lo hacían las demás funciones de
--     Calificaciones) — ahora sí, igual que staff_obtener_acceso_padre.
--
-- Este archivo es un snapshot de referencia; la migración real ya está
-- aplicada en Supabase. Ver también: RESUMEN_TECNICO_PARA_IA.md.

-- 1) Fix de seguridad
create or replace function public.staff_calificaciones_alumno(p_usuario text, p_pass text, p_alumno_id integer)
returns setof calificaciones
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v usuarios_sistema;
  v_nivel text;
begin
  v := public._staff_valida(p_usuario, p_pass);
  if not (v.usuario='admin' or v.acceso @> '["__all__"]'::jsonb or public._staff_tiene_acceso(v,'calificaciones')) then
    raise exception 'Sin permiso para consultar calificaciones';
  end if;

  select al.nivel into v_nivel from alumnos al where al.id = p_alumno_id;
  if v_nivel is not null and not public._staff_tiene_seccion(v, v_nivel) then
    raise exception 'Sin permiso sobre el nivel del alumno';
  end if;

  return query select c.* from calificaciones c where c.alumno_id = p_alumno_id;
end $$;

-- 2) Publicación de boletas
create table if not exists public.boletas_publicadas (
  grupo text not null,
  periodo text not null,
  publicado_por text,
  publicado_at timestamptz not null default now(),
  primary key (grupo, periodo)
);
alter table public.boletas_publicadas enable row level security;
revoke all on public.boletas_publicadas from anon, authenticated;

create or replace function public.staff_publicar_boleta(p_usuario text, p_pass text, p_grupo text, p_periodo text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare v usuarios_sistema;
begin
  v := public._staff_valida(p_usuario, p_pass);
  if not public._staff_tiene_acceso(v, 'calificaciones') then raise exception 'Sin permiso para el módulo Calificaciones'; end if;
  if not public._staff_tiene_seccion(v, public._grupo_a_nivel(p_grupo)) then raise exception 'Sin permiso sobre el nivel de ese grupo'; end if;
  insert into boletas_publicadas(grupo, periodo, publicado_por, publicado_at)
    values (p_grupo, p_periodo, v.nombre, now())
  on conflict (grupo, periodo) do update set publicado_por = excluded.publicado_por, publicado_at = now();
end $$;

create or replace function public.staff_despublicar_boleta(p_usuario text, p_pass text, p_grupo text, p_periodo text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare v usuarios_sistema;
begin
  v := public._staff_valida(p_usuario, p_pass);
  if not public._staff_tiene_acceso(v, 'calificaciones') then raise exception 'Sin permiso para el módulo Calificaciones'; end if;
  if not public._staff_tiene_seccion(v, public._grupo_a_nivel(p_grupo)) then raise exception 'Sin permiso sobre el nivel de ese grupo'; end if;
  delete from boletas_publicadas where grupo = p_grupo and periodo = p_periodo;
end $$;

create or replace function public.staff_estado_boleta(p_usuario text, p_pass text, p_grupo text, p_periodo text)
returns table(publicado boolean, publicado_por text, publicado_at timestamptz)
language plpgsql security definer set search_path to 'public'
as $$
declare v usuarios_sistema; v_row boletas_publicadas;
begin
  v := public._staff_valida(p_usuario, p_pass);
  if not public._staff_tiene_acceso(v, 'calificaciones') then raise exception 'Sin permiso para el módulo Calificaciones'; end if;
  if not public._staff_tiene_seccion(v, public._grupo_a_nivel(p_grupo)) then raise exception 'Sin permiso sobre el nivel de ese grupo'; end if;
  select * into v_row from boletas_publicadas bp where bp.grupo = p_grupo and bp.periodo = p_periodo;
  if v_row.grupo is null then return query select false, null::text, null::timestamptz;
  else return query select true, v_row.publicado_por, v_row.publicado_at; end if;
end $$;

revoke all on function public.staff_publicar_boleta(text,text,text,text) from public;
revoke all on function public.staff_despublicar_boleta(text,text,text,text) from public;
revoke all on function public.staff_estado_boleta(text,text,text,text) from public;
grant execute on function public.staff_publicar_boleta(text,text,text,text) to anon, authenticated;
grant execute on function public.staff_despublicar_boleta(text,text,text,text) to anon, authenticated;
grant execute on function public.staff_estado_boleta(text,text,text,text) to anon, authenticated;

-- 3) portal_calificaciones: solo boletas publicadas (+ grupo y fecha de publicación)
drop function if exists public.portal_calificaciones(text,text);
create function public.portal_calificaciones(p_usuario text, p_pass text)
returns table(materia text, calificacion numeric, periodo text, grupo text, publicado_at timestamptz)
language sql security definer set search_path to 'public'
as $$
  select c.materia, c.calificacion, c.periodo, c.grupo, bp.publicado_at
  from calificaciones c
  join padres_acceso pa on pa.alumno_id = c.alumno_id
  join boletas_publicadas bp on bp.grupo = c.grupo and bp.periodo = c.periodo
  where pa.usuario ilike p_usuario and pa.pass = extensions.crypt(p_pass, pa.pass) and pa.activo = true
  order by bp.publicado_at desc, c.periodo, c.materia;
$$;
grant execute on function public.portal_calificaciones(text,text) to anon, authenticated;

-- 4) portal_resumen: promedio del inicio también solo con boletas publicadas
create or replace function public.portal_resumen(p_usuario text, p_pass text)
returns table(adeudo_total numeric, cargos_pendientes integer, cargos_vencidos integer, avisos_no_leidos integer, promedio numeric, asistencia_pct integer, pagos_en_revision integer, ciclo text)
language plpgsql security definer set search_path to 'public'
as $$
DECLARE v_alumno int; v_nivel text;
BEGIN
  v_alumno := public._portal_alumno(p_usuario, p_pass);
  IF v_alumno IS NULL THEN RAISE EXCEPTION 'Acceso invalido'; END IF;
  SELECT a.nivel INTO v_nivel FROM alumnos a WHERE a.id = v_alumno;
  RETURN QUERY
  SELECT
    COALESCE((SELECT SUM(p.monto) FROM pagos p WHERE p.alumno_id = v_alumno AND COALESCE(p.estado,'Pendiente') IN ('Pendiente','Vencido')), 0)::numeric,
    COALESCE((SELECT COUNT(*) FROM pagos p WHERE p.alumno_id = v_alumno AND COALESCE(p.estado,'Pendiente') IN ('Pendiente','Vencido')), 0)::int,
    COALESCE((SELECT COUNT(*) FROM pagos p WHERE p.alumno_id = v_alumno AND (p.estado = 'Vencido' OR (COALESCE(p.estado,'Pendiente') = 'Pendiente' AND p.fecha < CURRENT_DATE))), 0)::int,
    COALESCE((SELECT COUNT(*) FROM comunicados c LEFT JOIN comunicados_lecturas l ON l.comunicado_id = c.id AND l.alumno_id = v_alumno
              WHERE l.id IS NULL AND (c.dest IS NULL OR c.dest = '' OR c.dest ILIKE '%todos%' OR (v_nivel IS NOT NULL AND c.dest ILIKE '%' || v_nivel || '%'))), 0)::int,
    (SELECT ROUND(AVG(k.calificacion), 1) FROM calificaciones k
       JOIN boletas_publicadas bp ON bp.grupo = k.grupo AND bp.periodo = k.periodo
      WHERE k.alumno_id = v_alumno),
    (SELECT CASE WHEN COUNT(*) = 0 THEN NULL ELSE ROUND(100.0 * SUM(CASE WHEN s.estado = 'A' THEN 1 ELSE 0 END) / COUNT(*))::int END FROM asistencia s WHERE s.alumno_id = v_alumno),
    COALESCE((SELECT COUNT(*) FROM pagos_online o WHERE o.alumno_id = v_alumno AND o.estado IN ('iniciado','en_revision')), 0)::int,
    (SELECT c.valor FROM configuracion c WHERE c.clave = 'ciclo_escolar');
END $$;
