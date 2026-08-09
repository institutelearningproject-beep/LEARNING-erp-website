# App de Padres LPI — guía completa

**Versión 2.0.0 · agosto 2026**

La app de padres ya no es solo un portal de consulta: ahora tiene **pago de colegiaturas**,
**estado de cuenta**, **avisos con confirmación de lectura** y está lista para publicarse en
**Google Play** como app instalable.

Sigue siendo el mismo archivo (`acceso-padres.html`) y la misma URL, así que **los papás que ya
lo usan no pierden nada**: al entrar ven la versión nueva.

---

## 1. Qué cambió

### En la app (`acceso-padres.html`)

| Antes | Ahora |
|---|---|
| Una tarjeta de login y 6 pestañas | App con pantalla de bienvenida, logo del colegio y barra inferior de 5 secciones |
| Sin pagos | **Inicio** con saldo pendiente, **Pagos** con estado de cuenta, botón de pagar y envío de comprobante |
| Avisos sin marcar | **Avisos** con globo de "sin leer", se marcan al abrirlos |
| Había que escribir la contraseña cada vez | Opción de **mantener la sesión iniciada** |
| Sin resumen | Promedio, asistencia y avisos nuevos de un vistazo |
| Iconos genéricos | Icono de la app con el osito del colegio, splash azul institucional |

### Secciones

- **Inicio** — saldo pendiente (o "Al corriente"), promedio, asistencia, avisos nuevos, próximos cargos y últimos avisos.
- **Pagos** — tres pestañas: *Por pagar* (cargos con vencimiento y botón Pagar), *Mis reportes* (comprobantes enviados y su estado) e *Historial* (pagos ya aplicados).
- **Escolar** — Calificaciones, Asistencia, Horario y Calendario.
- **Avisos** — comunicados del colegio; se abren para leer y se marcan como leídos.
- **Cuenta** — datos del alumno, facturación (CFDI), cambio rápido entre hermanos y cerrar sesión.

### En la base de datos (Supabase, ya aplicado)

Migración `app_padres_pagos_y_avisos`. **Aditiva: no se tocó nada de lo que ya existía y no se
abrió ninguna tabla al rol `anon`.**

Tabla nueva:

- `pagos_online` — cada comprobante que un papá sube (con RLS cerrado, sin políticas).

Funciones nuevas del portal (todas `SECURITY DEFINER`, revalidan usuario+contraseña):

| Función | Para qué |
|---|---|
| `portal_resumen` | Datos de la pantalla de inicio (saldo, promedio, asistencia, avisos sin leer) |
| `portal_estado_cuenta` | Cargos pendientes y vencidos, con el estado del comprobante si ya se envió |
| `portal_historial_pagos` | Pagos ya aplicados |
| `portal_datos_pago` | Banco, CLABE, beneficiario e instrucciones (lista blanca de `configuracion`) |
| `portal_reportar_pago` | El papá sube su comprobante y queda "en revisión" |
| `portal_pagos_reportados` | Sus comprobantes enviados y en qué van |
| `portal_avisos` | *(actualizada)* ahora devuelve `id` y `leido` |
| `portal_marcar_aviso_leido` | Marca el comunicado como leído para ese alumno |

Funciones nuevas del ERP (para el personal, requieren el módulo `pagos` o `comunicados`):

| Función | Para qué |
|---|---|
| `staff_listar_pagos_online` | Bandeja de comprobantes por revisar |
| `staff_ver_comprobante` | Descarga el comprobante que subió el papá |
| `staff_resolver_pago_online` | Aprobar / rechazar. **Al aprobar marca el pago como Pagado automáticamente** |
| `staff_lecturas_comunicado` | Quién leyó cada aviso |

> Estas cuatro funciones ya existen en la base pero **todavía no hay pantalla en el ERP** que
> las use. Ver "Pendientes" al final.

---

## 2. Archivos que cambiaron

| Archivo | Qué hacer |
|---|---|
| `acceso-padres.html` | **Reemplazar** (es la app nueva) |
| `manifest.json` | **Reemplazar** (nombre, iconos, atajos, capturas) |
| `sw.js` | **Reemplazar** (ahora red-primero en el HTML: los cambios se ven sin recargar dos veces) |
| `vercel.json` | **Reemplazar** (rutas `/padres`, `/app` y `/.well-known/assetlinks.json`) |
| `deploy_vercel.js` | **Reemplazar** (ahora sube `assetlinks.json` y los iconos nuevos) |
| `assetlinks.json` | **Nuevo** en la raíz — necesario para Google Play |
| `fotos/app-icon-*.png` | **Nuevos** — iconos de la app |
| `fotos/screen-*.png` | **Nuevos** — capturas para la ficha de Play y la instalación como PWA |
| `android-app/` | **Nuevo** — proyecto Android listo para compilar |
| `app_padres_pagos.sql` | Respaldo de la migración (ya aplicada, se guarda como referencia) |

