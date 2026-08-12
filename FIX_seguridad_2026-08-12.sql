-- ═══════════════════════════════════════════════════════════════════════
--  LEARNING PROJECT INSTITUTE — CORRECCIONES DE SEGURIDAD
--  Auditoría del 12 de agosto de 2026 · Proyecto Supabase bvmeunsyhrurigtgpedz
--
--  Ejecutar en: Supabase → SQL Editor → New query → Pegar → Run
--  Las fases están separadas a propósito. Corre FASE 1 primero y prueba
--  el ERP y el portal de padres antes de seguir con la FASE 2.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  FASE 1 — URGENTE. Riesgo de romper algo: prácticamente nulo.
--
--  Quita de la API pública 5 funciones internas que hoy cualquiera puede
--  invocar con la clave anon (que es pública y está en el código del sitio).
--  Ninguna de las 5 la llama el navegador: las usan pg_cron o el propio
--  motor por dentro, y esas rutas NO pasan por los permisos de anon.
-- ───────────────────────────────────────────────────────────────────────
BEGIN;

-- (1) Permitía BORRAR el bloqueo por intentos fallidos desde el navegador.
--     Verificado en la auditoría: 15 min de bloqueo → 0 min con una llamada.
REVOKE EXECUTE ON FUNCTION public._auth_registrar_resultado(text, text, boolean)
  FROM anon, authenticated, public;

-- (2) Permitía sondear qué cuentas están bloqueadas (enumeración de usuarios).
REVOKE EXECUTE ON FUNCTION public._auth_bloqueo_restante(text, text)
  FROM anon, authenticated, public;

-- (3) Permitía disparar un volcado COMPLETO de la base (alumnos, pagos,
--     nómina, hashes, accesos de padres) dentro de respaldos_bd, sin límite
--     de veces. La sigue llamando pg_cron como postgres, sin cambios.
REVOKE EXECUTE ON FUNCTION public.respaldo_diario()
  FROM anon, authenticated, public;

-- (4) Permitía disparar correos reales a los padres (15 por llamada) y
--     quemar la cuota de EmailJS. La sigue llamando pg_cron, sin cambios.
REVOKE EXECUTE ON FUNCTION public.enviar_recordatorios_pago()
  FROM anon, authenticated, public;

-- (5) Función de trigger; no tiene por qué ser invocable desde fuera.
REVOKE EXECUTE ON FUNCTION public.hash_pass_col()
  FROM anon, authenticated, public;

-- (6) Validadores internos de credenciales: solo deben usarse desde dentro
--     de otras funciones SECURITY DEFINER, nunca directamente desde la API.
REVOKE EXECUTE ON FUNCTION public._staff_valida(text, text)
  FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public._portal_alumno(text, text)
  FROM anon, authenticated, public;

COMMIT;

-- Comprobación: las 7 deben desaparecer de este listado.
SELECT p.proname AS "sigue expuesta a anon"
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
WHERE has_function_privilege('anon', p.oid, 'EXECUTE')
  AND p.proname IN ('_auth_registrar_resultado','_auth_bloqueo_restante',
                    'respaldo_diario','enviar_recordatorios_pago',
                    'hash_pass_col','_staff_valida','_portal_alumno');
-- Resultado esperado: 0 filas.


-- ───────────────────────────────────────────────────────────────────────
--  FASE 2 — Endurecer el hash de contraseñas (bcrypt coste 6 → 12).
--
--  Hoy las 27 cuentas (13 de personal + 14 de padres) usan coste 6, que es
--  el valor por defecto de pgcrypto y es MUY bajo: cada intento de
--  contraseña es unas 64 veces más rápido de probar que con coste 12.
--
--  Esto solo afecta a las contraseñas que se guarden DESPUÉS de correrlo.
--  Las 27 actuales siguen en coste 6 hasta que cada quien cambie su clave.
--  Ver la nota al final sobre cómo re-hashear las existentes.
-- ───────────────────────────────────────────────────────────────────────
BEGIN;

