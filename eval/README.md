# Evaluación de IA — Phase 7

Este directorio contiene el dataset y el harness reproducible para evaluar el
clasificador de SmartDesk AI sin modificar el producto. Phase 7A creó el corpus
y Phase 7B implementó runner, scoring offline y guardrails. No se realizaron
llamadas reales durante 7B. Phase 7 continúa **IN PROGRESS** y Gate 7 permanece
**NOT YET PASS**.

## Contrato evaluado

- commit base: `f03f2ca136868486b6d4e8180a562d1ba448119c`;
- prompt: `ticket-classification-v2`;
- schema: `ticket-classification-schema-v2`;
- proveedor/modelo previsto para la ejecución posterior: OpenAI Responses API,
  `gpt-5.6-luna`;
- salida de interés en 7A: `category` y `priority` contra ground truth;
- `confidence` se medirá después como señal operacional no calibrada y el
  routing HITL vigente es `confidence < 0.75`.

## Contenido

```text
eval/
├── README.md
├── labeling-policy-v1.md
├── datasets/v1/
│   ├── dev.jsonl
│   ├── test.jsonl
│   └── dataset-manifest.json
├── schemas/evaluation-case.schema.json
├── scripts/build_dataset_v1.py
├── scripts/validate_dataset.py
├── scripts/run_evaluation.py
├── scripts/score_evaluation.py
├── tests/
│   ├── test_validate_dataset.py
│   ├── test_run_evaluation.py
│   └── test_score_evaluation.py
└── runs/.gitkeep
```

Cada línea JSONL es un objeto independiente con entrada sintética, etiqueta
esperada y notas de ground truth. No contiene nombres, correos, identificadores
reales ni datos tomados de producción.

## Uso local

Requiere Python 3.10 o superior y solo la biblioteca estándar:

```bash
python eval/scripts/validate_dataset.py
python -m unittest discover -s eval/tests -v
```

El validador comprueba schema, campos obligatorios, enums contra el contrato
productivo, IDs y splits, unicidad global, duplicados de contenido, similitud
excesiva, conteos 30/120, distribución exacta de 20 casos de test por
categoría, coherencia del manifiesto y hashes SHA-256.

`build_dataset_v1.py` conserva la autoría explícita y permite comprobar que los
JSONL y el manifiesto se materializan de forma determinista. No debe editarse
ni usarse para cambiar el test `v1` congelado: cualquier cambio de caso, split,
política o etiqueta exige una nueva versión del dataset.

## Preflight y guardrails

Un run requiere límites y precios explícitos; no existen valores monetarios
por defecto que puedan quedar obsoletos. Los valores deben verificarse en la
fuente oficial de precios de OpenAI inmediatamente antes de una corrida y la
referencia usada debe quedar en `--pricing-source`.

