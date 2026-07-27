# 📋 RESUMEN COMPLETO — Learning Project Institute (LPI)
> Bitácora histórica del proyecto · Última revisión: 25 de julio de 2026

> ## ⚠️ LEE ESTO ANTES DE USAR EL DOCUMENTO
> Este archivo es una **bitácora acumulada**: mezcla el estado actual con decisiones que ya
> fueron superadas. Las secciones de junio 2026 describen un sistema que **ya no existe**.
> Para el estado real y vigente, la fuente de verdad es **`RESUMEN_TECNICO_PARA_IA.md`**;
> para bugs y riesgos abiertos, **`HALLAZGOS_2026-07-25.md`**.
>
> Correcciones rápidas de lo que este documento dice mal más abajo:
>
> | Dice el documento (junio) | Realidad (julio 2026) |
> |---|---|
> | El ERP es `erp.html` | El ERP en producción es **`erp-nuevo.html`** (`/erp`). `erp.html` está congelado en `/erp-anterior` y **roto a propósito**. |
> | Login `admin` / `1234` | Falso desde julio. 13 cuentas por área con contraseñas bcrypt; ver `CLAVES_ERP_LPI.txt`. |
> | Contraseñas en texto plano | Falso. Todo con bcrypt (`pgcrypto`), staff y padres. |
> | Tablas con políticas abiertas (`acceso_total`) | Falso. **RLS cerrado en las 28 tablas**, sin ninguna política abierta. Todo el acceso pasa por ~96 funciones `SECURITY DEFINER`. |
> | Los permisos son "solo de interfaz" | Falso. El filtrado por módulo y por sección se revalida **en el servidor** en cada llamada. |
> | Proyecto Supabase `ujwmuuwdmwqcnracqnzg` | El real es **`bvmeunsyhrurigtgpedz`**. |

## ⚡ ACTUALIZACIÓN JULIO 2026 — ERP v2 EN PRODUCCIÓN
- **ERP reestructurado (erp-nuevo.html) es ahora el sistema oficial en `/erp`** (vercel.json apunta /erp → erp-nuevo.html). El anterior quedó guardado en `erp_anterior_20260714.html` y accesible en `/erp-anterior` (erp.html).
- **Seguridad**: contraseñas staff y padres cifradas con bcrypt (pgcrypto + triggers), login vía RPC `staff_login`, puerta trasera de la cuenta `admin` eliminada, alta/edición/borrado de usuarios solo vía `staff_guardar_usuario`/`staff_eliminar_usuario` (exigen credenciales de admin con acceso total); tabla usuarios_sistema en solo-lectura para la anon key. Claves actuales en `CLAVES_ERP_LPI.txt` (en .gitignore).
- **RBAC**: 12 plantillas de rol (matriz oficial: Director General, Directora Mat/Pre, Coordinadora Maternal, Miss Maternal/Preescolar/Primaria/Secundaria, Coordinadora Primaria, Directora Pri/Sec + 3 admin). Selector de nivel en topbar para roles multi-nivel; colores + ositos por nivel.
- **Módulos nuevos** (tablas Supabase reales): tareas + tareas_cumplimiento, materias, cambridge_seguimiento, evaluaciones_cualitativas (preescolar), bitacora_comunicacion (reporte diario maternal), comunicados_lecturas, personal, biblioteca, talleres, inventario.
- **Sin demos**: grupos derivados de alumnos reales (rebuildGrupos), horarios por grupo (scheduleData[grupo]), calificaciones se cargan/guardan reales por grupo+periodo (materias dinámicas del catálogo), kardex/certificados usan calificaciones reales (se eliminó la fórmula falsa y la "Lic. Patricia Núñez"), ciclo escolar editable en Estructura Académica (configuracion.ciclo_escolar), aulas usan el catálogo de Configuración.
- **Pendientes**: confirmación de lectura de comunicados en el portal de padres (tabla lista, falta botón), módulo de reglamento interno, crear cuentas individuales del personal (plantillas listas), token de GitHub expuesto en .git/config (rotar).

---

## 🏫 ¿QUÉ ESTAMOS CONSTRUYENDO?

**Dos productos para Learning Project Institute**, un colegio bilingüe K–9 (Maternal a Secundaria) en Metepec, Estado de México, con certificación Cambridge:

| Producto | Archivo | URL |
|---|---|---|
| Página web institucional | `index.html` | https://institutelearningproject-project.vercel.app |
| Portal ERP administrativo | `erp.html` | https://institutelearningproject-project.vercel.app/erp |
| Página inscripciones secundaria | `inscripciones-secundaria.html` | https://institutelearningproject-project.vercel.app/inscripciones-secundaria |

---

## 📁 ARCHIVOS DEL PROYECTO

Todos en: `C:\Users\yacil\Claude\Projects\Learning Project\`

```
Learning Project/
├── index.html                      ← Página web principal
├── erp.html                        ← Sistema ERP administrativo
├── acceso-padres.html              ← Portal de padres (pestaña aparte, aislada de index.html)
├── inscripciones-secundaria.html   ← Página pre-inscripciones secundaria
├── manifest.json                   ← Manifest PWA del portal de padres
├── sw.js                           ← Service worker del portal de padres (cascarón offline)
├── deploy_vercel.js                ← Script de despliegue a Vercel
├── vercel.json                     ← Configuración de rutas Vercel
├── DEPLOY LPI.bat                  ← Doble clic para publicar todo
└── fotos/                          ← Fotos de la escuela (de Facebook)
    ├── slider-1.jpg ... slider-N.jpg   (galería y hero)
    ├── nosotros-1.jpg, nosotros-2.jpg
    ├── nivel-maternal.jpg, nivel-preescolar.jpg
    ├── nivel-primaria.jpg, nivel-secundaria.jpg
    ├── cambridge.jpg
    ├── programa-robotica.jpg, programa-mun.jpg, programa-nasa.jpg
