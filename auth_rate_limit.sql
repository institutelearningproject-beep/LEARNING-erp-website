-- ─────────────────────────────────────────────────────────────
-- Endurecimiento de login: límite de intentos + bloqueo temporal
-- Aplicado 2026-08-09 vía Supabase MCP (proyecto bvmeunsyhrurigtgpedz)
-- ─────────────────────────────────────────────────────────────
--
-- Qué hace:
--   - Tabla auth_intentos: cuenta intentos fallidos de login por
--     identificador de texto (usuario escrito) y contexto (staff/padres),
--     exista o no la cuenta — así el bloqueo no delata qué usuarios son reales.
--   - Tras 6 intentos fallidos seguidos, bloquea ese identificador 15 minutos.
--   - Un login correcto limpia el contador.
--   - staff_login y portal_login ahora revisan el bloqueo antes de validar
--     la contraseña, y lanzan una excepción con prefijo "LOCKED:" que el
--     front (erp.html / acceso-padres.html) detecta para mostrar el aviso.
--
-- Esto es un snapshot de referencia; la migración real ya está aplicada
-- en Supabase. Ver también: RESUMEN_TECNICO_PARA_IA.md.

create table if not exists public.auth_intentos (
  id bigserial primary key,
  contexto text not null check (contexto in ('staff','padres')),
  identificador text not null,
  intentos integer not null default 0,
  bloqueado_hasta timestamptz,
  ultimo_intento timestamptz not null default now(),
  unique (contexto, identificador)
);

alter table public.auth_intentos enable row level security;
revoke all on public.auth_intentos from anon, authenticated;

create or replace function public._auth_bloqueo_restante(p_contexto text, p_id text)
returns integer
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce((
    select greatest(0, ceil(extract(epoch from (bloqueado_hasta - now())) / 60))::integer
    from auth_intentos
    where contexto = p_contexto and identificador = p_id
      and bloqueado_hasta is not null and bloqueado_hasta > now()
  ), 0);
$$;
revoke all on function public._auth_bloqueo_restante(text, text) from public;

create or replace function public._auth_registrar_resultado(p_contexto text, p_id text, p_exito boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_limite integer := 6;
  v_bloqueo_min integer := 15;
  v_row auth_intentos;
begin
  if p_exito then
    delete from auth_intentos where contexto = p_contexto and identificador = p_id;
    return;
  end if;

  select * into v_row from auth_intentos
    where contexto = p_contexto and identificador = p_id
    for update;

  if v_row.id is null then
    insert into auth_intentos(contexto, identificador, intentos, ultimo_intento)
      values (p_contexto, p_id, 1, now());
    return;
  end if;

  if v_row.bloqueado_hasta is not null and v_row.bloqueado_hasta <= now() then
    update auth_intentos set intentos = 1, bloqueado_hasta = null, ultimo_intento = now()
      where id = v_row.id;
    return;
  end if;

  if v_row.intentos + 1 >= v_limite then
    update auth_intentos
      set intentos = intentos + 1, bloqueado_hasta = now() + (v_bloqueo_min || ' minutes')::interval, ultimo_intento = now()
      where id = v_row.id;
  else
    update auth_intentos set intentos = intentos + 1, ultimo_intento = now()
      where id = v_row.id;
  end if;
end;
$$;
revoke all on function public._auth_registrar_resultado(text, text, boolean) from public;

create or replace function public.staff_login(p_usuario text, p_pass text)
returns table(id integer, usuario text, nombre text, rol text, email text, acceso jsonb, secciones jsonb)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id text := lower(trim(p_usuario));
  v_restante integer;
  v_match boolean;
begin
  v_restante := public._auth_bloqueo_restante('staff', v_id);
  if v_restante > 0 then
    raise exception using message = 'LOCKED:Demasiados intentos. Intenta de nuevo en ' || v_restante || ' minuto(s).';
  end if;

  select exists(
    select 1 from usuarios_sistema u
    where u.usuario ilike p_usuario and u.pass = extensions.crypt(p_pass, u.pass)
  ) into v_match;

  perform public._auth_registrar_resultado('staff', v_id, v_match);

  if not v_match then
    return;
  end if;

  update usuarios_sistema u set last_acceso = now()
    where u.usuario ilike p_usuario and u.pass = extensions.crypt(p_pass, u.pass);

  return query
    select u.id, u.usuario, u.nombre, u.rol, u.email, u.acceso, u.secciones
    from usuarios_sistema u
    where u.usuario ilike p_usuario and u.pass = extensions.crypt(p_pass, u.pass)
    limit 1;
end;
$$;

create or replace function public.portal_login(p_usuario text, p_pass text)
returns table(id integer, nombre text, nivel text, grado text, email text)
language plpgsql
security definer
set search_path to 'public'
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
    select a.id, a.nombre, a.nivel, a.grado, a.email
    from padres_acceso pa join alumnos a on a.id = pa.alumno_id
    where pa.usuario ilike p_usuario and pa.pass = extensions.crypt(p_pass, pa.pass) and pa.activo = true
    limit 1;
end;
$$;

grant execute on function public.staff_login(text, text) to anon, authenticated;
grant execute on function public.portal_login(text, text) to anon, authenticated;
