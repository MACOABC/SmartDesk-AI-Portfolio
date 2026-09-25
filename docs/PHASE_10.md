# Phase 10 — Portfolio readiness

## Estado

**Phase 10: IN PROGRESS. Gate 10: NOT APPROVED.**

Esta fase mejora presentación, reproducibilidad y defendibilidad profesional
sin ampliar el producto. No cambia `v1.0`, no publica el repositorio y no crea
una release.

## Sprint autónomo inicial

| Checkpoint | Resultado | Evidencia |
| --- | --- | --- |
| 10.A Preflight | PASS | Root SmartDesk AI, `main`, árbol inicial limpio y GitHub privado verificados. |
| 10.B Hosted monitor | PASS | Causa confirmada y environment añadido; run `36087544636`, SHA `5602702c...`, `workflow_dispatch`, success y 404 esperado. |
| 10.C Deploy approval | PASS documental | No existen protection rules; documentación corregida para no afirmar required reviewers. |
| 10.D Current-tree safety | PASS | Endpoint productivo sustituido por `smartdesk.example.com`; cero secretos o rutas personales detectados. |
| 10.D Git history safety | BLOCKED | Dos commits contienen la referencia histórica; requiere decisión humana y eventual rewrite autorizado antes de publicación. |
| 10.E Coherencia | PASS | Contexto, deployment, operaciones, roadmap, status y evaluación reconciliados. |
| 10.F Quickstart | PASS | `docs/QUICKSTART.md` documenta bootstrap, n8n, tests, evaluación y BI. |
| 10.G Fresh-clone static check | PASS parcial | Clon limpio: archivos, validator, 35 tests y dataset PASS; Docker/Bash no disponibles en el host local. CI hosted cubrió Compose y PostgreSQL. |
| 10.H Demo contract | PASS | Storyboard, safety, plan B y criterios de aceptación. |
| 10.I Fixtures | PASS | Cuatro tickets sintéticos LOW/MEDIUM/HIGH/CRITICAL; cero PII real. |
| 10.J Arquitectura | PASS | Mermaid funcional, red y operaciones basado en componentes existentes. |
| 10.K–L README | PASS | Ruta recruiter/técnica, métricas, limitaciones, quickstart y mapa documental. |
| 10.M Assets | PASS plan | Lista exacta de capturas; imágenes y video requieren trabajo manual. |
| 10.N Metrics | PASS | Claims permitidos y prohibidos enlazados a evidencia. |
| 10.O GitHub polish | PASS parcial | Descripción y topics actualizados; repo privado; sin homepage, release o licencia. |
| 10.P Secret scan | PASS árbol / BLOCKED historia | Cero secretos; endpoint ausente del árbol y presente en historia. |
| 10.Q Tests | PASS | Validator, 35 tests, dataset y links; CI hosted `36088293846` PASS sobre `e5259e5...`. |
| 10.V Endpoint rotation | PASS | Ruta pública nueva configurada externamente; E2E sintético único PASS; ruta histórica 404; hosted monitor `36152093510` PASS sobre `a711971...`. |
| 10.W Sanitized portfolio repository | PASS | Candidato privado con historia y refs saneadas, `v1.0` preservado, aislamiento productivo y CI hosted PASS. |
| 10.X Pre-publication preparation | READY FOR MANUAL ASSETS | MIT, guía exacta de seis capturas, demo ejecutable, CV-safe claims, release notes y checklist preparados; sin tag, release ni cambio de visibilidad. |

## Documentación vigente

- `README.md`: entrada recruiter y técnica;
- `docs/ARCHITECTURE.md`: flujo, límites y operación;
- `docs/QUICKSTART.md`: reproducción;
- `docs/DEMO.md`: demo segura;
- `docs/PORTFOLIO_ASSETS.md`: capturas pendientes;
- `docs/PORTFOLIO_METRICS.md`: claims autorizados;
- `STATUS.md`: estado actual;
- `docs/PHASE_X.md` y `docs/testing/GATE_X.md`: snapshots y evidencia.

## Bloqueantes para Gate 10

1. Las capturas y el video requieren producción manual desde un entorno demo
   aislado y una revisión cuadro por cuadro.
2. El README renderizado necesita revisión visual con los assets incorporados.
3. El propietario debe autorizar explícitamente tag, release y cambio de
   visibilidad.
4. Gate 10 requiere una revisión final después de resolver los puntos
   anteriores; este sprint no lo declara PASS.

## Phase 10.W–10.X — candidato y pre-publicación

`MACOABC/SmartDesk-AI-Portfolio` es el candidato sanitizado de portfolio.
Permanece privado, conserva `v1.0`, no tiene secrets ni environments
productivos y sus workflows operativos están bloqueados. El repositorio
privado original conserva la autoridad de deployment.

Phase 10.X añadió MIT License, un manual exacto para seis assets reales, un
guion demo de aproximadamente tres minutos, claims aptos para CV con fuentes,
release notes de `v1.1.0` y la checklist de publicación. `v1.1.0` está
preparada conceptualmente, pero no existe tag ni GitHub Release. El siguiente
estado es `READY FOR MANUAL ASSETS`; Gate 10 continúa pendiente.

## Phase 10.V — rotación del endpoint productivo

La ruta pública productiva fue reemplazada por un valor aleatorio conservado
únicamente en configuración externa. Caddy mantiene estable el webhook interno
de n8n, expone una sonda GET 204 sin efectos y solo reenvía POST en la ruta
vigente. La ruta histórica fue retirada y una petición GET segura devolvió
404, sin alcanzar el workflow.

La transición utilizó dos deployments manuales por SHA: preparación
`36151549502` y cierre `36151962190`. Una única prueba sintética creó el ticket
esperado, obtuvo predicción `succeeded` y evento `skipped`; consumió una llamada
OpenAI y no activó Telegram. El monitor alojado `36152093510`, disparado por
`workflow_dispatch`, terminó `success` con HTTP 204 y su log no contiene el
hostname ni la ruta privada.

`refs/pull/1/head` continúa conservando la referencia histórica. Phase 10.V no
reescribió historia, no hizo force push, no movió `v1.0`, no cambió la
visibilidad privada y no intentó resolver ese ref.