```

### ¿Cómo se ordenan las fotos?
Las fotos de Facebook se nombran cronológicamente. El script las ordena `sort().reverse()` (más recientes primero) y salta las primeras 5 (`.slice(5)`) porque no gustaron. Las demás se convierten en `slider-1.jpg`, `slider-2.jpg`, etc.

---

## 🚀 CÓMO SE DESPLIEGA (Vercel)

### Método: Vercel REST API (dos pasos)
El `.bat` simplemente ejecuta: `node deploy_vercel.js`

**Paso 1 — Pre-upload de imágenes:**
- Cada foto se sube individualmente con `PUT /v2/files`
- Header: `x-vercel-digest: sha1(buffer)` (Node.js `crypto.createHash('sha1')`)
- Respuesta 200 = subida nueva, 409 = ya existe (ambas son OK)

**Paso 2 — Crear deployment:**
- POST a `/v13/deployments`
- Archivos HTML van inline con `{ file, data: content, encoding: 'utf-8' }`
- Fotos van por referencia con `{ file, sha, size }` (el hash del paso 1)

### Credenciales Vercel
```
Token:     (NO va aquí — vive en vercel_token.txt, que está en .gitignore)
Team ID:   team_Crh14Al7vlA4XukCIsSorIMv
Project:   prj_ZPcK26zmGolKAd0KSwW5D4lPyqd0
Nombre:    institutelearningproject-project
```
> ⚠ El token estuvo escrito en claro en este documento y dentro de `deploy_vercel.js` /
> `deploy_vercel.ps1` hasta el 25 de julio de 2026. Ahora `deploy_vercel.js` lo lee de la
> variable de entorno `VERCEL_TOKEN` o del archivo `vercel_token.txt` (ignorado por git).
> **Pendiente para el dueño:** rotar el token en Vercel → Account Settings → Tokens, y
> escribir el nuevo en `vercel_token.txt`. El token viejo debe revocarse.

### ¿Por qué este método y no GitHub/CLI?
- El archivo de fotos supera el límite de 10 MB del body JSON de Vercel
- La solución es pre-uploadear cada imagen por separado y luego referenciarla por su SHA1

### vercel.json (rutas limpias)
```json
{
  "version": 2,
  "routes": [
    { "src": "/erp", "dest": "/erp.html" },
    { "src": "/inscripciones-secundaria", "dest": "/inscripciones-secundaria.html" },
    { "src": "/(.*)", "dest": "/$1" }
  ]
}
```

---

## 🗄️ BASE DE DATOS — SUPABASE

### Conexión
```javascript
const _sb = window.supabase.createClient(
  'https://bvmeunsyhrurigtgpedz.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2bWV1bnN5aHJ1cmlndGdwZWR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzNTM4OTIsImV4cCI6MjA5NzkyOTg5Mn0.dw9m8xkDVgOFDAZ-PNVedOM90ylQ56eBC7PgVkptiH0'
);
```
> Nota: este es el proyecto real usado por `erp.html` (cliente `_sb`) y por `index.html` (cliente público `_sbPub`). El ref `ujwmuuwdmwqcnracqnzg` que aparecía aquí antes estaba desactualizado.

### Tablas creadas en Supabase
| Tabla | Descripción |
|---|---|
| `alumnos` | id, nombre, nivel, grado, pago, asist, estado, etc. |
| `maestros` | id, nombre, email/correo, materia, nivel, estado, etc. |
| `pagos` | id, alumno, concepto, monto, fecha, estado (Pagado/Pendiente/Vencido) |
| `facturas` | id, folio_sat, alumno, monto, fecha, estado, xml_url, pdf_url |
| `comunicados` | id, titulo, dest, preview, enviado, fecha, fecha_envio, canal_envio |
| `usuarios_sistema` | id, usuario, pass, nombre, rol, last_acceso |
| `horarios` | id, grupo, dia, franja (0-5), materia |
| `asistencia` | id, alumno_id, grupo, fecha, estado (A/F/T) |
| `calificaciones` | id, alumno_id, grupo, periodo, materia, calificacion |
| `padres_acceso` | id, alumno_id, usuario, pass, activo — login individual de cada padre/tutor (uno por alumno), ver sección "Portal de Padres" abajo |

### Usuario del ERP (login)
> ~~Usuario: `admin` / Contraseña: `1234`~~ — **OBSOLETO (julio 2026).**
> El login ya no compara en el navegador: se hace con la función `staff_login`, que valida
> el hash bcrypt del lado del servidor. Hay 13 cuentas por área; las contraseñas están en
> `CLAVES_ERP_LPI.txt` (fuera de git). La puerta trasera `admin`/`1234` fue eliminada.

---

## 🌐 PÁGINA WEB (index.html)

### Paleta de colores LPI
```css
--primary:       #1B3D7A  /* Azul marino */
--primary-dark:  #112960
--primary-light: #2C5FA8
--gold:          #E8A020  /* Dorado */
--gold-light:    #F5C154
--gold-dark:     #C47D10
```

### Fuentes
- `Poppins` (texto general) — Google Fonts
- `Playfair Display` (títulos serif) — Google Fonts
- `Font Awesome 6.5.0` (iconos) — cdnjs

### Estructura de secciones
1. **Navbar** — fijo, blanco semitransparente, se vuelve sólido al hacer scroll
2. **Hero** — fondo blanco, título azul bold, imagen circular con gradiente dorado, íconos flotantes animados
3. **Stats Bar** — +500 alumnos, 4 niveles, 7am–7pm, 100% bilingüe
4. **Sobre Nosotros** — historia del colegio
5. **Misión y Visión** — cards con iconos
6. **Galería** — mosaico 4 columnas, lightbox al hacer clic (42 fotos)
7. **¿Qué nos hace únicos?** — cards de diferenciadores
8. **Niveles** — Maternal, Preescolar, Primaria, Secundaria
9. **Cambridge** — sección certificación internacional
10. **Programas Especiales** — Robótica, MUN, NASA
11. **Contacto** — formulario + WhatsApp buttons + mapa
12. **Footer** — logo, links, redes sociales

### Navbar — botones
- Links: Inicio, Nosotros, Niveles, Cambridge, Programas, Contacto
- `Inscripciones` → botón azul → `inscripciones-secundaria.html`
- `Facturación` → botón secondary → URL facturación
- `Portal` → `erp.html`

### Logo LPI (URL del wixstatic)
```
https://static.wixstatic.com/media/2f20e7_809ae5cf3f514c2ea32cae018caeb600~mv2.png/v1/crop/x_0,y_296,w_1024,h_587/fill/w_240,h_138,al_c,q_85,usm_0.66_1.00_0.01,enc_avif,quality_auto/2f20e7_809ae5cf3f514c2ea32cae018caeb600~mv2.png
```
**IMPORTANTE:** El logo tiene fondo crema/blanco (NO es transparente). Por eso se muestra dentro de un contenedor blanco redondeado (clase `.logo-pill` o `.logo-wrap`) en lugar de usar filtros CSS.

### Efectos especiales en index.html
- **🐶🚀 Astronauta Perrito:** personaje SVG fijo que vaga por toda la pantalla, rebota en los bordes, se voltea según dirección, burbuja de mensajes cada 8 segundos
- **✏️ Cursor Lápiz:** cursor personalizado SVG que aplica a toda la página con `encodeURIComponent` → data URL → inyectado en `<style>` via JS

### Teléfonos de contacto LPI
- Maternal/Preescolar: `+52 722 648 9373`
- Primaria/Secundaria: `+52 566 961 8182`
- Redes: Facebook, Instagram, TikTok, WhatsApp

---

## 🖥️ ERP (erp.html)

### Arquitectura
- **Single HTML file** — todo el JS, CSS y HTML en un solo archivo
- **Windows flotantes** — cada módulo se abre como ventana arrastrable (estilo OS)
- **Taskbar** — barra inferior con ventanas minimizadas
- **Modal overlay** — para formularios de creación/edición

### Módulos del ERP
| Módulo | Función |
|---|---|
| Dashboard | KPIs (alumnos, maestros, cobranza, vencidos), gráfica asistencia semanal, pagos recientes, tabla últimos alumnos, accesos rápidos |
| Alumnos | CRUD completo, búsqueda/filtro por nivel y pago, exportar CSV |
| Maestros | CRUD completo, estado activo/inactivo |
| Calificaciones | Tabla por alumno x materia con inputs editables, cálculo de promedio |
| Asistencia | Registro diario por grupo, historial |
| Pagos | CRUD, estados (Pagado/Pendiente/Vencido), total cobrado |
| Facturación | Formulario CFDI estilo Aspel (emisor, receptor, conceptos, totales IVA) |
| Comunicados | Crear/enviar comunicados, filtro enviados/pendientes |
| Horarios | Tabla semanal editable (días × franjas horarias) |
| Reportes | Panel con botones para generar reportes |
| Usuarios | Gestión de usuarios del sistema y roles |
| Configuración | Tabs: Escuela, Académico, Notificaciones, Seguridad |

### Dashboard — IDs de elementos importantes
```javascript
document.getElementById('greeting')          // Saludo dinámico
document.getElementById('dashDate')          // Fecha actual
document.getElementById('dash-total')        // Total alumnos
document.getElementById('dash-maestros')     // Maestros activos
document.getElementById('dash-cobranza')     // Total cobrado
document.getElementById('dash-vencidos')     // Pagos vencidos
document.getElementById('barChart')          // Gráfica de barras asistencia
document.getElementById('dash-alumnos-body') // Tbody últimos alumnos
document.getElementById('dash-pagos-recientes') // Div pagos recientes
```

### Función principal de carga de datos
```javascript
async function loadAllData() // Lee todas las tablas de Supabase en paralelo con Promise.all
function initDashboard()     // Renderiza el dashboard con los datos cargados
function renderDashAlumnos() // Llena la tabla de últimos alumnos
function renderDashPagos()   // Llena la lista de pagos recientes
```

### CSS importante ERP
- `--sidebar-w: 240px` — ancho del sidebar
- `--topbar-h: 60px` — altura del topbar
- `.fwindow` — ventanas flotantes (con resize y drag)
- `.fw-titlebar` — barra de título arrastrable (`cursor: grab`)
- `.nav-item.active` — ítem activo del sidebar resaltado
- `.logo-pill` — contenedor blanco para el logo en el sidebar

### Roles del sistema
```
'Dueño / Director General' | 'Director' | 'Coordinador' | 'Supervisor' | 'Maestro'
```

---

## 👨‍👩‍👧 PORTAL DE PADRES (dentro de index.html, sección `#calificaciones`)