CREATE OR REPLACE FUNCTION public.hash_pass_col()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if new.pass is not null and new.pass <> '' and new.pass not like '$2%' then
    -- coste 12 en vez del 6 por defecto
    new.pass := extensions.crypt(new.pass, extensions.gen_salt('bf', 12));
  end if;
  return new;
end $function$;

REVOKE EXECUTE ON FUNCTION public.hash_pass_col() FROM anon, authenticated, public;

COMMIT;


-- ───────────────────────────────────────────────────────────────────────
--  FASE 3 — Límite de intentos en TODAS las funciones, no solo en el login.
--
--  PROBLEMA: hoy el bloqueo por intentos fallidos solo existe en
--  staff_login y portal_login. Las otras 129 funciones (portal_resumen,
--  staff_listar_alumnos, etc.) reciben usuario+contraseña y las revalidan,
--  pero NO cuentan los fallos. Verificado en la auditoría: 25 intentos
--  seguidos contra portal_resumen, cero registros de bloqueo.
--  O sea: el candado de la puerta principal no sirve, porque hay 129
--  ventanas abiertas que aceptan la misma llave.
--
--  POR QUÉ NO ES UN PARCHE DE UNA LÍNEA: cuando la validación falla, la
--  función lanza una excepción. En Postgres una excepción revierte TODA la
--  transacción — incluido el "+1" que acabamos de anotar en el contador.
--  Por eso staff_login no lanza excepción en el fallo, sino que devuelve
--  vacío. Para contar fallos en funciones que SÍ deben lanzar excepción
--  hace falta una transacción autónoma, y eso en Postgres se consigue con
--  dblink (una conexión aparte que hace commit por su cuenta).
--
--  ⚠ Esta fase toca los dos validadores que usan 118 funciones. Pruébala
--    fuera de horario y ten a la mano el bloque de reversión del final.
-- ───────────────────────────────────────────────────────────────────────

-- 3.1 — Habilitar dblink (transacciones autónomas)
CREATE EXTENSION IF NOT EXISTS dblink SCHEMA extensions;