Referencia verificada el `2026-09-20` para `gpt-5.6-luna`, procesamiento
Standard, por 1 000 000 de tokens: input ordinario USD 0.20, lectura de caché
USD 0.02, escritura de caché USD 0.25 y output USD 1.20. La fuente autoritativa
es la [página del modelo](https://developers.openai.com/api/docs/models/gpt-5.6-luna)
y la [tabla de precios](https://developers.openai.com/api/docs/pricing). Estos
valores son referencia documentada, no defaults del CLI; deben volver a
verificarse antes de cada run.

El preflight no necesita API key ni crea un directorio de run:

```bash
python eval/scripts/run_evaluation.py \
  --dataset eval/datasets/v1/dev.jsonl \
  --max-cases 5 \
  --max-api-calls 15 \
  --max-cost-usd MAX_USD_APROBADO \
  --input-price-per-million-usd PRECIO_INPUT_VIGENTE \
  --cached-input-price-per-million-usd PRECIO_CACHED_INPUT_VIGENTE \
  --cache-write-price-per-million-usd PRECIO_CACHE_WRITE_VIGENTE \
  --output-price-per-million-usd PRECIO_OUTPUT_VIGENTE \
  --pricing-source FUENTE_O_VERSION_DE_PRECIOS \
  --pricing-verification-date YYYY-MM-DD \
  --preflight-only
```

También se aceptan `EVAL_MAX_CASES`, `EVAL_MAX_API_CALLS`, `EVAL_MAX_USD`,
`EVAL_INPUT_PRICE_PER_1M_USD`, `EVAL_CACHED_INPUT_PRICE_PER_1M_USD`,
`EVAL_CACHE_WRITE_PRICE_PER_1M_USD`, `EVAL_OUTPUT_PRICE_PER_1M_USD`,
`EVAL_PRICING_SOURCE` y `EVAL_PRICING_VERIFICATION_DATE`.

El límite conservador de input es el tamaño UTF-8 del request completo más 512
tokens de framing. El coste máximo pre-run usa para todo ese input el mayor
precio entre input ordinario y escritura de caché,
`max_output_tokens=450`, hasta tres intentos por caso y nunca más de
`max_api_calls`. El run se rechaza si esa cota supera `max_cost_usd`. Antes de
cada request también se reserva su cota; alcanzar el límite detiene el run de
forma controlada.

## Ejecutar el runner

La API key solo se lee desde `OPENAI_API_KEY` —o desde el nombre indicado por
`--api-key-env`— y nunca se acepta como argumento, se escribe en artefactos ni
se incluye en logs. Ejemplo para un futuro smoke autorizado de tres casos dev:

```bash
python eval/scripts/run_evaluation.py \
  --dataset eval/datasets/v1/dev.jsonl \
  --max-cases 3 \
  --max-api-calls 9 \
  --max-cost-usd MAX_USD_APROBADO \
  --input-price-per-million-usd PRECIO_INPUT_VIGENTE \
  --cached-input-price-per-million-usd PRECIO_CACHED_INPUT_VIGENTE \
  --cache-write-price-per-million-usd PRECIO_CACHE_WRITE_VIGENTE \
  --output-price-per-million-usd PRECIO_OUTPUT_VIGENTE \
  --pricing-source FUENTE_O_VERSION_DE_PRECIOS \
  --pricing-verification-date YYYY-MM-DD
```

El request consume directamente `prompts/ticket-classification/v2.md` y
`schema-v2.json`; no existe una copia alternativa del contrato. Solo envía
`area`, `title` y `description` dentro de `<untrusted_ticket_data>`. Ground
truth, dificultad, tipo de escenario y notas nunca forman parte del request.

`test.jsonl` se rechaza salvo que una corrida oficial futura incluya además
`--allow-frozen-test`. Ese flag no omite hash, presupuesto, límites ni el resto
de validaciones. Un run ID nunca sobrescribe un directorio existente.

## Evidencia por run

Cada corrida aceptada crea `eval/runs/<run_id>/`:

```text
manifest.json       configuración, hashes, límites, preflight y estado final
predictions.jsonl   un resultado terminal por caso intentado
attempts.jsonl      un registro saneado por llamada API
metrics.json        scoring reproducible
cost.json           pricing, estimación pre-run y coste observado
```

El manifest registra commit Git; path, versión y SHA-256 del dataset; path,
versión y SHA-256 de prompt/schema; endpoint, provider, modelo solicitado y
modelos devueltos; `store`, reasoning, Structured Outputs, timeout y output
máximo; retries; HITL; precios; límites; versión de Python y terminación. Se
escribe inicialmente como `running`, se actualiza incrementalmente y queda como
evidencia final. Un run interrumpido conserva los JSONL ya escritos.

Cada línea de `predictions.jsonl` incluye IDs, ground truth, predicción y
correctitud; `confidence_raw`; routing HITL; estado/error; intentos; latencia;
tokens; coste; response ID y modelo devuelto. No guarda prompts de respuesta
ocultos, chain-of-thought, headers, API keys ni cuerpos de error.

`latency_ms` es el tiempo end-to-end del caso medido con reloj monotónico desde
antes del primer intento hasta la validación o error final. Incluye todos los
intentos y los backoffs de 2 s/4 s. `attempts.jsonl` conserva además latencia
por request.

Responses API reporta escritura de caché en
`usage.input_tokens_details.cache_write_tokens`. El coste observado aplica:

```text
regular_input_tokens = input_tokens - cached_tokens - cache_write_tokens

(regular_input_tokens × input_price
 + cached_tokens × cached_read_price
 + cache_write_tokens × cache_write_price
 + output_tokens × output_price) / 1_000_000
```

Los contadores deben ser enteros no negativos; las tres clases de input deben
sumar `input_tokens` y `total_tokens` debe ser input más output. Si falta
`cache_write_tokens`, se registra explícitamente
`cache_write_tokens_not_reported`, el valor queda `null` y no se interpreta
como cero. Si falta usage o la contabilidad es inconsistente para cualquier
intento, el coste total y los promedios que lo requieren quedan `null`; se
informa solo el coste conocido sin inventar el faltante.

## Scoring completamente offline

Una corrida se puede puntuar nuevamente sin API key, Internet, n8n,
PostgreSQL ni Telegram:

```bash
python eval/scripts/score_evaluation.py \
  --predictions eval/runs/RUN_ID/predictions.jsonl \
  --manifest eval/runs/RUN_ID/manifest.json
```

El scorer recalcula el coste desde los contadores crudos y los cuatro precios
del manifest; no confía en el coste previamente escrito en la predicción y no
usa red. También calcula accuracy, precision, recall y F1 por clase, macro-F1 y matriz
de confusión para categoría; accuracy, métricas por prioridad y su matriz;
exact match conjunto; review rate, auto coverage, accuracy de auto-resueltos y
del subconjunto HITL, y errores que escaparon. También reporta fallos,
intentos/retries, agotamiento, latencia mean/p50/p95/min/max, tokens y coste.

Denominadores:

- accuracy: predicciones correctas / clasificaciones válidas;
- error operacional: casos con error / casos intentados;
- review rate y auto coverage: clasificaciones válidas;
- accuracy HITL/auto: exact match conjunto dentro de cada subconjunto;
- error escapado: exact match incorrecto sin HITL;
- error escape rate: errores escapados / auto-resueltos.

`dataset_cases`, `attempted_cases`, `valid_classifications`, `errored_cases` y
casos no intentados quedan visibles. Un fallo no desaparece del denominador
operacional.

## Contrato operacional reproducido

- tres intentos máximos;
- backoff de 2 s antes del segundo y 4 s antes del tercero;
- retry únicamente para red/timeout/status 0 y HTTP 408, 425, 429, 500, 502,
  503 y 504;
- errores permanentes o Structured Output inválido no se reintentan;
- HITL exactamente cuando `confidence < 0.75`;
- `confidence` es un score operacional no calibrado, no una probabilidad.

## Protocolo oficial futuro

1. Verificar Git limpio, commit, contrato y hashes del dataset.
2. Verificar precios vigentes y registrar fuente/fecha exactas.
3. Ejecutar y aprobar `validate_dataset.py` y toda la suite local.
4. Ejecutar primero `--preflight-only` con límites explícitos.
5. Si se autoriza integración real, realizar una sola corrida pequeña sobre
   `dev`; no repetirla automáticamente.
6. Revisar artefactos, errores, coste y aislamiento antes del test oficial.
7. Ejecutar `test` una sola vez, con flag explícito, protocolo y presupuesto
   aprobados. No usar sus resultados para ajustar el mismo contrato y volver a
   presentar la misma versión como medición independiente.
8. Recalcular métricas offline y verificar nuevamente el SHA-256 sellado.

Phase 7B tampoco ejecutó el modelo ni produjo métricas reales. El harness listo
no autoriza por sí mismo el cierre de Gate 7.
