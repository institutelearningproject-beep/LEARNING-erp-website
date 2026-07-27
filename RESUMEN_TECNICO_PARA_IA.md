# Resumen técnico del proyecto — Learning Project Institute (LPI)
**Generado:** 22 de julio de 2026 — para que otra IA (o desarrollador) retome el proyecto sin perder contexto.

---

## 1. Qué es esto

Sitio web público + ERP administrativo completo para **Learning Project Institute (LPI)**, un colegio bilingüe (Maternal, Preescolar, Primaria y Secundaria, con programa Cambridge) ubicado en Metepec, Estado de México. Es un proyecto de un solo "tenant" (un colegio), no un SaaS multi-cliente.

Dos partes:
- **Sitio web público** (`index.html`): informativo, para atraer inscripciones.
- **ERP interno** (`erp-nuevo.html`, servido en `/erp`): sistema de gestión escolar completo para el personal (alumnos, calificaciones, asistencia, pagos, facturación, comunicados, etc.), con un **portal de padres** (`acceso-padres.html`) donde cada familia consulta calificaciones/asistencia/avisos/facturas de su hijo.

---

## 2. Ubicación en disco (máquina del usuario)

```
C:\Users\yacil\Claude\Projects\Learning Project
```

Todo el código fuente, scripts de despliegue, contratos y respaldos SQL viven ahí. No hay build step: son archivos HTML/JS/CSS planos, servidos tal cual.

---

## 3. Dónde está alojado / arquitectura

| Componente | Dónde vive | Notas |
|---|---|---|
| Frontend (HTML/JS estático) | **Vercel** — proyecto `institutelearningproject-project` | Deploy manual vía script propio, NO vía Git push / integración automática de Vercel. |
| Backend / base de datos | **Supabase** — proyecto `LPI-COLEGIO`, ref `bvmeunsyhrurigtgpedz` | Postgres + PostgREST (API REST auto-generada) + pg_cron (respaldos) + pgcrypto (hash de contraseñas). |
| Código fuente / control de versiones | **GitHub** — `institutelearningproject-beep/LEARNING-erp-website` | Repo puesto en privado (a petición del dueño, ver §8). Solo contiene 4 archivos históricos (README, erp.html viejo, index.html, supabase_schema.sql) — **no** es la fuente real del deploy. |
| URL pública | `https://institutelearningproject-project.vercel.app` | Dominio propio aún no configurado (pendiente). |

**Importante:** Vercel NO redepliega automáticamente al hacer `git push`. El deploy real ocurre corriendo `DEPLOY LPI.bat` (Windows) en la máquina del usuario, que ejecuta `deploy_vercel.js` (Node.js) usando la API REST de Vercel directamente con un token hardcodeado en ese archivo. Sube el contenido completo de los archivos en cada corrida (no incremental).

---

## 4. Rutas / URLs del sitio (definidas en `vercel.json`)

| Ruta | Archivo servido | Qué es |
|---|---|---|
| `/` | `index.html` | Sitio público del colegio |
| `/erp` | `erp-nuevo.html` | **ERP en producción (el que usa el colegio hoy)** |
| `/erp-nuevo` | `erp-nuevo.html` | Alias del mismo archivo |
| `/erp-anterior` | `erp.html` | ERP viejo, **congelado como referencia histórica** — ya no tiene acceso funcional a las tablas principales (ver §7), no se debe usar para operar el colegio |
| `/inscripciones-secundaria` | `inscripciones-secundaria.html` | Formulario simple de preinscripción a secundaria (no toca Supabase directo) |
| (portal de padres) | `acceso-padres.html` | No tiene ruta corta propia; se accede por su nombre de archivo directo |

---

## 5. Archivos clave en la carpeta del proyecto

