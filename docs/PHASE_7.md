# SmartDesk AI — Phase 7: evaluación de IA

## Estado

Phase 7 está **COMPLETE** y Gate 7 **PASS**. Phase 7A creó el dataset sintético
versionado. Phase 7B implementó el harness y scoring offline; Phase 7B.2
completó un smoke live controlado sobre tres casos `dev`; Phase 7C completó la
única corrida oficial autorizada del test congelado v1. El usuario aprobó
formalmente Gate 7 el 2026-09-20 después de revisar la integridad,
reproducibilidad, métricas y limitaciones documentadas.

## Baseline y contrato

Phase 7B parte de `f486fe20b330430800f223c928febab1ac7303f6` y consume directamente:

- `prompts/ticket-classification/v2.md`;
- `prompts/ticket-classification/schema-v2.json`;
- OpenAI Responses API, `gpt-5.6-luna`;
- Structured Outputs estricto, `store=false`, `reasoning.effort=none`;
- `max_output_tokens=450` y timeout de 60 s;
- tres intentos, backoff 2 s/4 s y la lista transitoria de Phase 6;
- routing HITL `confidence < 0.75`.

El score `confidence` continúa explícitamente no calibrado.

## Arquitectura 7B

```text
dataset + manifest + schema de evaluación
  → validación integral y SHA-256
  → preflight de casos/llamadas/coste
  → request construido con contrato productivo
  → OpenAI Responses API [solo en run autorizado]
  → validación determinista del Structured Output
  → predictions.jsonl + attempts.jsonl + manifest.json
  → score_evaluation.py offline
  → metrics.json + cost.json
```

`run_evaluation.py` es el único módulo con capacidad de red.
`score_evaluation.py` usa solo archivos locales y biblioteca estándar. Los
tests sustituyen el transporte por fakes y bloquean red durante la prueba de
scoring offline.

## Decisiones metodológicas

- El runner no recibe una copia del prompt ni taxonomías por CLI: carga los
  artefactos versionados y registra sus hashes.
- Solo `area`, `title` y `description` entran al request. Las etiquetas y notas
  permanecen exclusivamente en el registro de evaluación.
- La latencia por caso incluye requests, validación y backoff. Las latencias de
  intento se conservan aparte.
- Los cuatro precios (input ordinario, lectura de caché, escritura de caché y
  output) no tienen defaults. Deben suministrarse con fuente y fecha de
  verificación al momento del run para evitar cifras históricas silenciosas.
- El preflight usa una cota conservadora basada en bytes UTF-8, framing,
  máximo de output y posibles retries.
- El coste observado separa las tres clases mutuamente excluyentes de input
  reportadas por Responses API. Si `cache_write_tokens` no viene reportado, se
  conserva como `null` y las métricas que exigen coste completo permanecen
  `null`; nunca se convierte silenciosamente en cero.
- El scorer recalcula el coste completamente offline desde contadores crudos y
  pricing del manifest, y rechaza contabilidad negativa o inconsistente.
- Los resultados se escriben después de cada intento/caso. Un run parcial
  conserva evidencia y no se sobrescribe.
- El test requiere un flag adicional explícito y siempre conserva validación
  de hash y presupuesto.

## Evidencia local de 7B

La suite cubre happy path, contrato estructurado, JSON/enum inválidos, error
permanente, red/timeout, retry exitoso, agotamiento, backoff, HITL, latencia,
tokens ordinarios, lectura/escritura de caché, mezcla de las tres clases,
output, ausencia e inconsistencia de contadores, coste, límites, aislamiento de
ground truth, run parcial, matrices, denominadores, exact match y recomputación
de scoring sin red/API key.

## Phase 7B.2 — Smoke live de integración

El run `smoke-dev-20260920T190351Z`, sobre el commit
`e5619c6ecdde6f7755fc58a8e763830a05356801`, ejecutó una sola vez los tres
primeros casos `dev`: `SD-EVAL-DEV-001`, `SD-EVAL-DEV-002` y
`SD-EVAL-DEV-003`. Los guardrails fueron `max_cases=3`, `max_api_calls=9` y
`max_cost_usd=0.02`; el preflight estimó una cota de USD 0.0114585.

Las tres llamadas recibieron HTTP 200 y finalizaron en el primer intento, sin
retries. Responses API devolvió `gpt-5.6-luna` y usage completo: 1362 tokens
de input ordinario, 0 cached read, 0 cache write, 181 output y 1543 totales.
El coste recalculado offline fue USD 0.0004896. El scorer ejecutado nuevamente
sin API key reprodujo exactamente los artefactos derivados.