### Cómo funciona
Cada alumno inscrito tiene su **propio usuario y contraseña** (tabla `padres_acceso`, 1 fila por alumno). Si una familia tiene varios hijos en la escuela, cada hijo tiene un login distinto.

- **Generación automática:** al registrar un alumno nuevo en el ERP (`_saveAlumnoCore`, erp.html), se llama `crearAccesoPadre(alumno)` que genera usuario (basado en el nombre + id) y contraseña aleatoria, los guarda en `padres_acceso` y los muestra en el modal de confirmación para entregarlos al padre/tutor.
- **Ver/regenerar credenciales:** desde el expediente del alumno en el ERP (botón "Acceso padres" en `verAlumno()`) se puede consultar el usuario/contraseña actual o generar una nueva contraseña (`verAccesoPadre`, `regenerarAccesoPadre`).
- **Login en el sitio web:** el padre entra a la sección "Acceso Padres" (botón del navbar → `#calificaciones`), ingresa usuario/contraseña, y `loginPadre()` valida contra `padres_acceso` usando el cliente público `_sbPub`.
- **Panel de solo lectura:** tras el login se muestran 4 pestañas (`portalTab()`) con datos de Supabase filtrados por `alumno_id` del alumno logueado:
  - **Calificaciones** — tabla `calificaciones`
  - **Asistencia** — tabla `asistencia` (con % calculado)
  - **Horario** — tabla `horarios`, filtrada por `grupo = grado + ' ' + nivel` del alumno (ej. "4°A Primaria")
  - **Avisos** — tabla `comunicados`, filtrados por `dest` (Todos / nivel del alumno)

