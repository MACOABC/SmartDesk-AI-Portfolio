# SmartDesk AI — Registro de métricas y claims

Fuente autorizada para README, CV, LinkedIn, demo y entrevista. Una cifra solo
puede usarse junto con su contexto y caveat. Los conteos operacionales de Gate
8 no representan impacto empresarial.

## Claims permitidos

| Claim | Value | Evidence | Allowed usage | Caveat |
| --- | ---: | --- | --- | --- |
| Intake contract | 30/30 solicitudes | `docs/testing/GATE_2.md` | README, entrevista | Batería E2E controlada, no volumen productivo. |
| Integridad de IA/persistencia | 27/27 checks | `docs/testing/GATE_3.md` | README técnico, entrevista | Pruebas de contrato e integridad. |
| Intake regression | 30/30 | `docs/testing/GATE_3.md` | README técnico | Regresión controlada. |
| Reglas de negocio | 19/19 validaciones | `docs/testing/GATE_4.md` | README, CV, entrevista | Casos deterministas; no precisión del modelo. |
| Aceptación V1 desplegada | 6 escenarios | `docs/testing/GATE_5.md` | README, entrevista | Escenarios de aceptación, no tráfico real. |
| Reliability/HITL/SLA | G6.1–G6.22 PASS | `docs/testing/GATE_6.md` | README técnico, entrevista | Capacidad funcional; no acredita mejora de accuracy ni SLA empresarial. |
| Dataset oficial | 120 casos sintéticos congelados | `eval/datasets/v1/dataset-manifest.json` | README, CV, LinkedIn | Sin datos productivos. |
| Clasificaciones válidas | 120/120 | `eval/runs/official-test-v1-20260920T210544Z/metrics.json` | README, CV | Benchmark sintético. |
| Category accuracy | 89.17% | `docs/PHASE_7.md` y `metrics.json` | README, CV, LinkedIn | Modelo y dataset de la corrida del 2026-09-20. |
| Category macro-F1 | 88.72% | `docs/PHASE_7.md` y `metrics.json` | README técnico, entrevista | Mismo benchmark sintético. |
| Priority accuracy | 76.67% | `docs/PHASE_7.md` y `metrics.json` | README, CV, LinkedIn | Mismo benchmark sintético. |
| Priority macro-F1 | 78.55% | `docs/PHASE_7.md` y `metrics.json` | README técnico, entrevista | Mismo benchmark sintético. |
| Exact match | 67.50% | `docs/PHASE_7.md` y `metrics.json` | README, entrevista | Categoría y prioridad correctas simultáneamente. |
| Latencia mean | 1831.17 ms | `docs/PHASE_7.md` y `metrics.json` | README técnico, entrevista | End-to-end del runner, no SLA productivo. |
| Latencia p50 / p95 | 1504.76 / 4310.11 ms | `docs/PHASE_7.md` y `metrics.json` | README, entrevista | Mismo benchmark. |
| Errores operacionales | 0/120 | `docs/PHASE_7.md` y `metrics.json` | README técnico | No significa cero errores de clasificación. |
| Tokens | 61,414 | `eval/runs/official-test-v1-20260920T210544Z/cost.json` | Análisis técnico | Solo la corrida oficial. |
| Coste benchmark | USD 0.0199878 total; USD 0.000166565/caso | `cost.json` y `docs/PHASE_7.md` | Entrevista, análisis técnico | Pricing verificado el 2026-09-20; no proyectar gasto productivo. |
| HITL reviews | 0/120 | `docs/PHASE_7.md` y `metrics.json` | README, entrevista | Limitación: el threshold no discriminó errores. |
| HITL error escapes | 39/120 = 32.50% | `docs/PHASE_7.md` y `metrics.json` | README, entrevista | Debe acompañar cualquier explicación del confidence/HITL. |
| Analytics | 4 vistas | `db/migrations/005_phase8_analytics_views.sql` y `docs/testing/GATE_8.md` | README, CV | Capa operacional; no warehouse. |
| Power BI | 3 relaciones activas, 3 páginas, template `.pbit` | `docs/testing/GATE_8.md` y `powerbi/SmartDeskAI.pbit` | README, CV, demo | Template sin datos importados. |
| Reconciliación prediction | 9 success, 4 failed, 69.23% | `docs/PHASE_8.md` | Solo evidencia técnica Gate 8 | Dataset operacional pequeño; no usar como KPI empresarial. |
| CI offline | 35/35 tests | `docs/testing/GATE_9.md` y GitHub Actions | README, CV | Suite del repositorio. |
| Negative CI / recovery | FAIL esperado → PASS | GitHub runs `36079465259` y `36079518418` | README, entrevista | Prueba controlada, no incidente productivo. |
| CD por SHA | PASS sobre SHA exacto | GitHub run `36080435344` y `docs/testing/GATE_9.md` | README, entrevista | Environment sin required reviewers. |
| Backup/restore | PASS aislado y cifrado | `docs/testing/GATE_9.md` | README, CV | Evidencia de drill; no mide RPO/RTO continuo. |
| Hosted monitor | PASS, status esperado 404 | GitHub run `36087544636` | README técnico | GET seguro; no crea tickets ni acredita disponibilidad histórica. |

## Claims no permitidos

| Claim | Estado | Uso |
| --- | --- | --- |
| “Redujo el tiempo de soporte en X%” | NOT VERIFIED | DO NOT USE |
| “Ahorró X horas o USD” | NOT VERIFIED | DO NOT USE |
| “Procesó miles de tickets” | NOT VERIFIED | DO NOT USE |
| “Tiene usuarios/clientes en producción” | NOT VERIFIED | DO NOT USE |
| “HITL mejora la precisión del modelo” | CONTRADICTED BY BENCHMARK | DO NOT USE |
| “Confidence es probabilidad calibrada” | FALSE FOR THIS PROJECT | DO NOT USE |
| “99.9% availability” o cualquier uptime | NOT VERIFIED | DO NOT USE |
| “Enterprise-grade” o “completamente seguro” | NOT VERIFIED / demasiado absoluto | DO NOT USE |
| “Power BI demuestra impacto empresarial” | NOT VERIFIED | DO NOT USE |
| “v1.0 es el HEAD actual” | FALSE | DO NOT USE |

## Regla de actualización

Una nueva cifra requiere artefacto reproducible, fecha, configuración, alcance
y caveat. No sustituir ni redondear resultados históricos para mejorar la
narrativa. Si la evidencia cambia, añadir una nueva medición y conservar la
anterior como snapshot.

