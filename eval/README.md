# Evaluación de IA — Phase 7A

Este directorio contiene la base reproducible para evaluar el clasificador de
SmartDesk AI sin modificar el producto ni llamar todavía a la API oficial.
Phase 7 continúa **IN PROGRESS** y Gate 7 permanece **NOT YET PASS**.

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
├── scripts/validate_dataset.py
├── tests/test_validate_dataset.py
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

## Protocolo de uso

1. Usar `dev` para probar el runner y decidir cambios antes de la medición.
2. No inspeccionar resultados de `test` para iterar sobre el prompt dentro de
   la misma versión.
3. Verificar hashes antes y después de cada corrida.
4. Guardar resultados posteriores bajo `eval/runs/` sin sobrescribir corridas.
5. No versionar respuestas que contengan secretos o datos reales.

7A no ejecuta el modelo, no produce métricas de accuracy/latencia/costo y no
autoriza el cierre de Gate 7.
