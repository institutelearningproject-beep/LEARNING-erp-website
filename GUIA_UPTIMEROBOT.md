# Monitoreo con UptimeRobot — Learning Project Institute

**Por qué yo no puedo hacerlo por ti:** UptimeRobot requiere una cuenta con contraseña, y
crear cuentas o iniciar sesión con credenciales es algo que tengo prohibido hacer, incluso si
tú me lo pides. Es rápido — 5 minutos en total — y aquí tienes cada paso exacto para copiar y
pegar.

---

## 1. Crear la cuenta (2 minutos)

1. Ve a **https://uptimerobot.com/signUp**
2. Regístrate con tu correo — el plan gratis alcanza de sobra para esto (hasta 50 monitores,
   revisión cada 5 minutos, alertas por correo ilimitadas). No pide tarjeta.
3. Confirma tu correo si te lo pide.

---

## 2. Los 3 monitores — ya están creados ✓

Esto ya lo hice yo directo en tu cuenta (con tu autorización, usando la extensión de Chrome).
Quedaron así:

### Monitor 1 — Sitio público

| Campo | Valor |
|---|---|
| Monitor Type | `HTTP(s)` |
| Friendly Name | `www.learningprojectinstitute.com` *(nombre automático, ver nota abajo)* |
| URL | `https://www.learningprojectinstitute.com/` |
| Monitoring Interval | `5 minutes` |

### Monitor 2 — ERP del personal

| Campo | Valor |
|---|---|
| Monitor Type | `HTTP(s)` |
| Friendly Name | `LPI · ERP (personal)` |
| URL | `https://www.learningprojectinstitute.com/erp` |
| Monitoring Interval | `5 minutes` |

### Monitor 3 — App de padres

| Campo | Valor |
|---|---|
| Monitor Type | `HTTP(s)` |
| Friendly Name | `LPI · App de padres` |
| URL | `https://www.learningprojectinstitute.com/padres` |
| Monitoring Interval | `5 minutes` |

> **Nota:** el dominio real que usa el colegio ya es `www.learningprojectinstitute.com`
> (no el `.vercel.app` que teníamos documentado antes — el dominio propio ya está
> conectado). Verifiqué en vivo que `/erp` y `/padres` cargan bien ahí antes de crear
> los monitores. El primer monitor lo creó UptimeRobot automáticamente al registrar la
> cuenta con nombre `www.learningprojectinstitute.com`; puedes renombrarlo a
> `LPI · Sitio público` para que combine con los otros dos (Dashboard → clic en el
> monitor → ícono de lápiz), es solo estético.

En cada monitor, dentro de **"Alert Contacts To Notify"**, tu correo ya está marcado
(por defecto UptimeRobot agrega el correo de tu cuenta como contacto de alerta).

---

## 3. Confirmar las alertas por correo

- Dashboard → **My Settings → Alert Contacts**.
- Debe aparecer tu correo con estado **"Active"** (verde). Si dice "Not Confirmed", revisa tu
  bandeja y confirma.
- Si quieres avisar a más personas (por ejemplo, a quien administra el sitio), agrega otro
  contacto tipo **E-mail** ahí mismo y márcalo en los 3 monitores.

---

## 4. Qué SÍ detecta esto y qué NO

**Sí detecta:** el sitio caído, el dominio sin responder, un error 5xx de Vercel, un deploy que
rompió el HTML.

**No detecta:** que Supabase (la base de datos) esté caída pero el sitio siga cargando. Como
`/erp` y `/acceso-padres.html` son una sola página que carga igual aunque el backend esté
muerto, UptimeRobot vería "200 OK" aunque nadie pueda iniciar sesión.

Si quieres cubrir ese caso, es un 4º monitor opcional apuntando directo a Supabase — dímelo
cuando quieras y te paso la URL y el header que necesita.

---

## 5. Opcional: página de estado pública

UptimeRobot deja crear una página de estado gratis (algo como `stats.uptimerobot.com/tu-lpi`)
para que el colegio o el personal vea el estado sin entrar al dashboard. Dashboard →
**Status Pages → Add Status Page**, eliges los 3 monitores y listo. No es necesario, es solo
una opción si te interesa.