Como observación no autoritativa, las tres categorías `access` coincidieron;
una prioridad `medium` coincidió y dos fueron predichas como `high`. Ningún
caso activó HITL. Estos resultados son exclusivamente **integration smoke /
non-authoritative**: tres casos no miden rendimiento, no fijan una baseline y
no aprueban Gate 7.

La evidencia saneada se conserva en
`eval/runs/smoke-dev-20260920T190351Z/`. SHA-256:

- `attempts.jsonl`: `c6ff6f7fea80e741e36bd7ad931722d0863562d818179b9e175711386b32e7ec`;
- `cost.json`: `40732a97ef6482a3a03b7e7afd15c2ed4a78693d0906021e0a5a19248ba3dbf5`;
- `manifest.json`: `847a1a8dc186af69ad5465934467e0935805f93bf23d8b70406829ac57d4bc18`;
- `metrics.json`: `8c06297ccef1f6cda920992ea835711f4cd740239dad4a8740baf5be44017e8e`;
- `predictions.jsonl`: `e2c0e4ed67b16ef55b2769f01c5dd82dc9caf2426aca6a87ff6deba671c41791`.

El digest del conjunto, calculado sobre líneas `filename:sha256` ordenadas, es
`97edcac38b63f6dc4b356d58b3d9da0217790d380720a0332a4f1ecb392ade7f`.

## Phase 7C — Evaluación oficial del frozen test v1

El run `official-test-v1-20260920T210544Z`, iniciado sobre el commit
`6936e7c3333e04781fad55c1086adeb9323e20db`, procesó una sola vez, en su orden
original, los 120 casos de `eval/datasets/v1/test.jsonl`. El SHA-256 antes y
después fue
`461a27c60c2c9d6f971e54a2fadc54dedd84f19f53f557ed3560735508ad76f6`.
Los límites fueron 120 casos, 360 llamadas y USD 0.50; el preflight calculó una
cota conservadora de USD 0.4564095.

Las 120 llamadas recibieron HTTP 200 en el primer intento. No hubo retries,
casos con error ni casos omitidos. El modelo solicitado y devuelto fue
`gpt-5.6-luna`; el contrato conservó Structured Outputs estricto,
`store=false`, `reasoning.effort=none`, 450 tokens máximos de salida, timeout
de 60 s y routing HITL `confidence < 0.75`.

### Métricas oficiales observadas

| Métrica | Resultado |
| --- | ---: |
| Category accuracy | 107/120 = 89.17% |
| Category macro-F1 | 88.72% |
| Priority accuracy | 92/120 = 76.67% |
| Priority macro-F1 | 78.55% |
| Exact match categoría + prioridad | 81/120 = 67.50% |
| Operational error rate | 0/120 = 0.00% |
| Review rate con threshold 0.75 | 0/120 = 0.00% |
| Automatic coverage | 120/120 = 100.00% |
| Accuracy auto-resolved | 81/120 = 67.50% |
| Error escapes | 39/120 = 32.50% |

`confidence` se mantuvo como score operacional no calibrado. Todos los valores
estuvieron entre 0.93 y 1.00; por ello ningún caso activó HITL con el threshold
productivo. Esto deja 39 exact matches incorrectos auto-resueltos y constituye
el principal hallazgo para la revisión de Gate 7. No se ajustó el threshold ni
ningún componente del contrato después de observar el test.

### Desglose por clase

| Categoría | Precision | Recall | F1 | Soporte |
| --- | ---: | ---: | ---: | ---: |
| access | 95.24% | 100.00% | 97.56% | 20 |
| hardware | 68.97% | 100.00% | 81.63% | 20 |
| software | 95.24% | 100.00% | 97.56% | 20 |
| network | 100.00% | 95.00% | 97.44% | 20 |
| service_request | 89.47% | 85.00% | 87.18% | 20 |
| other | 100.00% | 55.00% | 70.97% | 20 |

| Prioridad | Precision | Recall | F1 | Soporte |
| --- | ---: | ---: | ---: | ---: |
| low | 87.50% | 60.00% | 71.19% | 35 |
| medium | 63.41% | 72.22% | 67.53% | 36 |
| high | 77.78% | 90.32% | 83.58% | 31 |
| critical | 89.47% | 94.44% | 91.89% | 18 |

La matriz de categoría usa filas esperadas y columnas predichas en el orden
`access, hardware, software, network, service_request, other`:

```text
20  0  0  0  0  0
 0 20  0  0  0  0
 0  0 20  0  0  0
 0  1  0 19  0  0
 0  3  0  0 17  0
 1  5  1  0  2 11
```

