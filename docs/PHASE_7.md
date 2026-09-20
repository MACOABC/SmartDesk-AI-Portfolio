# SmartDesk AI — Phase 7: evaluación de IA

## Estado

Phase 7 permanece **IN PROGRESS** y Gate 7 **NOT YET PASS**. Phase 7A creó el
dataset sintético versionado. Phase 7B implementó el harness y scoring offline,
pero no realizó llamadas reales ni ejecutó el test congelado.

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
- Los precios no tienen defaults. Deben suministrarse con fuente/fecha al
  momento del run para evitar cifras históricas silenciosas.
- El preflight usa una cota conservadora basada en bytes UTF-8, framing,
  máximo de output y posibles retries.
- El coste observado usa usage real. Si falta usage, las métricas que exigen
  coste completo permanecen `null`.
- Los resultados se escriben después de cada intento/caso. Un run parcial
  conserva evidencia y no se sobrescribe.
- El test requiere un flag adicional explícito y siempre conserva validación
  de hash y presupuesto.

## Evidencia local de 7B

La suite cubre happy path, contrato estructurado, JSON/enum inválidos, error
permanente, red/timeout, retry exitoso, agotamiento, backoff, HITL, latencia,
tokens, coste, límites, aislamiento de ground truth, run parcial, matrices,
denominadores, exact match y scoring sin red/API key.

No se generó evidencia de accuracy, latencia de proveedor, coste real ni
calibración. Esas mediciones pertenecen a una corrida posterior autorizada.

## Próxima decisión

Antes de una evaluación formal conviene una sola corrida live de tres casos
`dev`, con precios oficiales verificados, preflight y presupuesto explícito.
Su objetivo sería validar autenticación, forma real de Responses API, usage y
artefactos, no estimar accuracy. No se ejecutó durante Phase 7B.
