# Hallazgos de la revisión del código — 25 julio 2026

> ## ESTADO: A, B, D, F y G resueltos en código el mismo 25 de julio
>
> | # | Problema | Estado |
> |---|---|---|
> | A | Token de Vercel en archivos versionables | ✅ Resuelto en código · ⏳ **falta que el dueño rote el token en Vercel** |
> | B | Números de WhatsApp muertos | ✅ Cliente arreglado · ⏳ **falta correr `public_get_config.sql` en Supabase** |
> | C | El ERP de producción no está en git | ⏳ Pendiente — hacer commit (ya es seguro: no quedan secretos en archivos versionables) |
> | D | `typeof scheduleData` en TDZ | ✅ Resuelto (causa raíz eliminada) |
> | E | Contradicción sobre los respaldos | ⏳ Pendiente — requiere ver `cron.job` en Supabase |
> | F | `RESUMEN_PROYECTO_LPI.md` obsoleto | ✅ Resuelto (tabla de correcciones al inicio + notas inline) |
> | G | Basura pesada | ✅ Añadida a `.gitignore` · los archivos siguen en disco (73 MB), borrarlos es decisión del dueño |
>
> **Fuga extra encontrada al verificar:** la contraseña de la cuenta `admin` (que sigue
> vigente) estaba en claro en `RESUMEN_PROYECTO_LPI.md` y en `schema_lpi_completo.sql`.
> Ambas ya están redactadas. Aun así conviene rotarla, porque estuvo en disco sin protección.
>
> **Verificado tras los cambios:** los tres HTML vivos pasan el chequeo de sintaxis;
> `deploy_vercel.js` resuelve el token correctamente; ningún archivo que git subiría
> contiene ya secretos; el frontend vivo tiene **cero** accesos directos a tablas.


Revisión de puesta al día sobre el código real de la carpeta, contrastado contra `RESUMEN_TECNICO_PARA_IA.md` y `RESUMEN_PROYECTO_LPI.md`. No se tocó nada del sistema; esto es solo el diagnóstico para arrancar mañana.

**Limitación de esta revisión:** no hubo acceso al MCP de Supabase en esta sesión, así que todo lo relativo a la base de datos (RLS, funciones, cron de respaldos) está inferido del código cliente, no verificado en vivo.

---

## 1. Lo que sí está confirmado y correcto

| Punto | Evidencia |
|---|---|
| `erp-nuevo.html` no toca ni una tabla directo | 0 ocurrencias de `.from(`; 89 llamadas `rpc()` a 77 funciones `staff_*` distintas |
| `acceso-padres.html` igual de limpio | 0 `.from(`; solo 9 funciones `portal_*` |
| Rutas de `vercel.json` | `/erp` → `erp-nuevo.html`, `/erp-anterior` → `erp.html`, tal como documenta el resumen |
| El fix de `rebuildGrupos()` está en el fuente | `erp-nuevo.html:825` envuelto en `try/catch` |
| El remoto de git ya no lleva token | `.git/config` apunta a la URL limpia del repo |
| `CLAVES_ERP_LPI.txt` está protegido | Cubierto por `.gitignore` |
| El sitio en producción responde | `/erp` sirve el login y el sidebar completo (29 módulos) |

El ERP en producción son 5,308 líneas en un archivo; el portal de padres 425; el sitio público 2,400.

---

## 2. Problemas encontrados (no documentados antes)

### 🔴 A. El token de Vercel está en un archivo que git SÍ subiría
`RESUMEN_PROYECTO_LPI.md` contiene el token de Vercel en claro (sección "Credenciales Vercel"), y ese archivo **no está en `.gitignore`**. Hoy figura como *untracked*, así que un `git add .` seguido de `push` lo publica. El token también vive en `deploy_vercel.js` y `deploy_vercel.ps1`.

Ese token da control total del proyecto de Vercel: quien lo tenga puede desplegar lo que quiera en el dominio del colegio.

**Qué hacer:** rotar el token en Vercel, dejarlo solo en `deploy_vercel.js`, borrarlo del `.md`, y agregar los tres archivos a `.gitignore`. Mejor aún: leerlo de una variable de entorno o de un `vercel_token.txt` ignorado.

### 🔴 B. Los números de WhatsApp editables desde el ERP están muertos en producción
`index.html:2126` lee la tabla `configuracion` **directo con la llave anon**:

```js
_waSb.from('configuracion').select('valor').eq('clave','whatsapp_canales').maybeSingle()
```

Con RLS cerrado en las 28 tablas (como documenta el §7 del resumen técnico), esa consulta devuelve `null`, el código hace `if (!cfg) return;` y el sitio se queda con los números fijos del código. **Falla en silencio** — nadie se entera.

