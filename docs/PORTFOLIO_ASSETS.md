# SmartDesk AI — Guía de captura de assets

Esta guía define seis grupos de evidencia visual de alto valor —siete PNG por
la secuencia n8n en tres partes—. Ninguno debe fabricarse, simular producción
ni capturarse desde datos operacionales. Los PNG seleccionados se guardan en
`docs/assets/screenshots/` después de revisar cada imagen al 100 % de zoom.

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
**Status:** READY / PASS
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

**Assets:**

- `n8n-ticket-workflow-01-intake.png`
- `n8n-ticket-workflow-02-ai-processing.png`
- `n8n-ticket-workflow-03-outcome.png`

**Status:** READY / PASS
**Human review:** APPROVED
**Strategy:** 3-part sequence because the 78-node workflow is not legible in a
single full-canvas screenshot.
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
**Status:** READY / PASS
**Human review:** APPROVED
**Fuente:** caso sintético `SD-EVAL-TEST-083` del dataset congelado y su salida
real conservada en los artefactos de la evaluación oficial.
**Estado/datos:** composición determinista con los valores originales del input
y del resultado exitoso, sin datos productivos ni identificadores del proveedor.
**Debe verse:** marca de dato sintético, área, asunto, descripción y JSON con
`category`, `priority` y `summary`.
**Debe ocultarse:** endpoint real, authorization headers, provider response ID,
execution ID, ticket UUID, hostname, IP y rutas personales.
**Composición:** dos paneles input/output, fondo claro y contenido legible en
GitHub README.
**Resolución:** 1920×1080, 16:9.
**Caption:** “Example synthetic ticket and the schema-validated structured
result preserved from the frozen evaluation benchmark.”
**Competencia demostrada:** IA aplicada con contratos y validación
determinista.

## 4. Power BI analytical model

**Filename:** `powerbi-data-model.png`
**Status:** READY / PASS
**Source:** modelo real validado en Power BI Desktop durante Gate 8.
**Debe verse:** `FactTickets` como tabla padre y las relaciones activas 1:* a
`FactAIPredictions`, `FactHITLReviews` y `FactAutomationEvents`.
**Debe ocultarse:** filas, credenciales, conexión, hostname, IP, rutas locales
y cualquier dato operacional.
**Resolución:** 1227×779.
**Caption:** “Power BI analytical model with active one-to-many relationships
across tickets, predictions, human reviews and automation events.”
**Competencia demostrada:** SQL analítico, modelado relacional y Power BI.

## 5. GitHub Actions CI

**Filename:** `github-actions-ci.png`
**Status:** READY / PASS
**Source:** GitHub Actions run `36187333999`, SHA `e036b09`, repositorio
candidato.
**Debe verse:** repositorio candidato, `Status Success` y job `validate` verde.
**Debe ocultarse:** URL, tabs personales, logs del runner y cualquier valor
sensible.
**Ajuste:** crop y eliminación de padding únicamente; la UI no fue recreada.
**Resolución:** 1920×650.
**Caption:** “Hosted CI run for the sanitized portfolio candidate, with the
deterministic validation job completed successfully.”
**Competencia demostrada:** testing, CI y reproducibilidad.

## 6. Final demo video

**Status:** READY / PASS
**Human review:** APPROVED
**URL:** https://youtu.be/li0uU9b3e70
**Duration:** approximately 3m40s
**Visibility:** YouTube Unlisted
**Source:** recorrido final basado en los assets seleccionados, fixtures
sintéticos y evidencia saneada del repositorio candidato.
**Security:** revisión visual completada antes de enlazar el video; no se usa
ninguno de los dashboards Power BI rechazados como evidencia pública.
**Competencia demostrada:** comunicación técnica concisa y explicación
end-to-end del sistema.

## Power BI dashboards no seleccionados

Las tres capturas de páginas del reporte se contrastaron con Gate 8. Sus
valores coinciden exactamente con las 13 filas operacionales usadas para
reconciliación técnica y no existe evidencia de un seed demo público. Por ello
no se versionan ni se presentan en el README.

| Captura | Clasificación | Motivo |
| --- | --- | --- |
| Operations Overview | REJECT | Conteos operacionales de Gate 8; no son un dataset demo público. |
| AI & Human Review | REJECT | Mismos datos operacionales y riesgo de confundir `Prediction Success Rate` con accuracy. |
| SLA & Automation | REJECT | Datos operacionales, redundancia y poco valor adicional frente al modelo. |

## Assets descartados del bloque principal

| Asset | Estado | Motivo |
| --- | --- | --- |
| Power BI SLA/HITL | NOT NEEDED | La historia ya aparece en arquitectura y demo; añadirlo saturaría el README. |
| Negative CI → recovery | NOT NEEDED | Se conserva como evidencia profunda, no como captura principal. |
| Deploy por SHA | NOT NEEDED | El candidato no es autoridad productiva; mostrarlo puede confundir esa separación. |
| Demo thumbnail | NOT NEEDED | Crear solo después de que exista un video aprobado. |

## Selección visual final

| Asset | Source image | Classification | Final filename | README? | Reason | Security status |
| --- | --- | --- | --- | --- | --- | --- |
| Architecture | Asset aprobado | PRIMARY | `architecture-overview.png` | YES | Resume la arquitectura end-to-end. | PASS |
| n8n intake | Workflow real | PRIMARY | `n8n-ticket-workflow-01-intake.png` | YES | Intake, validación, persistencia y contrato IA. | PASS |
| n8n AI processing | Workflow real | PRIMARY | `n8n-ticket-workflow-02-ai-processing.png` | YES | Llamadas estructuradas, retries y fallos. | PASS |
| n8n outcome | Workflow real | PRIMARY | `n8n-ticket-workflow-03-outcome.png` | YES | Clasificación, HITL, reglas y resultado final. | PASS |
| Structured AI result | Caso `SD-EVAL-TEST-083` | PRIMARY | `ticket-ai-response.png` | YES | Une un input sintético con su output real validado. | PASS |
| Power BI data model | IMG-01 | PRIMARY | `powerbi-data-model.png` | YES | Demuestra relaciones analíticas sin mostrar filas. | PASS |
| GitHub Actions CI | Run `36187333999` | PRIMARY | `github-actions-ci.png` | YES | Evidencia CI alojado y job determinista exitoso. | PASS |
| Power BI SLA / Automation | IMG-02 | REJECT | — | NO | Datos operacionales de Gate 8 y redundancia. | SAFE BUT NOT PUBLICABLE |
| Power BI AI & Human Review | IMG-03 | REJECT | — | NO | Datos operacionales; success rate no es accuracy. | SAFE BUT NOT PUBLICABLE |
| Power BI Operations Overview | IMG-04 | REJECT | — | NO | Datos operacionales sin seed demo público. | SAFE BUT NOT PUBLICABLE |

## Revisión antes de incorporar un PNG

- [ ] La fuente es local/demo y todos los datos son sintéticos.
- [ ] No aparecen endpoints, hostnames, IPs, alias SSH ni rutas personales.
- [ ] No aparecen secrets, credentials, chat IDs ni response IDs.
- [ ] No aparecen notificaciones, tabs, perfiles o ventanas ajenas.
- [ ] El caption es factual y coherente con `PORTFOLIO_METRICS.md`.
- [ ] El archivo mantiene su nombre final y un crop legible para README.
- [ ] La imagen fue revisada al 100 % de zoom.