Después de copiarlos: doble clic en **`DEPLOY LPI.bat`**, como siempre.

---

## 3. Lo primero que hay que hacer: poner los datos bancarios

Hoy la app dice *"La escuela aún no publica sus datos bancarios"* porque están vacíos.
Corre esto en **Supabase → SQL Editor** con los datos reales del colegio:

```sql
update configuracion set valor = 'BBVA México'                       where clave = 'pago_banco';
update configuracion set valor = '012XXXXXXXXXXXXXXX'                where clave = 'pago_clabe';
update configuracion set valor = 'LEARNING PROJECT INSTITUTE S.C.'   where clave = 'pago_beneficiario';
update configuracion set valor = 'Realiza tu transferencia y sube aquí tu comprobante. Lo validamos en un máximo de 24 horas hábiles.'
                                                                      where clave = 'pago_instrucciones';
```

En cuanto tengan valor, la app muestra la CLABE con botón de copiar dentro de la hoja de pago.

---

## 4. Cómo funciona el pago hoy (y qué falta decidir)

Como todavía no eligieron pasarela, el flujo que quedó **ya sirve desde el primer día** y no
cobra comisión:

1. El papá ve su cargo y toca **Pagar**.
2. La app le muestra banco, CLABE, beneficiario y referencia (el nombre del alumno).
3. Transfiere desde su banco y **sube la foto o el PDF del comprobante** (las fotos se comprimen solas).
4. El cargo queda **"En revisión"** y ya no se puede reportar dos veces.
5. Alguien de administración lo revisa y lo aprueba → el pago se marca **Pagado** solo, y el papá lo ve al instante.

Cuando decidan la pasarela, **no hay que rehacer nada**: la tabla `pagos_online` ya guarda
`metodo` y `referencia_externa`, y el botón "Pagar con tarjeta" ya está en el código, oculto
detrás de la clave `pago_metodos`. Solo se conecta el webhook.

**Comparación rápida para cuando lo decidan (México, agosto 2026 — confirmar tarifas vigentes):**

| Opción | A favor | En contra |
|---|---|---|
| **Mercado Pago** | Alta rápida, acepta OXXO y SPEI, es lo que más usan los colegios | Comisión por transacción; el dinero se libera con retraso salvo que pagues por adelanto |
| **Stripe** | Mejor panel y mejor API | Alta más lenta en México, comisión similar o mayor |
| **Solo transferencia** | Cero comisión | Alguien tiene que revisar comprobantes a mano todos los días |

Mi sugerencia: **arrancar con transferencia + comprobante** (que ya está listo) y medir cuánto
trabajo real da. Si son 30 familias, se revisa en 10 minutos al día y se ahorran las comisiones.
Si crece o si los papás piden tarjeta, se conecta Mercado Pago encima, sin tocar lo demás.

---

## 5. Publicar en Google Play

Hay dos caminos. **El segundo es mucho más fácil.**

### Requisitos comunes

- Cuenta de **Google Play Console** (pago único de 25 USD).
- Como el colegio es una institución, Google va a pedir verificación de identidad de la
  organización. Tenlo listo: es lo que más tarda (puede llevar días).
- El sitio ya está en HTTPS ✓ y el manifest ya cumple los requisitos ✓.

### Camino A (recomendado) — PWABuilder, sin instalar nada

1. Despliega primero (`DEPLOY LPI.bat`) para que la app nueva esté en línea.
2. Entra a **https://www.pwabuilder.com**.
3. Pega: `https://institutelearningproject-project.vercel.app/acceso-padres.html`
4. Te da una calificación del manifest y del service worker (debería salir en verde).
5. Clic en **Package for stores → Android → Generate**.
   - Package ID: `mx.learningproject.padres`
   - App name: `LPI Padres`
   - Launcher name: `LPI Padres`
   - Deja marcado *"Signing key: Create new"*.
6. Descarga el ZIP. Trae:
   - `app-release-bundle.aab` → esto se sube a Play
   - `signing.keystore` + `signing-key-info.txt` → **guárdalos en un lugar seguro; sin ellos no puedes volver a actualizar la app nunca**
   - `assetlinks.json` → **este reemplaza el que va en la raíz del proyecto**
7. Copia ese `assetlinks.json` a la carpeta del proyecto (sustituye el que dejé con el texto
   `PEGAR_AQUI...`), corre `DEPLOY LPI.bat` y verifica que abra:
   `https://institutelearningproject-project.vercel.app/.well-known/assetlinks.json`
8. En Play Console: crear app → subir el `.aab` → llenar la ficha (usa las capturas de
   `fotos/screen-*.png`) → enviar a revisión.

> **Ojo con el paso 7.** Si `assetlinks.json` no coincide con la firma real de la app, la app
> abre con una barra de navegador arriba en lugar de verse como app nativa. Si eso pasa, la
> huella correcta está en Play Console → *Configuración → Integridad de la app → Certificado
> de firma de apps* (copia el SHA-256 y pégalo en el archivo).