O sea: si alguien cambia los números en Configuración → WhatsApp del ERP, el sitio público los ignora.

**Qué hacer:** crear una función `public_get_config(p_clave)` en Supabase (`SECURITY DEFINER`, que solo devuelva claves de una lista blanca como `whatsapp_canales`) y cambiar `index.html` para llamarla por `rpc()`. Es el único `.from(` que queda en todo el frontend vivo.

### 🟡 C. El ERP de producción nunca se ha commiteado
El repo tiene **un solo commit**, de junio, y `erp-nuevo.html` aparece como *untracked*. También `acceso-padres.html`, `deploy_vercel.js`, `vercel.json`, los `.sql` y ambos resúmenes. El repo de GitHub no es un respaldo real de nada — si se pierde la carpeta local, se pierde el proyecto (salvo lo que esté vivo en Vercel).

**Qué hacer:** después de arreglar (A), hacer un commit real con todo lo que sí debe versionarse.

### 🟡 D. El guardia `typeof scheduleData` dentro de `rebuildGrupos()` no funciona
Dentro de la función (línea 811):

```js
Object.keys(typeof scheduleData!=='undefined'?scheduleData:{})
```

`scheduleData` es `const` declarado en la línea 3085. Para variables `let`/`const` en zona muerta temporal (TDZ), `typeof` **también lanza** `ReferenceError` — no devuelve `'undefined'` como pasaría con `var`. Es una particularidad conocida de JavaScript.

Consecuencia: en la llamada temprana de la línea 825 solo el `try/catch` evita el crash; el `typeof` no aporta nada. Funciona, pero el catálogo de grupos arranca con los grupos demo de `GRUPOS_BASE` hasta que el login vuelve a llamar `rebuildGrupos()` en la línea 692. Aceptable, pero la solución limpia es mover `const scheduleData = {}` arriba de la línea 804.

### 🟡 E. Contradicción sobre los respaldos automáticos
- `RESUMEN_PROYECTO_LPI.md` dice: `respaldo_diario()` corre **diario** a las 08:00 UTC, retención **14 días**.
- `RESUMEN_TECNICO_PARA_IA.md` dice: respaldo **mensual**, retención **395 días**.

Alguien de los dos está mal. Hay que mirar `cron.job` en Supabase y corregir el documento equivocado.

### 🟢 F. `RESUMEN_PROYECTO_LPI.md` tiene datos obsoletos
Sigue diciendo que el ERP es `erp.html`, que el login es `admin`/`1234`, que las contraseñas están en texto plano, que las tablas tienen políticas abiertas (`acceso_total`), y en la tabla de links apunta al proyecto de Supabase equivocado (`ujwmuuwdmwqcnracqnzg` en vez de `bvmeunsyhrurigtgpedz`). Todo eso ya cambió. La cabecera de julio sí está al día, pero el cuerpo del documento no — es fácil que alguien lea la parte vieja y actúe sobre información falsa.

### 🟢 G. Basura pesada en la carpeta
~73 MB entre `LPI-hostinger.zip` (24M), `zitGz9GO` (24M, archivo sin extensión), `LPI-sitio.zip` (13M), `LPI-part1/2.zip` (12M) y un `.fuse_hidden...` (240K). Todos son respaldos de la época de Hostinger, ya irrelevantes. Los `.zip` sí están en `.gitignore`; `zitGz9GO` no.

---

## 3. Pendientes previos que siguen abiertos

1. **Verificar en vivo el fix de `rebuildGrupos`** (§10 del resumen técnico) — está en el fuente, falta confirmar que el deploy ya subió y que la consola del navegador está limpia.
2. Confirmar que el repo de GitHub quedó privado y el token viejo de GitHub revocado (§8).
3. Confirmación de lectura de comunicados — la tabla `comunicados_lecturas` existe, bloqueada y sin función ni UI.
4. Módulo de reglamento interno — nunca se construyó.
5. Cuentas individuales por persona en vez de las 13 genéricas por área.
6. Dominio propio (hoy `.vercel.app`).
7. API real de timbrado CFDI (hoy el staff sube el XML/PDF a mano desde Aspel).
8. Cuota de EmailJS: 200 correos/mes en plan gratuito, compartida por credenciales, calificaciones, asistencia, horarios, avisos, facturas y recordatorios de pago. Vigilar si crece la matrícula.

---

## 4. Orden sugerido para mañana

1. **B** — arreglar los números de WhatsApp (bug funcional real que afecta al sitio público).
2. **A** — rotar el token de Vercel y sacarlo del `.md`.
3. **§10** — verificar el ERP en vivo con la consola del navegador.
4. **C** — commit real del proyecto.
5. **E / F** — reconciliar los dos documentos con la realidad.
6. **D / G** — limpieza (bajo riesgo, se puede hacer en cualquier momento).