La matriz de prioridad usa filas esperadas y columnas predichas en el orden
`low, medium, high, critical`:

```text
21 14  0  0
 3 26  7  0
 0  1 28  2
 0  0  1 17
```

Las confusiones dominantes fueron `other → hardware` (5),
`service_request → hardware` (3), `other → service_request` (2),
`low → medium` (14) y `medium → high` (7). Descriptivamente, la prioridad se
sobrestimó con frecuencia y la categoría residual `other` tuvo el recall más
bajo. No se identificó un ground truth objetivamente inválido durante esta
revisión; varios bordes son deliberadamente discutibles y permanecen
congelados como parte del dataset v1.

### Operación, coste y análisis secundario

La latencia end-to-end fue mean 1831.17 ms, p50 1504.76 ms, p95 4310.11 ms,
mínimo 1113.99 ms y máximo 6755.68 ms. Responses API reportó 53 709 tokens de
input ordinario, 0 cached read, 0 cache write, 7 705 output y 61 414 totales.
La contabilidad fue completa e internamente consistente en 120/120 casos. Con
precios Standard verificados el 2026-09-20, el coste real recalculado fue USD
0.0199878; los promedios por ticket intentado y clasificación válida fueron
ambos USD 0.000166565.

La sensibilidad se calculó offline sin cambiar la política productiva:

| Threshold | Review rate | Auto coverage | Auto accuracy | Error escapes |
| ---: | ---: | ---: | ---: | ---: |
| 0.50 | 0.00% | 100.00% | 67.50% | 39/120 (32.50%) |
| 0.60 | 0.00% | 100.00% | 67.50% | 39/120 (32.50%) |
| 0.70 | 0.00% | 100.00% | 67.50% | 39/120 (32.50%) |
| 0.75 | 0.00% | 100.00% | 67.50% | 39/120 (32.50%) |
| 0.80 | 0.00% | 100.00% | 67.50% | 39/120 (32.50%) |
| 0.85 | 0.00% | 100.00% | 67.50% | 39/120 (32.50%) |
| 0.90 | 0.00% | 100.00% | 67.50% | 39/120 (32.50%) |
| 0.95 | 0.83% | 99.17% | 68.07% | 38/119 (31.93%) |

Por dificultad, exact match fue 70.83% en `easy` (34/48), 60.42% en
`medium` (29/48) y 75.00% en `hard` (18/24). Por `scenario_type`, los grupos
con más errores exactos fueron `normal` (15/52), `category_boundary` (6/19),
`irrelevant_context` (5/6) y `priority_boundary` (4/15). Las tasas de grupos
muy pequeños, como `natural_language` 2/2 con error, no sustentan conclusiones
generales.

El scorer se volvió a ejecutar sin API key y con salida de red bloqueada.
`metrics.json` y `cost.json` se reprodujeron exactamente salvo
`generated_at`. La evidencia final se conserva en
`eval/runs/official-test-v1-20260920T210544Z/`. SHA-256:

- `attempts.jsonl`: `30f69c840bc48a20cac672082393bff19a3c3c5a70063887aa969b7c03c41107`;
- `cost.json`: `7d64fcb7315b423adf15723d935ed2be5af71ee237dd61c1622207681c699ee3`;
- `manifest.json`: `e59d51c3a85901b0867b9c5ca37430412f18bb2f1182782952b77bb556add903`;
- `metrics.json`: `f3f9edfb3d214a932af455d16701517875c2896cc6a6d3b6e531e5c7d07180e7`;
- `predictions.jsonl`: `76e9937265ec0f9bcab9e818621c26b1708566eaeadb6dbc29a64c2288544277`.

El digest del conjunto, calculado como en el smoke sobre líneas
`filename:sha256` ordenadas, es
`83c278ae1046643dde5a5efcec22009444b58c9d6691c9a4e5dc91a4d4f0ca45`.

## Cierre formal

Gate 7 queda **PASS** y Phase 7 **COMPLETE**. La aprobación reconoce que la
evaluación oficial se ejecutó una sola vez sobre 120/120 casos, con evidencia
completa y reproducible, sin modificar después del test el dataset, prompt,
schema, modelo, configuración ni threshold HITL productivo. Las limitaciones
observadas —sobreestimación de prioridad, confusión de asuntos no TI con
`hardware` y confidence no calibrado— permanecen como hallazgos documentados y
no invalidan la evaluación.

La fase actual pasa administrativamente a Phase 8, que permanece **NOT
STARTED**. Este cierre no incluye diseño ni implementación de Phase 8.