### Tabla `padres_acceso`
Ver `padres_acceso.sql` para crearla en Supabase. Columnas: `id, alumno_id, usuario, pass, activo, created_at`.

### Funciones clave
| Archivo | Función | Qué hace |
|---|---|---|
| erp.html | `crearAccesoPadre(alumno)` | Genera e inserta usuario/contraseña nuevos |
| erp.html | `obtenerAccesoPadre(alumnoId)` | Trae el acceso actual del alumno |
| erp.html | `verAccesoPadre(id)` / `regenerarAccesoPadre(id)` | Ver o regenerar contraseña desde el expediente |
| index.html | `loginPadre()` | Valida usuario/contraseña contra `padres_acceso` |
| index.html | `portalTab(tab)` | Carga el contenido de cada pestaña del portal |

### Envío de credenciales por correo (EmailJS)
Al crear o regenerar el acceso de un alumno, `erp.html` envía automáticamente un correo real con el usuario/contraseña (si el alumno tiene `email` registrado), usando EmailJS (sin backend propio).

```javascript
const EMAILJS_PUBLIC_KEY  = 'MU0xmWwYm7iiEwD-2';
const EMAILJS_SERVICE_ID  = 'service_bsxbk74';     // Gmail conectado: pentatlonmoderno22@gmail.com
const EMAILJS_TEMPLATE_ID = 'template_q4yfvo5';    // plantilla "Contact Us" en EmailJS
```
- Dashboard: https://dashboard.emailjs.com (cuenta: learningprojectinstitute)
- Función: `enviarCorreoAccesoPadre(alumno, acc)` — llamada desde `crearAccesoPadre()` y `regenerarAccesoPadre()`
- Variables de la plantilla: `to_email, alumno_nombre, usuario, pass`
- Plan gratuito: 200 correos/mes (se resetea el día 30 de cada mes)
- **Nota:** se pidió conectar `learningprojectinstitute960@gmail.com`, pero por error en el flujo de Google OAuth quedó conectado `pentatlonmoderno22@gmail.com`. El usuario decidió dejarlo así. Para cambiarlo: EmailJS → Email Services → Gmail → Disconnect → reconectar con la cuenta correcta (sin cambiar Service ID si se quiere evitar tocar el código).

### Portal de padres en página aparte (jun 2026)
El portal de padres (login + calificaciones/asistencia/horario/avisos/factura) ya no vive dentro de index.html — se movió por completo a **acceso-padres.html**, un archivo independiente. Los botones "Acceso Padres" y "Facturación Online" del menú abren ese archivo en una pestaña nueva (`target="_blank"`), así el padre nunca ve el navbar, hero, galería ni el resto del sitio — solo el portal, aislado, sin distracciones. El botón de Facturación abre directo en la pestaña "Factura" vía `acceso-padres.html?tab=factura`.

### Seguridad del portal de padres (jun 2026)
index.html y erp.html comparten la misma llave "anon" de Supabase, así que la base de datos no puede distinguir un padre de un miembro del staff — por eso antes cualquiera con la llave (visible en el código fuente de la página) podía leer directo cualquier tabla (calificaciones, asistencia, `padres_acceso` con usuarios/contraseñas en texto plano, etc.), sin importar de qué alumno.