-- 3.2 — Registrar un intento fallido en su PROPIA transacción, de modo que
--       sobreviva al rollback que provoca la excepción de credenciales.
CREATE OR REPLACE FUNCTION public._auth_fallo_autonomo(p_contexto text, p_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  perform extensions.dblink(
    'dbname=' || current_database(),
    format('select public._auth_registrar_resultado(%L, %L, false)', p_contexto, p_id)
  );
exception when others then
  -- Si dblink falla, NO bloqueamos al usuario legítimo: solo no se cuenta.
  null;
end $function$;

REVOKE EXECUTE ON FUNCTION public._auth_fallo_autonomo(text, text)
  FROM anon, authenticated, public;

-- 3.3 — Validador del personal, ahora con bloqueo por intentos
CREATE OR REPLACE FUNCTION public._staff_valida(p_usuario text, p_pass text)
RETURNS usuarios_sistema
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v usuarios_sistema;
  v_id text := lower(trim(coalesce(p_usuario, '')));
  v_restante integer;
begin
  v_restante := public._auth_bloqueo_restante('staff', v_id);
  if v_restante > 0 then
    raise exception using message =
      'LOCKED:Demasiados intentos. Intenta de nuevo en ' || v_restante || ' minuto(s).';
  end if;

  select * into v from usuarios_sistema u
   where u.usuario ilike p_usuario
     and u.pass = extensions.crypt(p_pass, u.pass);

  if v.id is null then
    perform public._auth_fallo_autonomo('staff', v_id);
    raise exception 'Credenciales inválidas';
  end if;

  -- Éxito: limpiar el contador solo si existe, para no escribir en cada llamada
  if exists (select 1 from auth_intentos
              where contexto = 'staff' and identificador = v_id) then
    perform public._auth_registrar_resultado('staff', v_id, true);
  end if;

  return v;
end $function$;

REVOKE EXECUTE ON FUNCTION public._staff_valida(text, text)
  FROM anon, authenticated, public;

-- 3.4 — Validador del portal de padres, ahora con bloqueo por intentos.
--       Conserva el comportamiento original (devuelve NULL si no coincide)
--       para no romper a las 8 funciones que la usan.
CREATE OR REPLACE FUNCTION public._portal_alumno(p_usuario text, p_pass text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_alumno integer;
  v_id text := lower(trim(coalesce(p_usuario, '')));
  v_restante integer;
begin
  v_restante := public._auth_bloqueo_restante('padres', v_id);
  if v_restante > 0 then
    raise exception using message =
      'LOCKED:Demasiados intentos. Intenta de nuevo en ' || v_restante || ' minuto(s).';
  end if;

  select pa.alumno_id into v_alumno
    from padres_acceso pa
   where pa.usuario ilike p_usuario
     and pa.pass = extensions.crypt(p_pass, pa.pass)
     and pa.activo = true
   limit 1;

  if v_alumno is null then
    perform public._auth_fallo_autonomo('padres', v_id);
    return null;   -- mismo contrato que la versión anterior
  end if;

  if exists (select 1 from auth_intentos
              where contexto = 'padres' and identificador = v_id) then
    perform public._auth_registrar_resultado('padres', v_id, true);
  end if;

  return v_alumno;
end $function$;

REVOKE EXECUTE ON FUNCTION public._portal_alumno(text, text)
  FROM anon, authenticated, public;


-- ───────────────────────────────────────────────────────────────────────
--  QUÉ PROBAR DESPUÉS DE LA FASE 3
-- ───────────────────────────────────────────────────────────────────────
--  1. Entrar al ERP con una cuenta real y abrir 3 o 4 módulos distintos
--     (alumnos, pagos, calificaciones). Deben cargar normal.
--  2. Entrar al portal de padres con un usuario real y ver calificaciones.
--  3. Fallar 6 veces la contraseña a propósito con un usuario de prueba:
--     debe aparecer el aviso de bloqueo y NO dejar seguir intentando.
--  4. Esperar 15 min (o limpiar la fila a mano) y confirmar que vuelve a entrar.


-- ───────────────────────────────────────────────────────────────────────
--  REVERSIÓN de la FASE 3, por si algo se rompe
-- ───────────────────────────────────────────────────────────────────────
/*
CREATE OR REPLACE FUNCTION public._staff_valida(p_usuario text, p_pass text)
RETURNS usuarios_sistema LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $f$
declare v usuarios_sistema;
begin
  select * into v from usuarios_sistema u
    where u.usuario ilike p_usuario and u.pass = extensions.crypt(p_pass, u.pass);
  if v.id is null then raise exception 'Credenciales inválidas'; end if;
  return v;
end $f$;
REVOKE EXECUTE ON FUNCTION public._staff_valida(text,text) FROM anon, authenticated, public;

CREATE OR REPLACE FUNCTION public._portal_alumno(p_usuario text, p_pass text)
RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $f$
  SELECT pa.alumno_id FROM padres_acceso pa
   WHERE pa.usuario ILIKE p_usuario
     AND pa.pass = extensions.crypt(p_pass, pa.pass)
     AND pa.activo = true
   LIMIT 1;
$f$;
REVOKE EXECUTE ON FUNCTION public._portal_alumno(text,text) FROM anon, authenticated, public;
*/


-- ───────────────────────────────────────────────────────────────────────
--  NOTA — Re-hashear las 27 contraseñas actuales a coste 12
--
--  No se puede hacer automáticamente: bcrypt es de una sola vía, y para
--  re-hashear hace falta la contraseña en claro. Las tienes en
--  CLAVES_ERP_LPI.txt (que está bien puesto en .gitignore). Con eso:
--
--     UPDATE usuarios_sistema
--        SET pass = extensions.crypt('<contraseña en claro>', extensions.gen_salt('bf', 12))
--      WHERE usuario = '<usuario>';
--
--  Ojo: el trigger hash_pass_col no re-hashea valores que ya empiezan con
--  '$2', por eso aquí se pasa el hash ya calculado. Comprobar después con:
--
--     SELECT usuario, split_part(pass,'$',3) AS coste FROM usuarios_sistema;
--
--  Y aprovechar para cambiar las claves, ya que el repositorio fue público
--  durante meses y conviene rotar por precaución.
-- ───────────────────────────────────────────────────────────────────────
