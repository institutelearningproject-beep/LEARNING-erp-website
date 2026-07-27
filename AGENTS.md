## Learning Project Institute (LPI) — instrucciones para agentes

Sitio web público + ERP escolar para Learning Project Institute (colegio bilingüe en Metepec, Edo. de México). Un solo tenant, sin build step: HTML/JS/CSS planos.

**Antes de tocar nada, lee estos dos archivos:**

- `RESUMEN_TECNICO_PARA_IA.md` — arquitectura, hosting, rutas, modelo de seguridad de la base de datos, cómo desplegar y pendientes. Es el punto de partida obligatorio.
- `RESUMEN_PROYECTO_LPI.md` — bitácora funcional (features e historial de decisiones). ⚠ El cuerpo tiene datos obsoletos de junio; solo la cabecera de julio está al día.
- `HALLAZGOS_2026-07-25.md` — diagnóstico del código real vs. los resúmenes: bugs abiertos, riesgos y orden de trabajo sugerido.

**Reglas rápidas:**

- El ERP en producción es `erp-nuevo.html` (ruta `/erp`). `erp.html` está congelado y roto a propósito — no operar con él.
- El deploy NO ocurre con `git push`. Se corre `DEPLOY LPI.bat` (Node.js, API REST de Vercel).
- No hay entorno de staging: `/erp` es producción real.
- Todo acceso a datos pasa por funciones SQL `SECURITY DEFINER` en Supabase (proyecto `bvmeunsyhrurigtgpedz`). RLS está cerrado en las 28 tablas; nunca abrir una tabla al rol `anon`.
- `CLAVES_ERP_LPI.txt` contiene contraseñas en claro. Está en `.gitignore`. No subirlo, no pegarlo en chats ni en commits.
