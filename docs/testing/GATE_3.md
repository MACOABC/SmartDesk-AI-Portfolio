# Evidencia en progreso — Gate 3

## Estado

- **Fecha de la evidencia disponible:** 2026-09-17.
- **Gate 3 status: IN PROGRESS.**
- **Alcance verificado:** contrato versionado de clasificación y base de persistencia PostgreSQL.

Gate 3 no está aprobado ni cerrado. Este documento registra únicamente la evidencia ejecutada hasta este checkpoint.

## Base del contrato

El contrato V1 está versionado mediante:

- prompt `ticket-classification-v1` en `prompts/ticket-classification/v1.md`;
- schema `ticket-classification-schema-v1` en `prompts/ticket-classification/schema-v1.json`.

La salida contiene exactamente:

- `category`;
- `priority`;
- `summary`.

El schema exige `type: object`, los tres campos requeridos y `additionalProperties: false`.

Categorías aprobadas:

- `access`;
- `hardware`;
- `software`;
- `network`;
- `service_request`;
- `other`.

Prioridades aprobadas:

- `low`;
- `medium`;
- `high`;
- `critical`.

Las validaciones locales comprobaron sintaxis JSON, identificadores, campos requeridos, enums, límite de `summary`, ausencia de propiedades adicionales, reglas del prompt y ausencia de material sensible. Resultado: **PASS**.

## Base de persistencia

- **Migración:** `db/migrations/002_create_ticket_ai_predictions.sql`.
- **SHA-256 aplicado:** `95c3869b69509924700d3f030af1f141e4d6daabc0a2406fc15c2ab3d18a1203`.
- **Base objetivo:** `smartdesk_db`.
- **Tabla creada:** `public.ticket_ai_predictions`.

Resultado real de la aplicación:

```text
BEGIN
CREATE TABLE
CREATE INDEX
COMMIT
```

La estructura verificada en el catálogo de PostgreSQL contiene:

- 13 columnas;
- primary key sobre `id`;
- foreign key `ticket_id → public.tickets(id)` con `ON DELETE RESTRICT`;
- 10 restricciones `CHECK`;
- índice `(ticket_id, created_at DESC)`;
- múltiples predicciones permitidas por ticket, sin `UNIQUE(ticket_id)`.

Se ejecutaron 27 controles reales de integridad directamente contra PostgreSQL:

- 4 casos que debían aceptarse;
- 21 casos que debían rechazarse;
- protección `ON DELETE RESTRICT`;
- comprobación de que `updated_at` requiere actualización explícita.

Resultado: **27/27 PASS**.

Todos los datos usados fueron sintéticos. Las pruebas se ejecutaron dentro de una transacción que terminó con `ROLLBACK`.

Estado final comprobado:

```text
synthetic_tickets_remaining=0
synthetic_predictions_remaining=0
prediction_rows=0
predictions_table_exists=true
```

## Pendiente para cerrar Gate 3

- Hacer disponibles el prompt y el schema versionados dentro de n8n en modo de solo lectura.
- Implementar validación determinista de la salida en el workflow.
- Seleccionar y configurar de forma segura el proveedor y el modelo.
- Ejecutar una llamada real a la API de IA.
- Persistir predicciones desde n8n.
- Manejar de forma controlada fallos del proveedor, respuestas inválidas y fallos de persistencia.
- Ejecutar y documentar las pruebas end-to-end de Fase 3.

## Límites de esta evidencia

- No se llamó ninguna API de IA.
- No se seleccionó proveedor ni modelo.
- No se configuraron credenciales de IA.
- n8n y Docker Compose no fueron modificados en estos pasos.
- Esta evidencia no mide precisión, rendimiento, disponibilidad ni impacto de producción.
