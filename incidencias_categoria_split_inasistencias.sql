-- ─────────────────────────────────────────────────────────────
-- Split de "Incidencias" en Conductuales/Académicas + renombre
-- de "Asistencia" a "Inasistencias" en el portal de padres
-- Aplicado 2026-08-11 vía Supabase MCP (proyecto bvmeunsyhrurigtgpedz)
-- ─────────────────────────────────────────────────────────────
--
-- Qué hace:
--   - ERP: el módulo "Incidencias" se dividió en dos pantallas/ventanas
--     independientes: "Incidencias conductuales" e "Incidencias académicas".
--     Cada incidencia ahora tiene una columna categoria ('Conductual' o
--     'Académica'); los registros existentes quedaron como 'Conductual'
--     por default (comportamiento previo).
--   - Permisos: staff_listar_incidencias, staff_guardar_incidencia y
--     staff_eliminar_incidencia ahora validan el acceso a
--     'incidencias_conductuales' / 'incidencias_academicas' en vez del
--     antiguo módulo único 'incidencias'. Los usuarios que ya tenían
--     acceso a 'incidencias' se migraron automáticamente para tener
--     ambos módulos nuevos (ver paso 7).
--   - Portal de padres: nueva función portal_incidencias(usuario,pass)
--     devuelve ambas categorías (los padres ven las dos).
--   - Portal de padres / Asistencia → "Inasistencias": portal_asistencia
--     ahora solo devuelve registros con estado 'F' (Faltó) o 'T' (Tarde);
--     los padres ya no ven el listado completo de "Asistió" día a día,
--     solo el reporte de inasistencias. La captura diaria en el ERP
--     (con A/F/T) no cambió.
--   - ERP: el módulo "Asistencia" (título interno) ahora se muestra como
--     "Inasistencias" en el menú y agrega un modo "Reporte de faltas"
--     (toggle en la barra de herramientas) que acumula faltas/tardes por
--     alumno del grupo, con exportación a Excel/PDF. La captura diaria
--     de A/F/T no se modificó.
--
-- Este archivo es un snapshot de referencia; la migración real ya está
-- aplicada en Supabase. Ver también: RESUMEN_TECNICO_PARA_IA.md.

-- 1) Nueva columna categoria en incidencias
alter table public.incidencias
  add column if not exists categoria text not null default 'Conductual';

alter table public.incidencias
  drop constraint if exists incidencias_categoria_check;
alter table public.incidencias
  add constraint incidencias_categoria_check check (categoria in ('Conductual','Académica'));

-- 2) staff_listar_incidencias: filtra por las categorías a las que el usuario tiene acceso
drop function if exists public.staff_listar_incidencias(text,text);
create function public.staff_listar_incidencias(p_usuario text, p_pass text)
returns setof incidencias
language plpgsql security definer set search_path to 'public'
as $$
declare
  v usuarios_sistema;
  v_conduct boolean;
  v_academ boolean;
begin
  v := public._staff_valida(p_usuario, p_pass);
  v_conduct := public._staff_tiene_acceso(v,'incidencias_conductuales');
  v_academ := public._staff_tiene_acceso(v,'incidencias_academicas');
  if not (v_conduct or v_academ) then
    raise exception 'Sin permiso para el módulo Incidencias';
  end if;
  return query select i.* from incidencias i
    left join alumnos a on a.id = i.alumno_id
    where (a.id is null or public._staff_tiene_seccion(v, a.nivel))
      and ((i.categoria = 'Conductual' and v_conduct) or (i.categoria = 'Académica' and v_academ))
    order by i.fecha desc;
end $$;
revoke all on function public.staff_listar_incidencias(text,text) from public;
grant execute on function public.staff_listar_incidencias(text,text) to anon, authenticated;

-- 3) staff_guardar_incidencia: nuevo parámetro p_categoria, valida el permiso correspondiente
drop function if exists public.staff_guardar_incidencia(text,text,integer,text,date,text);
create function public.staff_guardar_incidencia(p_usuario text, p_pass text, p_alumno_id integer, p_tipo text, p_fecha date, p_descripcion text, p_categoria text default 'Conductual')
returns incidencias
language plpgsql security definer set search_path to 'public'
as $$
declare v usuarios_sistema; v_row incidencias; v_cat text; v_modulo text;
begin
  v := public._staff_valida(p_usuario, p_pass);
  v_cat := case when p_categoria = 'Académica' then 'Académica' else 'Conductual' end;
  v_modulo := case when v_cat = 'Académica' then 'incidencias_academicas' else 'incidencias_conductuales' end;
  if not public._staff_tiene_acceso(v, v_modulo) then raise exception 'Sin permiso para el módulo Incidencias'; end if;
  insert into incidencias (alumno_id, tipo, fecha, descripcion, registrado_por, categoria)
  values (p_alumno_id, p_tipo, p_fecha, p_descripcion, v.nombre, v_cat)
  returning * into v_row;
  return v_row;
end $$;
revoke all on function public.staff_guardar_incidencia(text,text,integer,text,date,text,text) from public;
grant execute on function public.staff_guardar_incidencia(text,text,integer,text,date,text,text) to anon, authenticated;

-- 4) staff_eliminar_incidencia: valida el permiso según la categoría del registro a borrar
create or replace function public.staff_eliminar_incidencia(p_usuario text, p_pass text, p_id integer)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare v usuarios_sistema; v_cat text; v_modulo text;
begin
  v := public._staff_valida(p_usuario, p_pass);
  select categoria into v_cat from incidencias where id = p_id;
  if v_cat is null then return; end if;
  v_modulo := case when v_cat = 'Académica' then 'incidencias_academicas' else 'incidencias_conductuales' end;
  if not public._staff_tiene_acceso(v, v_modulo) then raise exception 'Sin permiso para el módulo Incidencias'; end if;
  delete from incidencias where id = p_id;
end $$;

-- 5) portal_incidencias: los padres ven ambas categorías
create or replace function public.portal_incidencias(p_usuario text, p_pass text)
returns table(categoria text, tipo text, descripcion text, fecha date)
language sql security definer set search_path to 'public'
as $$
  select i.categoria, i.tipo, i.descripcion, i.fecha
  from incidencias i
  join padres_acceso pa on pa.alumno_id = i.alumno_id
  where pa.usuario ilike p_usuario and pa.pass = extensions.crypt(p_pass, pa.pass) and pa.activo = true
  order by i.fecha desc;
$$;
revoke all on function public.portal_incidencias(text,text) from public;
grant execute on function public.portal_incidencias(text,text) to anon, authenticated;

-- 6) portal_asistencia: los padres solo ven inasistencias (Faltó/Tarde), no el registro diario completo
create or replace function public.portal_asistencia(p_usuario text, p_pass text)
returns table(fecha date, estado text)
language sql security definer set search_path to 'public'
as $$
  select a.fecha, a.estado from asistencia a
  join padres_acceso pa on pa.alumno_id = a.alumno_id
  where pa.usuario ilike p_usuario and pa.pass = extensions.crypt(p_pass, pa.pass) and pa.activo = true
    and a.estado in ('F','T')
  order by a.fecha desc limit 30;
$$;

-- 7) Migración de datos: usuarios con acceso a 'incidencias' ahora tienen ambos módulos nuevos
update usuarios_sistema
set acceso = (acceso - 'incidencias') || '["incidencias_conductuales","incidencias_academicas"]'::jsonb
where acceso @> '["incidencias"]'::jsonb;