```
erp-nuevo.html            ← ERP EN VIVO (/erp). ~389 KB, un solo archivo con todo el JS inline.
erp.html                  ← ERP viejo, congelado (/erp-anterior).
erp_anterior_20260630.html, erp_anterior_20260714.html  ← snapshots de respaldo históricos, no en uso.
index.html                ← Sitio web público del colegio.
acceso-padres.html        ← Portal de padres (PWA, con service worker sw.js).
inscripciones-secundaria.html ← Formulario público de preinscripción.
sw.js, manifest.json      ← Service worker / PWA del portal de padres.
vercel.json               ← Mapeo de rutas (ver §4).
deploy_vercel.js          ← Script de deploy real (usa API REST de Vercel, token hardcodeado).
deploy_vercel.ps1         ← Versión antigua en PowerShell (no usar, usar el .js).
DEPLOY LPI.bat            ← Doble clic para desplegar (corre deploy_vercel.js).
subir_github.bat, subir_vercel.bat ← Scripts antiguos, probablemente obsoletos.
CLAVES_ERP_LPI.txt        ← Contraseñas en claro de las 13 cuentas de personal (ÚNICA copia legible; en Supabase están hasheadas). NO subir a GitHub (está en .gitignore).
RESUMEN_PROYECTO_LPI.md   ← Bitácora funcional del proyecto (features, historial de decisiones).
RESUMEN_TECNICO_PARA_IA.md ← Este archivo.
supabase_schema.sql, schema_lpi_completo.sql, *.sql sueltos ← Snapshots/migraciones antiguas del esquema, para referencia; la fuente de verdad real es la base de datos en vivo en Supabase, no estos archivos.
fotos/                    ← ~70 imágenes usadas por el sitio público.
Contrato_ERP_LearningProject*.docx/.pdf ← Contrato comercial del proyecto con el colegio.
```

Archivos `.zip` sueltos (`LPI-*.zip`) son respaldos antiguos de hosting (Hostinger), ya no relevantes al flujo actual (Vercel).

---

## 6. Stack técnico

- **Frontend:** HTML + JavaScript vanilla (sin framework, sin build step). Un solo `<script>` inline gigante por archivo. CSS inline en `<style>`.
- **Cliente de base de datos:** `supabase-js` cargado por CDN, inicializado con la URL del proyecto y la **llave pública "anon"** (visible en el código fuente del cliente — esto es normal/esperado en Supabase, la seguridad real vive en RLS + funciones del lado servidor, ver §7).
- **Backend:** Supabase (Postgres 15 gestionado). Sin servidor propio: toda la lógica de negocio vive en **funciones SQL `SECURITY DEFINER`** llamadas vía `supabase.rpc(...)` desde el cliente.
- **Autenticación:** NO usa Supabase Auth. Es un login propio: tabla `usuarios_sistema` (personal) y `padres_acceso` (un usuario/contraseña por alumno para el portal de padres), con contraseñas hasheadas con bcrypt (`pgcrypto`).
- **Cron:** `pg_cron` corre un respaldo mensual completo de la base de datos (`respaldo_diario()`, guardado en tabla `respaldos_bd`, retención 395 días).
- **Emails:** EmailJS (SDK del lado cliente) para enviar credenciales del portal de padres y notificaciones (calificaciones nuevas, facturas listas, etc.). Usa una "public key" (no es secreta por diseño).
- **WhatsApp:** enlaces `wa.me` generados en el cliente (sin API de WhatsApp Business, es solo abrir un chat prellenado).
- **Facturación:** el ERP **no** tima ni conecta con el SAT/Aspel directamente. El flujo real es: se genera el CFDI en el sistema Aspel de la escuela (fuera de este proyecto), y el personal **sube manualmente** el folio fiscal/XML/PDF ya timbrados al ERP (`staff_timbrar_factura`), que entonces lo hace visible al padre en su portal.

---

## 7. Modelo de seguridad de la base de datos (MUY IMPORTANTE)

Esto fue objeto de un trabajo extenso de hardening en julio 2026. El diseño final:

