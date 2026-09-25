# SmartDesk AI — Guía de captura de assets

Esta guía define seis assets finales de alto valor. Ninguno debe fabricarse,
simular producción ni capturarse desde datos operacionales. Guardar los PNG
aprobados en `docs/assets/screenshots/` solo después de revisar cada imagen al
100 % de zoom.

## Reglas comunes

- Fuente: entorno local o demo aislado con datos exclusivamente sintéticos.
- Formato: PNG, 1600×900 o superior, relación 16:9.
- Legibilidad: texto principal legible al 100 % y sin ventanas ajenas.
- Prohibido: hostname, IP, webhook, alias SSH, rutas personales, `.env`,
  tokens, passwords, chat IDs, credenciales, response IDs y logs productivos.
- Si una captura necesita blur para ser segura, repetirla con datos saneados en
  origen en vez de depender del blur.

## 1. Architecture overview

**Filename:** `architecture-overview.png`
**Status:** MANUAL CAPTURE REQUIRED
**Pantalla a abrir:** preview renderizado del Mermaid de
`docs/ARCHITECTURE.md` en el candidato de portfolio.
**Estado/datos:** commit final candidato, sin paneles laterales ni información
local visible.
**Debe verse:** request, HTTPS/Caddy, n8n, validación, OpenAI, PostgreSQL,
reglas, Telegram, HITL/SLA, analytics y Power BI.
**Debe ocultarse:** URL del navegador si contiene datos locales, hostname, IP,
rutas personales y controles del editor.
**Crop recomendado:** solo diagrama y título, centrados, con margen uniforme.
**Resolución:** 1920×1080 preferida; mínimo 1600×900.
**Caption:** “Arquitectura end-to-end: validación, IA estructurada,
automatización, persistencia y analítica.”
**Competencia demostrada:** diseño de arquitectura e integración de sistemas.

## 2. n8n ticket workflow

**Filename:** `n8n-ticket-workflow.png`
**Status:** MANUAL CAPTURE REQUIRED
**Pantalla a abrir:** canvas del workflow real `Ticket Intake` en una
instancia local/demo.
**Estado/datos:** workflow importado y nodos nombrados; cerrar execution data,
credentials y settings.
**Debe verse:** recepción, validación, persistencia DB-first, llamada IA,
validación de salida, reglas y ramas de respuesta.
**Debe ocultarse:** credentials, URLs, hostnames, execution IDs, tokens,
headers y paneles con datos anteriores.
**Crop recomendado:** canvas completo centrado; zoom suficiente para leer los
nombres de nodos.
**Resolución:** 1920×1080 o 2560×1440, crop final 16:9.
**Caption:** “Orquestación n8n del intake: persistencia antes de IA y reglas
deterministas después de validar el JSON.”
**Competencia demostrada:** automatización de procesos y diseño de workflows.

## 3. Synthetic ticket and structured AI response

**Filename:** `ticket-ai-response.png`
**Status:** MANUAL CAPTURE REQUIRED
**Pantalla a abrir:** cliente HTTP o terminal limpia con request y response de
una ejecución ensayada de `DEMO-LOW-001`.
**Estado/datos:** entorno demo aislado; payload de `demo/tickets.json`; salida
real capturada en el ensayo.
**Debe verse:** marca de dato sintético, request, HTTP result y JSON con
`category`, `priority` y `summary`.
**Debe ocultarse:** endpoint real, authorization headers, provider response ID,
ticket UUID completo y command history no relacionada.
**Crop recomendado:** dos paneles o bloques verticales request/response, sin
barra de direcciones.
**Resolución:** 1600×900 o superior, 16:9.
**Caption:** “Ticket sintético clasificado mediante Structured Outputs y JSON
Schema.”
**Competencia demostrada:** IA aplicada con contratos y validación
determinista.

## 4. Power BI overview

**Filename:** `powerbi-overview.png`
**Status:** MANUAL CAPTURE REQUIRED
**Pantalla a abrir:** página Overview del reporte Power BI.
**Estado/datos:** modelo conectado únicamente a la base demo y filtros en un
estado representativo; nunca usar las filas operacionales de Gate 8.
**Debe verse:** KPIs, distribución por categoría/prioridad/área, filtros y
periodo visible.
**Debe ocultarse:** panel de conexión, servidor, usuario, rutas locales,
emails, texto libre y Power Query con credenciales.
**Crop recomendado:** canvas completo del reporte, sin Desktop chrome
innecesario.
**Resolución:** 1920×1080 preferida, 16:9.
**Caption:** “Overview operativo sobre vistas PostgreSQL y datos sintéticos de
demo.”
**Competencia demostrada:** modelado analítico, SQL, DAX y visualización.

## 5. Power BI AI quality

**Filename:** `powerbi-ai-quality.png`
**Status:** MANUAL CAPTURE REQUIRED
**Pantalla a abrir:** página AI Quality del reporte Power BI.
**Estado/datos:** dataset demo sintético con filtros visibles y sin texto de
tickets.
**Debe verse:** status de predictions, categorías, prioridades y métricas con
grain explícito.
**Debe ocultarse:** response IDs, summaries, emails, conexión y datos
operacionales de Gate 8.
**Crop recomendado:** canvas del reporte completo o zona central con título y
filtros.
**Resolución:** 1920×1080 preferida, 16:9.
**Caption:** “Trazabilidad de predicciones a grain prediction; confidence no
se presenta como probabilidad calibrada.”
**Competencia demostrada:** evaluación responsable y observabilidad de IA.

## 6. GitHub Actions CI

**Filename:** `github-actions-ci.png`
**Status:** MANUAL CAPTURE REQUIRED
**Pantalla a abrir:** run CI final del repositorio candidato.
**Estado/datos:** ejecución PASS sobre el commit final, con el job
`Run deterministic CI` expandido solo si la salida está saneada.
**Debe verse:** repositorio candidato, estado verde, SHA abreviado,
validator/tests y PostgreSQL temporal o migraciones.
**Debe ocultarse:** rutas del runner que distraigan, identidad no necesaria,
tabs personales y cualquier valor sensible.
**Crop recomendado:** encabezado del run y lista de steps; evitar sidebar y
actividad ajena.
**Resolución:** 1600×900 o superior, 16:9.
**Caption:** “CI determinista: validator, 35 tests y migraciones sobre
PostgreSQL temporal.”
**Competencia demostrada:** testing, CI y reproducibilidad.

## Assets descartados del bloque principal

| Asset | Estado | Motivo |
| --- | --- | --- |
| Power BI SLA/HITL | NOT NEEDED | La historia ya aparece en arquitectura y demo; añadirlo saturaría el README. |
| Negative CI → recovery | NOT NEEDED | Se conserva como evidencia profunda, no como captura principal. |
| Deploy por SHA | NOT NEEDED | El candidato no es autoridad productiva; mostrarlo puede confundir esa separación. |
| Demo thumbnail | NOT NEEDED | Crear solo después de que exista un video aprobado. |

## Revisión antes de incorporar un PNG

- [ ] La fuente es local/demo y todos los datos son sintéticos.
- [ ] No aparecen endpoints, hostnames, IPs, alias SSH ni rutas personales.
- [ ] No aparecen secrets, credentials, chat IDs ni response IDs.
- [ ] No aparecen notificaciones, tabs, perfiles o ventanas ajenas.
- [ ] El caption es factual y coherente con `PORTFOLIO_METRICS.md`.
- [ ] El archivo mantiene su nombre final y 16:9.
- [ ] La imagen fue revisada al 100 % de zoom.

