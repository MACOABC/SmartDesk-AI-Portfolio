# SmartDesk AI — Modelo Power BI

## Tablas y relaciones

```text
FactTickets[ticket_id] (1)
    ├── (*) FactAIPredictions[ticket_id]
    ├── (*) FactHITLReviews[ticket_id]
    └── (*) FactAutomationEvents[ticket_id]
```

Crear las tres relaciones como activas, uno-a-muchos y con filtro en una sola
dirección desde `FactTickets` hacia cada tabla hija.

No crear relaciones entre las tres tablas hijas. Aunque existen IDs físicos
compartidos, añadirlos produciría rutas de filtro ambiguas. La vista HITL ya
contiene la prediction y decisión exactas necesarias para analizar cambios.

Verificar antes de continuar:

```text
FactTickets[ticket_id] = unique and non-null
FactAIPredictions[prediction_id] = unique and non-null
FactHITLReviews[review_id] = unique and non-null
FactAutomationEvents[event_id] = unique and non-null
```

No se necesita many-to-many. Una `DimDate` es opcional; para el primer
template se recomienda omitirla y usar `ticket_created_at` directamente.

## Tipos recomendados

- IDs, statuses, categorías, prioridades, versiones y códigos: Text.
- Timestamps `*_at`: Date/Time/Timezone según disponibilidad del conector.
- Confidence y `resolution_minutes`: Decimal number.
- Attempt count: Whole number.
- `review_required`, `category_changed`, `priority_changed`: True/False con
  NULL preservado.

No sustituir NULL por cero o `false` cuando represente ausencia de evidencia.

## Páginas

### 1 — Operations Overview

Cards: Total Tickets, Resolved Tickets, Open Tickets y SLA Breached.

Visuales: tickets por fecha de creación, área, categoría final, prioridad
final y estado. Slicers: fecha, área, categoría final, prioridad final y
estado.

### 2 — AI & Human Review

Cards: Prediction Attempts, Prediction Success Rate, Persisted Reviews,
Completed Reviews y Override Rate.

Visuales: predictions por estado, categoría, prioridad, modelo, prompt y error;
distribución de confidence; category/priority changes en HITL.

Etiquetar confidence como señal operacional no calibrada. No usar la palabra
accuracy para agreement u overrides.

### 3 — SLA & Automation

Cards: SLA Assigned, SLA Breached, SLA Breach Rate, Resolved Tickets y Median
Resolution Minutes.

Visuales: SLA por estado; breaches por prioridad final; resolution minutes por
prioridad/categoría final; eventos por estado; fallos por error code.

## Filtros de comprobación

Validar al menos:

1. un área con tickets conocidos;
2. cada estado de ticket persistido;
3. una categoría final;
4. una prioridad final;
5. un rango de fecha de creación.

Cada selección debe reconciliarse con SQL sobre las mismas vistas.
