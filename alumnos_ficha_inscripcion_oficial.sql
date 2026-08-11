-- ─────────────────────────────────────────────────────────────
-- Ficha de inscripción oficial (formato Learning Project Institute)
-- Aplicado 2026-08-11 vía Supabase MCP (proyecto bvmeunsyhrurigtgpedz)
-- ─────────────────────────────────────────────────────────────
--
-- Qué hace:
--   - Nueva columna jsonb "ficha" en alumnos: guarda todos los campos
--     del formato oficial de inscripción (domicilio del alumno, y los
--     datos completos de padre / madre / tutor: nombre, CURP, RFC,
--     fecha de nacimiento, estado civil, domicilio, teléfonos, email,
--     ocupación, grado de estudios; el tutor además con parentesco,
--     sexo, edad y domicilio propio).
--   - staff_guardar_alumno ahora acepta un parámetro p_ficha (jsonb)
--     además de los ya existentes p_curp / p_nacimiento (que ya
--     existían en la función pero no se usaban desde el formulario;
--     ahora sí se capturan).
--   - El formulario "Nuevo alumno / Editar alumno" del ERP se amplió
--     para capturar todos estos campos, editables en cualquier momento.
--   - El botón "Imprimir ficha" ahora incluye estos datos en el
--     documento imprimible, con el mismo diseño (logo y formato)
--     que ya se usaba para la ficha de inscripción del ERP.
--   - Fix menor: se detectó que setupAlumnoForm() (la función que
--     llena la lista de contactos/tutores y de documentos al abrir
--     el formulario) nunca se llamaba desde editAlumno()/openAddAlumno();
--     se corrigió para que la lista de contactos y documentos se
--     muestre correctamente al editar un alumno.
--
-- No se agregaron fotos de padre/madre/tutor ni el croquis del
-- domicilio en esta primera versión (solo la foto del alumno, que
-- ya existía).
--
-- Este archivo es un snapshot de referencia; la migración real ya está
-- aplicada en Supabase.

alter table public.alumnos
  add column if not exists ficha jsonb not null default '{}'::jsonb;

create or replace function public.staff_guardar_alumno(
  p_usuario text, p_pass text, p_id integer, p_nombre text, p_nivel text, p_grado text, p_tutor text,
  p_tel text, p_email text, p_pago text, p_asist text, p_foto text, p_matricula text, p_edad text,
  p_anio_cursante text, p_fecha_ingreso date, p_tutores jsonb, p_historial jsonb, p_documentos jsonb,
  p_curp text default null, p_nacimiento date default null, p_ficha jsonb default null
)
returns alumnos
language plpgsql security definer set search_path to 'public'
as $$
declare v usuarios_sistema; v_old alumnos; v_row alumnos;
begin
  v := public._staff_valida(p_usuario, p_pass);
  if not public._staff_tiene_acceso(v, 'alumnos') then
    raise exception 'Sin permiso para el módulo Alumnos';
  end if;
  if not public._staff_tiene_seccion(v, p_nivel) then
    raise exception 'Sin permiso sobre el nivel %', p_nivel;
  end if;

  if p_id is not null then
    select * into v_old from alumnos where id = p_id;
    if v_old.id is null then raise exception 'Alumno no encontrado'; end if;
    if not public._staff_tiene_seccion(v, v_old.nivel) then
      raise exception 'Sin permiso sobre el nivel actual del alumno';
    end if;
    update alumnos set
      nombre=p_nombre, nivel=p_nivel, grado=p_grado, tutor=p_tutor, tel=p_tel, email=p_email,
      pago=p_pago, asist=p_asist, foto=coalesce(nullif(p_foto,''), foto), matricula=p_matricula,
      edad=p_edad, anio_cursante=p_anio_cursante, fecha_ingreso=p_fecha_ingreso,
      tutores=coalesce(p_tutores, tutores), historial=coalesce(p_historial, historial),
      documentos=coalesce(p_documentos, documentos),
      curp=coalesce(p_curp, curp), nacimiento=coalesce(p_nacimiento, nacimiento),
      ficha=coalesce(p_ficha, ficha)
    where id = p_id returning * into v_row;
  else
    insert into alumnos (nombre, nivel, grado, tutor, tel, email, pago, asist, foto, matricula,
      edad, anio_cursante, fecha_ingreso, tutores, historial, documentos, curp, nacimiento, ficha)
    values (p_nombre, p_nivel, p_grado, p_tutor, p_tel, p_email, p_pago, p_asist, p_foto, p_matricula,
      p_edad, p_anio_cursante, p_fecha_ingreso, coalesce(p_tutores,'[]'::jsonb), coalesce(p_historial,'{}'::jsonb),
      coalesce(p_documentos,'[]'::jsonb), p_curp, p_nacimiento, coalesce(p_ficha,'{}'::jsonb))
    returning * into v_row;
  end if;
  return v_row;
end $$;