1. **RLS (Row Level Security) está activo en las 28 tablas de `public`, y NINGUNA tiene política abierta.** Es decir, con la llave "anon" (pública, la que está en el código del sitio) nadie puede leer ni escribir ninguna tabla directamente vía la API REST de Supabase. Verificado con `SET ROLE anon` + advisors de seguridad de Supabase (0 hallazgos de "rls_policy_always_true").
2. **Todo el acceso real pasa por ~96 funciones `SECURITY DEFINER`** en el esquema `public`, con estas familias de nombres:
   - `staff_login`, `staff_guardar_usuario`, `staff_eliminar_usuario`, `staff_listar_usuarios` → gestión de cuentas de personal (solo admin puede crear/editar/ver la lista completa).
   - `staff_listar_*` / `staff_guardar_*` / `staff_eliminar_*` → una función por tabla operativa (alumnos, pagos, facturas, calificaciones, asistencia, horarios, maestros, comunicados, incidencias, eventos, inscripciones, bajas, nómina, tareas, materias, Cambridge, evaluaciones cualitativas, bitácora, personal, biblioteca, talleres, inventario, acceso de padres, configuración genérica).
   - `portal_*` → usadas por el portal de padres (`portal_login`, `portal_calificaciones`, `portal_asistencia`, `portal_horario`, `portal_avisos`, `portal_calendario`, `portal_facturas`, `portal_solicitar_factura`, `portal_descargar_factura`).
   - `_staff_valida`, `_staff_tiene_acceso`, `_staff_tiene_seccion`, `_grupo_a_nivel`, `_config_puede_leer`, `_config_puede_escribir` → helpers internos (no invocables directo desde el cliente, `REVOKE`d de `anon`/`authenticated`).
3. **Patrón de cada función:** recibe `p_usuario` + `p_pass` (contraseña en claro) en cada llamada, revalida contra el hash bcrypt guardado, revisa el permiso del rol (módulo `acceso` + nivel/sección `secciones`) y solo entonces lee/escribe. El navegador nunca ve un hash ni compara contraseñas — todo se revalida en el servidor en cada acción.
4. **Filtrado por rol:**
   - `acceso` (array de "módulos", ej. `alumnos`, `calificaciones`, `facturacion`, `pagos`, `nomina`) controla qué puede **escribir/eliminar** cada rol.
   - `secciones` (array de niveles: `Maternal`, `Preescolar`, `Primaria`, `Secundaria`, o `["__all__"]`) controla qué alumnos/datos puede **ver**.
   - Excepción de diseño: la **lectura** de `alumnos`, `maestros`, `materias` y `eventos_calendario` NO exige el módulo específico (solo la sección/nivel), porque muchos roles necesitan ver esos catálogos aunque no tengan permiso de editarlos (ej. Facturación necesita ver la lista de alumnos para emitir una factura, aunque no tenga el módulo "alumnos").
5. **Tablas huérfanas bloqueadas sin reemplazo:** `claves_padres` (función vieja de "claves de boleta" que solo usaba `erp.html`, nunca se portó al ERP nuevo) y `comunicados_lecturas` (tabla creada para "confirmación de lectura" de avisos, pero nunca se conectó a ninguna UI). Ambas están con RLS cerrado y sin función — si se quieren reactivar, hay que diseñar las funciones seguras primero.
6. **`erp.html` (el ERP viejo, `/erp-anterior`) quedó roto a propósito** para las tablas principales (alumnos, pagos, facturas, usuarios) porque nunca se actualizó para usar las funciones seguras — sigue intentando leer las tablas directo, y ahora eso da 0 resultados. Es solo un respaldo congelado, no se debe usar operativamente.

### Las 13 cuentas de personal (por área, no por nombre de persona)
Ver `CLAVES_ERP_LPI.txt` para las contraseñas reales. Resumen de roles: `admin` y `amaury` (acceso total), `directora.maternal`, `coordinadora.maternal`, `miss.maternal`, `miss.preescolar`, `directora.primaria`, `coordinadora.primaria`, `miss.primaria`, `miss.secundaria`, `admin.facturacion`, `admin.inscripciones`, `admin.comunicacion`. Solo `admin`/`amaury` pueden crear, editar o eliminar cuentas (vía `staff_guardar_usuario` / `staff_eliminar_usuario`, que exigen credenciales de administrador).