Arreglo aplicado (sin tocar login ni agregar backend): el portal de padres (index.html) ya **no lee ninguna tabla directo**. Todas sus consultas pasan por funciones de Supabase (`portal_login`, `portal_calificaciones`, `portal_asistencia`, `portal_horario`, `portal_avisos`, `portal_facturas`, `portal_solicitar_factura`, `portal_descargar_factura`) que:
- Revalidan usuario+contraseña en cada llamada (no solo al iniciar sesión).
- Solo devuelven las columnas que el portal necesita — nunca `tutor`, `tel`, `curp`, `nacimiento` ni la contraseña.
- Verifican que el alumno_id/pago_id consultado realmente pertenezca a ese usuario antes de regresar o insertar nada.

Esto reduce el riesgo real del uso normal de la app a casi cero. ~~**Límite conocido:** como erp.html sigue usando la misma llave con las tablas abiertas (`acceso_total`), alguien muy técnico que ataque la API de Supabase directamente (no a través de la página) todavía podría llegar a esas tablas — cerrar eso al 100% requeriría darle al ERP una llave con permisos distintos, lo cual sí implica una pequeña función de servidor. Quedó pendiente por decisión explícita del cliente (prioridad: no tocar el modo actual).~~

> ✅ **RESUELTO en julio 2026.** Ese "límite conocido" ya se cerró: el ERP se reescribió como
> `erp-nuevo.html` y hoy no lee ni escribe ninguna tabla directo (0 llamadas `.from()`,
> 89 llamadas a 77 funciones `staff_*`). RLS quedó activo y cerrado en las 28 tablas, así
> que la llave anon no sirve para nada contra la API de Supabase. No hizo falta una segunda
> llave: la solución fueron funciones `SECURITY DEFINER` que revalidan usuario+contraseña
> en cada llamada. Ver §7 de `RESUMEN_TECNICO_PARA_IA.md`.

### Factura online de colegiaturas (modelo, sin conexión automática a Aspel todavía)
El padre ya puede pedir su factura desde el portal, pero **no hay API real con Aspel/PAC** — Aspel sigue siendo el programa de escritorio de la oficina. Lo que se construyó es el flujo completo de solicitud → cumplimiento manual → entrega, listo para conectar una API real después sin rediseñar nada.

**Flujo:**
1. En el portal del padre (pestaña "Factura"), se listan sus pagos con `estado='Pagado'` (tabla `pagos`).
2. Por cada pago sin factura, el padre pulsa "Solicitar factura", llena RFC/razón social/CP fiscal/uso CFDI/correo, y se crea una fila real en `facturas` (`estado='Pendiente'`, `pago_id`, `alumno_id`).
3. En el ERP → Facturación CFDI, esa solicitud aparece con la etiqueta "Solicitud padre". El staff **replica esos datos manualmente en Aspel** (RFC, receptor, concepto, monto ya se muestran en el modal) y timbra ahí como siempre.
4. De vuelta en el ERP, el staff usa el botón "Subir CFDI timbrado" (ícono de nube): captura el folio fiscal/UUID real que dio Aspel, sube el XML real y (opcional) el PDF real.
5. Al guardar: la fila pasa a `estado='Timbrada'` con el XML/PDF reales guardados en la base de datos, y se envía un correo real (EmailJS) avisando al padre que ya puede descargar su factura.
6. El padre entra a su portal, pestaña Factura, y descarga el XML/PDF real desde ahí.

**Columnas nuevas en `facturas`:** `alumno_id`, `pago_id` (único, liga 1 factura por pago), `pdf_cfdi` (PDF real en base64), `solicitado_at`, `notificado`. El XML real se guarda en la columna `xml_cfdi` que ya existía.

**Funciones clave:** `subirCfdiTimbrado(id)` / `confirmSubirCfdiTimbrado(id)` (erp.html) — reemplazaron el timbrado falso (`Math.random()`) que existía antes. `renderPortalFactura()` / `solicitarFactura()` / `descargarFacturaArchivo()` (index.html).

**Pendiente real:** conectar una API de timbrado (Aspel Sellado CFDI, EDICOM, u otro PAC) para que el paso 3-4 se automatice solo. Requiere que la escuela consiga esas credenciales — no se puede hacer sin ellas, y el certificado de sello digital (CSD) nunca debe vivir en el navegador, así que ese paso también necesitará una función de servidor (p.ej. Supabase Edge Function).

### Notificaciones desde el ERP (Calificaciones, Asistencia, Horarios, Comunicados)
El portal de padres siempre muestra datos en vivo desde Supabase (no hay "publicar"). Los botones "Enviar" en el ERP solo mandan un **correo de aviso** ("ya hay algo nuevo, revisa el portal"), no controlan qué se ve.

```javascript
const EMAILJS_NOTIF_TEMPLATE_ID = 'template_dr4n4k1';  // "Notificacion Portal Padres"
```
- Funciones genéricas: `notificarPortalPadre(alumno, tipoAviso, mensaje)` (1 alumno) y `notificarGrupoPortalPadres(alumnosArr, tipoAviso, mensaje, onProgress)` (varios)
- Variables de la plantilla: `to_email, alumno_nombre, tipo_aviso, mensaje`
- **Calificaciones:** columna de radio buttons por alumno → "Enviar a alumno" (individual) o "Enviar a grupo" (todo el grupo activo)
- **Asistencia:** mismo patrón de radio buttons + individual/grupo
- **Horarios:** selector de alumno (filtrado al grupo activo) + botones individual/grupo, ya que el horario es por grupo
- **Comunicados:** el modal de envío deja elegir Destinatarios (grupo completo o alumno individual)
- **Nota técnica:** el envío por grupo en Calificaciones/Asistencia filtra `alumnos` directamente por `grado+nivel` (no usa `estudiantesCalif`, que muestra todos los alumnos sin filtrar por grupo — bug preexistente no corregido, fuera de este alcance)

