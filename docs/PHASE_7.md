# SmartDesk AI — Phase 7: evaluación de IA

## Estado

Phase 7 permanece **IN PROGRESS** y Gate 7 **NOT YET PASS**. Phase 7A creó el
dataset sintético versionado. Phase 7B implementó el harness y scoring offline;
Phase 7B.2 completó un smoke live controlado sobre tres casos `dev`. El test
congelado no se ejecutó.

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

## Próxima decisión

El smoke confirma que el harness está técnicamente listo para solicitar una
autorización separada de Phase 7C: una única corrida formal del test congelado.
Phase 7C no está autorizada ni iniciada por esta evidencia.
