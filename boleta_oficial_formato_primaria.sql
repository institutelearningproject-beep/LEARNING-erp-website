-- ─────────────────────────────────────────────────────────────
-- Boleta de calificaciones en el formato oficial de la escuela
-- (BOLETA DE EVALUACIÓN INTERNA), primera versión para Primaria.
-- Aplicado 2026-08-11 vía Supabase MCP (proyecto bvmeunsyhrurigtgpedz)
-- ─────────────────────────────────────────────────────────────
--
-- Qué hace:
--   - Catálogo de materias de Primaria (10, aplican a los 6 grados):
--     Lenguajes, Saberes y Pensamiento Científico, Ética Naturaleza y
--     Sociedades, De lo Humano y lo Comunitario, Inglés, Música,
--     Tecnología, Francés, Educación Física, Mindfulness. Se agregó
--     una columna "orden" en materias para que la boleta las liste
--     siempre en este orden.
--   - Config nueva: turno_escolar (Matutino por default).
--   - staff_calificaciones_boleta: trae TODAS las calificaciones de
--     un grupo (los 3 trimestres a la vez), para poder armar la
--     boleta con columnas 1°/2°/3° periodo + promedio final, igual
--     que el Excel de referencia.
--   - portal_datos_escuela: función pública (sin login) que expone
--     nombre del instituto, CCT y turno para el encabezado de la
--     boleta — son datos ya públicos en el sitio web.
--   - portal_login ahora también regresa curp y ficha (nombre
--     dividido en apellidos/nombres) del alumno, para poder mostrarlos
--     en la boleta del portal de padres.
--   - En el ERP, el botón "Boleta oficial" (módulo Calificaciones)
--     ahora arma el documento en este formato: datos del alumno
--     (apellidos/nombres/CURP/grupo), datos de la escuela (turno/CCT/
--     ciclo escolar), tabla de materias x los 3 periodos + promedio
--     final por materia, promedio final de grado, firma de padre/
--     tutor por periodo, y firmas de docentes/directora.
--   - En el portal de padres, la pestaña "Calificaciones" muestra el
--     mismo pivote (materia x periodo) y el botón "Ver / imprimir
--     boleta oficial" genera el mismo documento — solo con los
--     periodos que la escuela ya publicó (boletas_publicadas sigue
--     controlando qué ven los padres).
--
-- Este archivo es un snapshot de referencia; la migración real ya está
-- aplicada en Supabase.

-- 1) Config: turno escolar
insert into public.configuracion (clave, valor)
values ('turno_escolar', 'Matutino')
on conflict (clave) do nothing;

-- 2) Catálogo de materias de Primaria
alter table public.materias add column if not exists orden integer;

insert into public.materias (nombre, nivel, grado, grupo, docente, creado_por)
select v.nombre, 'Primaria', null, null, null, 'sistema'
from (values
  ('Lenguajes'),
  ('Saberes y Pensamiento Científico'),
  ('Ética, Naturaleza y Sociedades'),
  ('De lo Humano y lo Comunitario'),
  ('Inglés'),
  ('Música'),
  ('Tecnología'),
  ('Francés'),
  ('Educación Física'),
  ('Mindfulness')
) as v(nombre)
where not exists (
  select 1 from public.materias m where m.nivel = 'Primaria' and m.nombre = v.nombre
);

update public.materias set orden = t.orden
from (values
  ('Lenguajes', 1),
  ('Saberes y Pensamiento Científico', 2),
  ('Ética, Naturaleza y Sociedades', 3),
  ('De lo Humano y lo Comunitario', 4),
  ('Inglés', 5),
  ('Música', 6),
  ('Tecnología', 7),
  ('Francés', 8),
  ('Educación Física', 9),
  ('Mindfulness', 10)
) as t(nombre, orden)
where public.materias.nivel = 'Primaria' and public.materias.nombre = t.nombre;

create or replace function public.staff_listar_materias(p_usuario text, p_pass text)
returns setof materias
language plpgsql security definer set search_path to 'public'
as $$
declare v usuarios_sistema;
begin
  v := public._staff_valida(p_usuario, p_pass);
  return query select m.* from materias m where m.nivel is null or public._staff_tiene_seccion(v, m.nivel) order by m.nivel, coalesce(m.orden, 999), m.id;
end $$;

-- 3) Calificaciones de todos los periodos de un grupo (staff)
create or replace function public.staff_calificaciones_boleta(p_usuario text, p_pass text, p_grupo text)
returns setof calificaciones
language plpgsql security definer set search_path to 'public'
as $$
declare v usuarios_sistema;
begin
  v := public._staff_valida(p_usuario, p_pass);
  if not public._staff_tiene_acceso(v, 'calificaciones') then
    raise exception 'Sin permiso para el módulo Calificaciones';
  end if;
  if not public._staff_tiene_seccion(v, public._grupo_a_nivel(p_grupo)) then
    raise exception 'Sin permiso sobre el nivel de ese grupo';
  end if;
  return query select c.* from calificaciones c where c.grupo = p_grupo;
end $$;
revoke all on function public.staff_calificaciones_boleta(text,text,text) from public;
grant execute on function public.staff_calificaciones_boleta(text,text,text) to anon, authenticated;

-- 4) Datos públicos de la escuela para el encabezado de la boleta (portal de padres)
create or replace function public.portal_datos_escuela()
returns table(nombre_instituto text, cct text, turno_escolar text)
language sql security definer set search_path to 'public'
as $$
  select
    (select valor from configuracion where clave='nombre_instituto'),
    (select valor from configuracion where clave='cct'),
    (select valor from configuracion where clave='turno_escolar');
$$;
revoke all on function public.portal_datos_escuela() from public;
grant execute on function public.portal_datos_escuela() to anon, authenticated;

-- 5) portal_login ahora también regresa curp y ficha
drop function if exists public.portal_login(text,text);
create function public.portal_login(p_usuario text, p_pass text)
returns table(id integer, nombre text, nivel text, grado text, email text, curp text, ficha jsonb)
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_id text := lower(trim(p_usuario));
  v_restante integer;
  v_match boolean;
begin
  v_restante := public._auth_bloqueo_restante('padres', v_id);
  if v_restante > 0 then
    raise exception using message = 'LOCKED:Demasiados intentos. Intenta de nuevo en ' || v_restante || ' minuto(s).';
  end if;

  select exists(
    select 1 from padres_acceso pa
    where pa.usuario ilike p_usuario and pa.pass = extensions.crypt(p_pass, pa.pass) and pa.activo = true
  ) into v_match;

  perform public._auth_registrar_resultado('padres', v_id, v_match);

  if not v_match then
    return;
  end if;

  return query
    select a.id, a.nombre, a.nivel, a.grado, a.email, a.curp, a.ficha
    from padres_acceso pa join alumnos a on a.id = pa.alumno_id
    where pa.usuario ilike p_usuario and pa.pass = extensions.crypt(p_pass, pa.pass) and pa.activo = true
    limit 1;
end;
$$;
revoke all on function public.portal_login(text,text) from public;
grant execute on function public.portal_login(text,text) to anon, authenticated;