---

## 8. Estado de GitHub

El repo público tenía un token de acceso personal expuesto en la URL del remoto local; se limpió (`git remote set-url` sin el token). **Pendiente confirmar con el usuario** si ya: (a) revocó ese token viejo desde GitHub → Settings → Developer settings → Personal access tokens, y (b) puso el repositorio en privado desde Settings → Danger Zone. Esto se le indicó pero no se verificó que lo haya ejecutado.

---

## 9. Cómo desplegar un cambio

1. Editar el/los archivo(s) `.html` directamente en `C:\Users\yacil\Claude\Projects\Learning Project`.
2. Correr `DEPLOY LPI.bat` (doble clic, en Windows, con Node.js instalado).
3. El script sube TODO el contenido de `index.html`, `erp.html`, `erp-nuevo.html`, `inscripciones-secundaria.html`, `acceso-padres.html`, `vercel.json`, `manifest.json`, `sw.js` y las fotos, y crea un deployment nuevo de producción en Vercel vía su API REST directa (no usa `vercel` CLI ni integración Git).
4. El portal de padres tiene un **service worker** (`sw.js`) que cachea agresivamente (cache-first) — después de desplegar, a veces hace falta recargar dos veces o hacer hard-refresh para ver cambios en ese cliente.

Cambios en la base de datos (tablas, funciones, políticas RLS) se hacen directo en el proyecto de Supabase (`bvmeunsyhrurigtgpedz`) vía migraciones SQL — no requieren ni pasan por el deploy de Vercel.

---

## 10. Problema conocido recién corregido (verificar tras el próximo deploy)

Había un bug de JavaScript **pre-existente** (de antes del trabajo de seguridad, introducido cuando `scheduleData` pasó de `var` a `const`/`let` en una reescritura previa del módulo de Horarios): una llamada `rebuildGrupos()` se ejecutaba al cargar la página, ANTES de que `scheduleData` estuviera inicializada, lo que lanzaba un `ReferenceError` no capturado que **detenía la ejecución de todo el resto del script** (cientos de variables/funciones declaradas después de esa línea quedaban permanentemente inutilizables — por eso no aparecían usuarios, alumnos, ni funcionaba `openWindow()` para abrir módulos). Se corrigió envolviendo esa llamada en `try/catch`. Falta confirmar en vivo, con el navegador, que tras el último deploy ya no ocurre (el usuario iba a correr `DEPLOY LPI.bat` de nuevo).

---

## 11. Pendientes / ideas no implementadas (mencionadas por el dueño en algún momento)

- Cuentas de personal **individuales con nombre** (hoy son 13 cuentas genéricas por área/rol, no por persona) — se puede hacer desde Configuración → Usuarios y Roles eligiendo la plantilla del rol.
- Módulo de **"reglamento interno"** (mencionado en la especificación original, nunca se construyó).
- Confirmación de lectura de comunicados en el portal de padres (tabla `comunicados_lecturas` existe pero no está conectada a ninguna UI).
- Dominio propio para el sitio (hoy usa el subdominio `.vercel.app`).
- Repo de GitHub: confirmar que quedó privado y el token viejo revocado (§8).

---

## 12. Para pruebas / desarrollo

- El proyecto de Supabase se puede inspeccionar y modificar vía el MCP de Supabase (ID de proyecto `bvmeunsyhrurigtgpedz`).
- Para simular una llamada como la haría el navegador (con la llave "anon", respetando RLS) desde el editor SQL de Supabase: `begin; set role anon; select ...; reset role; commit;`.
- No hay entorno de "staging": `/erp` es producción real. Los cambios se prueban insertando/borrando filas de prueba directo en la base (con prefijo `ZZ_PRUEBA_` se usó como convención en este proyecto) y limpiándolas después, o abriendo el sitio en vivo.
