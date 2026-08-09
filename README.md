# Learning Project Institute — sitio web, ERP y app de padres

Código del colegio bilingüe **Learning Project Institute** (Metepec, Estado de México).
Un solo colegio (no es un SaaS multi-cliente), sin build step: HTML, CSS y JavaScript planos.

> **Antes de tocar nada, lee [`AGENTS.md`](AGENTS.md) y [`RESUMEN_TECNICO_PARA_IA.md`](RESUMEN_TECNICO_PARA_IA.md).**
> Ahí está la arquitectura, el modelo de seguridad de la base de datos y cómo se despliega.

---

## Las tres piezas

| Pieza | Archivo | URL |
|---|---|---|
| Sitio público | `index.html` | `/` |
| ERP del personal | `erp.html` | `/erp` |
| App de padres (PWA) | `acceso-padres.html` | `/padres` · `/app` |
| App Android (TWA) | `android-app/` | Google Play |

`erp-nuevo.html` es una copia histórica del ERP. `inscripciones-secundaria.html` es el
formulario público de preinscripción.

---

## Cómo funciona por dentro

- **Base de datos:** Supabase (Postgres). Proyecto `bvmeunsyhrurigtgpedz`.
- **Seguridad:** RLS activo y **cerrado en todas las tablas** — con la llave pública `anon`
  nadie puede leer ni escribir ninguna tabla directo. Todo el acceso pasa por funciones SQL
  `SECURITY DEFINER` (`staff_*` para el personal, `portal_*` para los padres) que revalidan
  usuario y contraseña contra el hash bcrypt en cada llamada.
- **Autenticación:** propia, no usa Supabase Auth. `usuarios_sistema` (13 cuentas por área)
  y `padres_acceso` (una por alumno).
- **Despliegue:** Vercel, pero **no** con `git push`. Se corre `DEPLOY LPI.bat`, que ejecuta
  `deploy_vercel.js` contra la API REST de Vercel. Este repo es control de versiones y
  respaldo, no la fuente del deploy.

## Estructura

```
index.html                Sitio público
erp.html                  ERP en producción
acceso-padres.html        App de padres (pagos, calificaciones, avisos)
manifest.json  sw.js      PWA de la app de padres
assetlinks.json           Verificación de dominio para Google Play
android-app/              Proyecto Android (Trusted Web Activity)
vercel.json               Rutas y cabeceras
deploy_vercel.js          Script de despliegue (lee el token de vercel_token.txt)
DEPLOY LPI.bat            Doble clic para desplegar
*.sql                     Migraciones y esquemas de Supabase
fotos/                    Imágenes del sitio y assets de la app
AGENTS.md                 Instrucciones para quien retome el proyecto
GUIA_APP_PADRES.md        App de padres: qué hace y cómo publicarla en Play
RESUMEN_TECNICO_PARA_IA.md  Arquitectura completa
HALLAZGOS_2026-07-25.md     Diagnóstico de bugs y riesgos abiertos
```

## Reglas del repo

- **Nunca** commitear `CLAVES_ERP_LPI.txt`, `vercel_token.txt`, ni ninguna llave de firma
  (`*.jks`, `*.keystore`). Están en `.gitignore`, pero revisa antes de cada commit.
- La llave `anon` de Supabase **sí** va en el código del cliente: es pública por diseño y la
  seguridad real vive en RLS + las funciones del servidor.
- No hay entorno de pruebas: `/erp` es producción real.

## Desplegar un cambio

1. Editar los archivos.
2. Doble clic en `DEPLOY LPI.bat`.
3. Commitear y subir aquí para dejar registro.

Los cambios de base de datos se hacen directo en Supabase (SQL Editor) y se guardan como
archivo `.sql` en este repo para tener el historial.