### Camino B — compilar el proyecto que dejé en `android-app/`

Solo si quieren control total del código Android.

1. Instalar **Android Studio**.
2. Abrir la carpeta `android-app` (File → Open).
3. Crear la llave de firma (una sola vez, desde la terminal):

   ```
   keytool -genkeypair -v -keystore lpi-padres-upload.jks -alias lpi-padres ^
           -keyalg RSA -keysize 2048 -validity 10000
   ```

   Guarda el archivo `.jks` y las contraseñas en un lugar seguro. **No las mandes por chat ni
   las subas a GitHub.**

4. En `app/build.gradle` descomenta el bloque `signingConfigs.release` y pon la ruta y el alias.
5. Ver la huella para `assetlinks.json`:

   ```
   keytool -list -v -keystore lpi-padres-upload.jks -alias lpi-padres
   ```

   Copia la línea `SHA256:` y pégala en `assetlinks.json` (sin espacios extra), luego despliega.
6. En Android Studio: **Build → Generate Signed Bundle / APK → Android App Bundle**.
7. Sube el `.aab` a Play Console.

### Para la ficha de Play

- **Nombre:** LPI Padres
- **Descripción corta:** Colegiaturas, calificaciones y avisos del Learning Project Institute.
- **Descripción larga (borrador):**
  > App oficial para padres de familia del Learning Project Institute, colegio bilingüe en
  > Metepec, Estado de México. Consulta el estado de cuenta de tu hijo o hija, paga la
  > colegiatura enviando tu comprobante, revisa calificaciones y asistencia, consulta el
  > horario y el calendario escolar, y recibe los avisos del colegio. El acceso es exclusivo
  > para familias inscritas, con el usuario que entrega la escuela.
- **Capturas:** `fotos/screen-inicio.png`, `screen-pagos.png`, `screen-escolar.png`, `screen-avisos.png`, `screen-login.png`
- **Icono 512×512:** `fotos/app-icon-512.png`
- **Categoría:** Educación
- **Clasificación de contenido:** apta para todos
- Google va a pedir una **política de privacidad publicada en una URL**. Todavía no existe:
  hay que escribirla y subirla (por ejemplo en `/privacidad`). Es requisito obligatorio.

### iPhone

En iOS no se necesita App Store: los papás abren la app en Safari y usan
**Compartir → Agregar a inicio**. Queda con su icono y a pantalla completa. Publicar en la App
Store sí requeriría una app nativa de verdad y 99 USD al año.

---

## 6. Nota de seguridad importante

La app guarda usuario y contraseña en el dispositivo cuando el papá deja marcado *"Mantener la
sesión iniciada"* (viene marcado por defecto, porque una app que pide contraseña cada vez se
siente rota). Está avisado en la pantalla de login y se borra al cerrar sesión.

Esto es una consecuencia del diseño actual del sistema: **todas** las funciones del portal
reciben usuario y contraseña en cada llamada. La mejora real sería cambiar a **sesiones con
token** (una tabla `padres_sesiones` con token, expiración y dispositivo), para que el
dispositivo guarde un token revocable en lugar de la contraseña. Es un cambio de un rato y vale
la pena antes de que la app crezca mucho — sobre todo si van a manejar pagos.

Lo que **no** cambió y sigue bien: RLS cerrado en todas las tablas, cero accesos directos desde
el navegador, y la contraseña se revalida contra el hash bcrypt en el servidor en cada consulta.

---

## 7. Pendientes

1. **Poner los datos bancarios** en `configuracion` (sección 3). Sin esto la app no puede cobrar.
2. **Pantalla en el ERP para revisar comprobantes.** Las funciones ya están; falta el módulo en
   `erp.html` que liste `staff_listar_pagos_online`, muestre el comprobante y tenga los botones
   Aprobar / Rechazar. **Sin esto, los comprobantes llegan pero nadie los puede aprobar desde la
   interfaz** (por ahora se pueden aprobar corriendo `staff_resolver_pago_online` en el SQL Editor).
3. **Decidir la pasarela de pago** (sección 4).
4. **Política de privacidad publicada** — Google Play la exige.
5. **Datos de prueba:** dejé en la base un alumno `ZZ_PRUEBA_App Padres` con usuario
   `zz_prueba_app`. Bórralo cuando ya no lo necesites:

   ```sql
   delete from alumnos where nombre like 'ZZ_PRUEBA%';
   delete from comunicados where titulo like 'ZZ_PRUEBA%';
   ```

6. **Notificaciones push** — quedaron fuera a propósito (elegiste "solo dentro de la app").
   Cuando las quieran, la app ya tiene service worker; falta Web Push con llaves VAPID y una
   función que dispare el envío al publicar un comunicado.
