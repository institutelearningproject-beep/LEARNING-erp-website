-- ============================================================================
--  public_get_config — lectura pública y acotada de la tabla `configuracion`
--  Learning Project Institute (LPI) · proyecto Supabase bvmeunsyhrurigtgpedz
--  Creado: 25 de julio de 2026
-- ============================================================================
--
--  PARA QUÉ ES
--  -----------
--  El sitio público (index.html) necesita leer los números de WhatsApp que el
--  personal edita desde el ERP (Configuración → WhatsApp, clave
--  `whatsapp_canales`). Antes lo hacía con:
--
--      _waSb.from('configuracion').select('valor').eq('clave','whatsapp_canales')
--
--  Eso NUNCA funcionó desde que se cerró RLS: la tabla `configuracion` no tiene
--  política abierta, así que la llave anon recibe cero filas y el código hace
--  `return` en silencio. Resultado: cambiar los números en el ERP no tenía
--  ningún efecto en la página web, sin ningún error visible.
--
--  Esta función lo resuelve sin abrir la tabla: es SECURITY DEFINER, pero solo
--  devuelve claves que estén en la LISTA BLANCA de abajo. Cualquier otra clave
--  devuelve NULL, aunque exista en la tabla.
--
--  CÓMO CORRERLO
--  -------------
--  Supabase → SQL Editor → pegar todo → Run.
--
-- ============================================================================

create or replace function public.public_get_config(p_clave text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_valor text;
begin
  -- LISTA BLANCA: solo estas claves se pueden leer sin autenticación.
  -- No agregues aquí nada que contenga datos de alumnos, correos, teléfonos
  -- de tutores, credenciales ni configuración interna del ERP.
  if p_clave is null or p_clave not in ('whatsapp_canales') then
    return null;
  end if;

  select c.valor into v_valor
  from public.configuracion c
  where c.clave = p_clave
  limit 1;

  return v_valor;
end;
$$;

-- La función es la única puerta: la tabla sigue cerrada.
revoke all on function public.public_get_config(text) from public;
grant execute on function public.public_get_config(text) to anon, authenticated;

comment on function public.public_get_config(text) is
  'Lectura pública acotada de public.configuracion. Solo devuelve claves de la lista blanca (hoy: whatsapp_canales). Usada por index.html con la llave anon.';

-- ============================================================================
--  VERIFICACIÓN — correr después, debe devolver el JSON de los números
-- ============================================================================
-- begin;
--   set role anon;
--   select public.public_get_config('whatsapp_canales');  -- debe devolver el JSON
--   select public.public_get_config('aviso_general');     -- debe devolver NULL
--   select * from public.configuracion;                   -- debe devolver 0 filas
--   reset role;
-- commit;