---

## 📄 INSCRIPCIONES SECUNDARIA (inscripciones-secundaria.html)

### Contenido
- **Sección 1 — Hero de inscripciones:**
  - Badge "Abriendo pronto" con punto pulsante
  - Cuenta regresiva en tiempo real hasta `2025-09-01`
  - Formulario de pre-registro (nombre padre, alumno, email, teléfono, grado)
  - Al enviar: muestra confirmación + abre WhatsApp automáticamente

- **Sección 2 — Robótica:**
  - Imagen circular con gradiente azul/dorado
  - Íconos flotantes animados: Robótica, Programación, Electrónica, NASA
  - Cards de features: LEGO/Arduino, Programa NASA, Coding
  - Botón CTA que regresa a la sección de inscripciones

### Flujo del formulario
```javascript
// Al submit: envía datos como mensaje de WhatsApp al número de primaria/secundaria
window.open(`https://api.whatsapp.com/send?phone=5215669618182&text=${msg}`, '_blank');
```

---

## 🔧 PROBLEMAS RESUELTOS Y SUS SOLUCIONES

| Problema | Solución |
|---|---|
| Vercel rechazaba el body (>10MB) | Dos pasos: pre-upload por SHA1, luego deployment por referencia |
| Logo "todo blanco" | El logo tiene fondo crema → usar `.logo-pill` con `background:white` en vez de `filter:invert` |
| `files[0] should NOT have additional property sha` | HTMLs van con `{ file, data, encoding:'utf-8' }`, imágenes con `{ file, sha, size }` |
| Letras del nav se perdían | Hero cambió a blanco → navbar siempre blanco (no depende del scroll para visibilidad) |
| pnpm 403 en web-artifacts-builder skill | Se diseñó el hero directamente en HTML/CSS sin el skill de React |
| Fotos de alta calidad | Las fotos vienen de la carpeta `fotos/` con imágenes reales de Facebook de la escuela |

---

## 📋 ESTADO ACTUAL Y PENDIENTES

### ✅ Completado
- [x] Página web institucional completa (todas las secciones)
- [x] Todas las imágenes de Unsplash reemplazadas con fotos reales de la escuela
- [x] Hero rediseñado (blanco + imagen circular + íconos flotantes)
- [x] Galería de fotos con lightbox (42 fotos, más recientes primero)
- [x] ERP completo con 11 módulos + Supabase conectado
- [x] Dashboard del ERP con KPIs, gráficas y tablas reales
- [x] Logo correcto en ERP sidebar, ERP login y footer de la web
- [x] Script de deploy automático a Vercel (DEPLOY LPI.bat)
- [x] Página de inscripciones secundaria con countdown + formulario
- [x] Astronauta perrito vagabundo + cursor lápiz en la web
- [x] Botón "Facturación" en navbar (reemplazó "Inscripciones")
- [x] Portal de Padres reconstruido: login individual por alumno (usuario/contraseña en `padres_acceso`), generado automáticamente al inscribir, con vista de calificaciones/asistencia/horario/avisos (jun 2026)
- [x] Envío real de credenciales por correo vía EmailJS al crear/regenerar el acceso de un alumno (jun 2026)
- [x] Eliminado el módulo falso "Plataforma Padres" del ERP que simulaba envíos sin hacer nada real (jun 2026)
- [x] Botones reales de "Enviar a alumno" / "Enviar a grupo" en Calificaciones, Asistencia, Horarios y Comunicados — notifican por correo al padre que hay algo nuevo en su portal (jun 2026)
- [x] Factura online: el padre solicita factura de sus pagos ya pagados desde el portal, el staff la timbra en Aspel y sube el XML/PDF real al ERP, el padre recibe correo y descarga su factura — reemplazó el timbrado falso con Math.random() (jun 2026)

### ✅ Mejoras tecnológicas — julio 2026 (padres + institución)
- [x] **Bitácora de incidencias**: nuevo módulo ERP `Incidencias` (tabla `incidencias`, tipos Positiva/Negativa/Administrativa), con acceso rápido "Nueva incidencia" desde el expediente del alumno.
- [x] **Calendario escolar visual**: nuevo módulo ERP `Calendario Escolar` (tabla `eventos_calendario`) + nueva pestaña "Calendario" en el portal de padres (`acceso-padres.html`), consumida vía la función RPC segura `portal_calendario`.
- [x] **Tablero de pendientes del día**: nuevo widget en el dashboard del ERP que agrupa en un solo lugar facturas por timbrar, pagos vencidos, comunicados sin enviar, incidencias negativas de hoy y eventos del calendario de hoy — con acceso directo al módulo correspondiente.
- [x] **Selector de hijos en el portal**: si un dispositivo se usa para más de un hijo/a, el portal recuerda (solo en `localStorage`, nunca la contraseña) el usuario y nombre de cada alumno consultado, mostrando chips de acceso rápido en la pantalla de login. La contraseña siempre debe volver a escribirse.
- [x] **Aviso también por WhatsApp**: botón de WhatsApp (enlace `wa.me`, sin API ni credenciales) junto a los botones de notificación por correo en Calificaciones, Asistencia y Horarios (usa el teléfono/WhatsApp del tutor), y botón "Compartir por WhatsApp" en el detalle de Comunicados (abre el selector de contacto de WhatsApp con el mensaje ya redactado).
- [x] **Portal de padres como PWA instalable**: se agregó `manifest.json`, `sw.js` (service worker con cascarón offline, sin cachear nunca las llamadas a Supabase) e íconos (`fotos/oso-icon-192.png` / `-512.png`) para que los padres puedan "instalar" `acceso-padres.html` como app en su celular/escritorio.
- [x] **Recordatorios automáticos de pago**: función de Postgres `enviar_recordatorios_pago()` + extensión `pg_cron` (corre diario a las 15:00 UTC / 9:00 CDMX) + `pg_net` (llama la API REST de EmailJS directamente desde la base de datos, sin backend). Envía un correo a los padres con pagos vencidos o por vencer en 3 días, evitando reenviar el mismo aviso antes de 6 días (columna `recordatorio_enviado_at` en `pagos`) y con un tope de 15 envíos por corrida para cuidar la cuota mensual de EmailJS.
  - **Cambio de cuenta necesario**: se activó "Allow EmailJS API for non-browser applications" en la cuenta de EmailJS (Account → Security) para permitir que Supabase llame la API sin un navegador de por medio; se mantiene "Use Private Key" activado (más seguro) y la llave privada solo vive dentro de la función de Postgres, nunca se expone al cliente.
  - **Límite importante a vigilar**: el plan gratuito de EmailJS es de 200 correos/mes, compartido entre TODAS las notificaciones del sistema (credenciales, calificaciones, asistencia, horarios, avisos, facturas y ahora recordatorios de pago). Si la escuela crece, conviene subir de plan en EmailJS o separar los recordatorios de pago a un servicio de correo transaccional aparte.
- [x] **Respaldo automático de la base de datos**: tabla `respaldos_bd` (con Row Level Security activado y SIN política abierta — a propósito, para no exponer un volcado completo de la base por la anon key pública) + función `respaldo_diario()` + `pg_cron` (corre diario a las 08:00 UTC / 2:00 CDMX). Cada respaldo guarda un JSON completo de alumnos, maestros, pagos, facturas, comunicados, usuarios del sistema, horarios, asistencia, inscripciones, incidencias, eventos del calendario y accesos de padres, con retención de 14 días (los más antiguos se borran solos). Probado manualmente y funcionando.
  - En `erp.html` (pestaña "Respaldos" dentro de Configuración) hay un visor para listar y descargar cada respaldo como archivo `.json`, protegido por las funciones RPC `staff_listar_respaldos` y `staff_obtener_respaldo` (mismo patrón que las `portal_*`: revalidan usuario+contraseña del staff en cada llamada). Ya creadas, probadas y funcionando en producción.

### 🔲 Ideas / Pendientes posibles
- [ ] Agregar fotos reales de alta calidad desde Facebook/fuente oficial
- [ ] Conectar formulario de contacto a un endpoint real (email o base de datos)
- [ ] Panel de reportes con gráficas reales de Supabase
- [ ] Módulo de pagos con generación de recibos PDF
- [ ] Sistema de notificaciones por WhatsApp desde el ERP
- [ ] Dominio propio (actualmente en `.vercel.app`)
- [x] ~~Autenticación más robusta (actualmente usuario/contraseña en texto plano en tablas)~~ — **hecho en julio 2026**: bcrypt vía `pgcrypto` para staff y padres, login por `staff_login` / `portal_login`.
- [ ] Reconectar EmailJS con learningprojectinstitute960@gmail.com si se quiere usar esa cuenta en vez de pentatlonmoderno22@gmail.com
- [ ] Conectar una API real de timbrado (Aspel Sellado CFDI / EDICOM / otro PAC) para automatizar el paso que hoy hace el staff a mano subiendo el XML/PDF

### ✅ Roles y estructura real de la escuela — julio 2026
Se reorganizó el sistema de permisos del ERP para reflejar los roles reales de LPI (antes solo existían "pestañas" sueltas sin relación a la estructura de la escuela):
- [x] **Plantillas de rol** (`ROLE_TEMPLATES` en `erp.html`): Director General, Directora Maternal y Preescolar, Maestra/Auxiliar Maternal y Preescolar, Directora Primaria y Secundaria, Maestra/Auxiliar Primaria y Secundaria, Administración — Facturación y Nómina, Administración — Inscripciones, Administración — Comunicación. Al crear/editar un usuario en Configuración → Usuarios y Roles, se puede elegir una plantilla que prellena secciones y pestañas (queda editable después).
- [x] **Secciones (filtrado real de datos, no solo de módulos)**: cada usuario tiene un campo `secciones` (Maternal/Preescolar/Primaria/Secundaria, o `__all__`). Los módulos de Alumnos, Maestros, Asistencia, Calificaciones y Horarios ahora filtran de verdad los datos según la sección del usuario logueado (`alumnosVisibles()`, `maestrosVisibles()`, `opcionesGrupo()` en erp.html) — una directora o maestra de maternal ya no ve alumnos/maestros de primaria y secundaria, y viceversa. Director General y roles de Administración ven todo.
- [x] **Calificaciones para directoras y maestros**: antes solo estaba pensado para un módulo administrativo; ahora las directoras y maestros/auxiliares de cada sección tienen acceso (filtrado a su sección) porque son quienes publican las calificaciones que se reflejan en el portal de padres.
- [x] **Nuevo módulo Nómina** (tabla `nomina`): sueldos del personal, separado de Pagos y Cobranza (que es de colegiaturas). Bajo Contabilidad, junto con Pagos y Facturación CFDI.
- [x] **Nuevo módulo Bajas** (tabla `bajas_alumnos`): registro de alumnos dados de baja con motivo y fecha (el alumno se conserva en el historial, no se borra).
- [x] **Nuevo módulo Archivo de documentos**: vista centralizada de los documentos ya subidos por alumno (reutiliza los documentos del expediente).
- [x] **Canal general del sistema**: aviso/banner visible para todo el personal al entrar al ERP (dashboard), editable por cualquier usuario con acceso a Comunicados (se guarda en la tabla `configuracion`, clave `aviso_general`).
- [x] Sidebar reorganizado: Bajas y Archivo bajo "Control Escolar", Nómina bajo "Contabilidad".

~~**Nota técnica importante**: como en el resto del ERP, estos permisos son solo de interfaz (ocultan módulos y filtran listas en el navegador) — las tablas de Supabase siguen con políticas abiertas (`acceso_total`) como el resto del sistema, siguiendo el mismo criterio ya aceptado en jun 2026 (RLS real solo se aplicó al portal de padres vía funciones RPC). Si más adelante se requiere que el filtrado por sección sea imposible de saltar (no solo ocultar en la interfaz), habría que mover esa lógica a políticas RLS o funciones RPC del lado de Supabase.~~

> ✅ **SUPERADO en julio 2026.** Justo eso se hizo: el filtrado por módulo (`acceso`) y por
> nivel (`secciones`) ya **no** es solo de interfaz — se revalida dentro de cada función
> `staff_*` del lado del servidor, en cada llamada. Ocultar un módulo en el navegador ya no
> es lo que protege los datos. Excepción de diseño: la *lectura* de `alumnos`, `maestros`,
> `materias` y `eventos_calendario` exige la sección pero no el módulo, porque varios roles
> necesitan esos catálogos sin poder editarlos.

### ✅ Cuentas reales por rol + corrección crítica de login — julio 2026
Después de construir el modelo de roles/secciones se detectó que **el login nunca funcionó para usuarios nuevos**: `doLogin()` solo comparaba usuario/contraseña contra un arreglo fijo en el propio código (`sistemaUsuarios`), que arrancaba con un único usuario (`admin`) — nunca consultaba la tabla `usuarios_sistema` de Supabase antes de validar. Resultado: cualquier cuenta creada desde Configuración → Usuarios se guardaba bien en la base de datos, pero **nunca podía iniciar sesión** en una pestaña/sesión nueva.
- [x] **Corregido**: `doLogin()` ahora consulta primero `usuarios_sistema` en Supabase (con respaldo al usuario local `admin` si no hay conexión).
- [x] **Cuentas reales creadas** en Supabase (todas con la plantilla de rol correspondiente ya asignada; contraseñas en texto plano como el resto del sistema, pendientes de reasignar a personas reales):
  - `amaury` — Director General (Amaury Hernández), acceso total.
  - `directora.maternal` — Directora Maternal y Preescolar.
  - `directora.primaria` — Directora Primaria y Secundaria.
  - `maestras.maternal` / `maestras.primaria` — cuentas compartidas para maestras/auxiliares de cada sección (hasta tener nombres individuales).
  - `admin.facturacion` — Facturación, Pagos y Nómina.
  - `admin.inscripciones` — Inscripciones, Bajas y Archivo.
  - `admin.comunicacion` — Comunicados, aviso general y calendario escolar.
  - `admin` — se dejó aparte como cuenta técnica de respaldo; se le asignó el correo institucional `institutelearningproject@gmail.com`.
- [x] **Números de WhatsApp ahora editables** desde Configuración → WhatsApp (nueva pestaña en el ERP): antes estaban fijos en el código de `index.html`. Ahora se guardan en la tabla `configuracion` (clave `whatsapp_canales`) y `index.html` los lee al cargar la página (se agregó el cliente de Supabase al sitio público, con la misma llave anónima de solo lectura que ya se usaba en el ERP). Si no hay conexión o no se ha guardado nada, el sitio sigue usando los números por defecto ya conocidos.

- [ ] Respaldo automático de la base de datos (pg_cron + exportación periódica, ya que el plan Free de Supabase no incluye retención de backups) — completado, ver sección de mejoras tecnológicas de julio 2026 más abajo.

---

## 💡 COMANDOS CLAVE

```bash
# Desplegar TODO a producción (doble clic en Windows):
DEPLOY LPI.bat

# O desde terminal:
node "C:\Users\yacil\Claude\Projects\Learning Project\deploy_vercel.js"
```

---

## 🌐 LINKS IMPORTANTES

| Recurso | URL |
|---|---|
| Página web | https://institutelearningproject-project.vercel.app |
| ERP | https://institutelearningproject-project.vercel.app/erp |
| Inscripciones Secundaria | https://institutelearningproject-project.vercel.app/inscripciones-secundaria |
| Supabase Dashboard | https://supabase.com (proyecto: **bvmeunsyhrurigtgpedz** — `LPI-COLEGIO`) |
| Vercel Dashboard | https://vercel.com (proyecto: institutelearningproject-project) |
| Facebook LPI | https://www.facebook.com/learningprojectinstitute |
| Instagram LPI | https://www.instagram.com/learningprojectinstitute960 |
| TikTok LPI | https://www.tiktok.com/@learningprojectinstitute |
