# SmartDesk AI — Medidas DAX

Las medidas siguientes agregan columnas ya definidas en PostgreSQL. No
reimplementan reglas de negocio.

```DAX
Tickets :=
DISTINCTCOUNT(FactTickets[ticket_id])
```

```DAX
Resolved Tickets :=
CALCULATE(
    DISTINCTCOUNT(FactTickets[ticket_id]),
    NOT ISBLANK(FactTickets[resolved_at])
)
```

```DAX
Open Tickets :=
CALCULATE(
    DISTINCTCOUNT(FactTickets[ticket_id]),
    FactTickets[ticket_status] = "open"
)
```

```DAX
SLA Assigned :=
CALCULATE(
    DISTINCTCOUNT(FactTickets[ticket_id]),
    NOT ISBLANK(FactTickets[sla_id])
)
```

```DAX
SLA Breached :=
CALCULATE(
    DISTINCTCOUNT(FactTickets[ticket_id]),
    FactTickets[sla_status] = "breached"
)
```

```DAX
SLA Breach Rate :=
DIVIDE([SLA Breached], [SLA Assigned])
```

```DAX
Average Resolution Minutes :=
AVERAGE(FactTickets[resolution_minutes])
```

```DAX
Median Resolution Minutes :=
MEDIAN(FactTickets[resolution_minutes])
```

```DAX
Prediction Attempts :=
COUNTROWS(FactAIPredictions)
```

```DAX
Successful Predictions :=
CALCULATE(
    COUNTROWS(FactAIPredictions),
    FactAIPredictions[prediction_status] = "succeeded"
)
```

```DAX
Failed Predictions :=
CALCULATE(
    COUNTROWS(FactAIPredictions),
    FactAIPredictions[prediction_status] = "failed"
)
```

```DAX
Terminal Prediction Attempts :=
[Successful Predictions] + [Failed Predictions]
```

```DAX
Prediction Success Rate :=
DIVIDE(
    [Successful Predictions],
    [Terminal Prediction Attempts]
)
```

`Prediction Success Rate` es una métrica de filas de prediction. No representa
el porcentaje de tickets resueltos correctamente.

```DAX
Persisted Reviews :=
COUNTROWS(FactHITLReviews)
```

```DAX
Completed Reviews :=
CALCULATE(
    COUNTROWS(FactHITLReviews),
    FactHITLReviews[review_status] IN { "approved", "overridden" }
)
```

```DAX
Pending Reviews :=
CALCULATE(
    COUNTROWS(FactHITLReviews),
    FactHITLReviews[review_status] = "pending"
)
```

```DAX
Category Overrides :=
CALCULATE(
    COUNTROWS(FactHITLReviews),
    FactHITLReviews[category_changed] = TRUE()
)
```

```DAX
Priority Overrides :=
CALCULATE(
    COUNTROWS(FactHITLReviews),
    FactHITLReviews[priority_changed] = TRUE()
)
```

```DAX
Overridden Reviews :=
CALCULATE(
    COUNTROWS(FactHITLReviews),
    FactHITLReviews[review_status] = "overridden"
)
```

```DAX
Override Rate :=
DIVIDE([Overridden Reviews], [Completed Reviews])
```

```DAX
Automation Events :=
COUNTROWS(FactAutomationEvents)
```

```DAX
Succeeded Events :=
CALCULATE(
    COUNTROWS(FactAutomationEvents),
    FactAutomationEvents[event_status] = "succeeded"
)
```

```DAX
Failed Events :=
CALCULATE(
    COUNTROWS(FactAutomationEvents),
    FactAutomationEvents[event_status] = "failed"
)
```

```DAX
Skipped Events :=
CALCULATE(
    COUNTROWS(FactAutomationEvents),
    FactAutomationEvents[event_status] = "skipped"
)
```

## Valores de referencia actuales

Antes de aplicar filtros, la ejecución SQL de Gate 8 produjo:

| Medida | Valor PostgreSQL |
| --- | ---: |
| Tickets | 13 |
| Resolved Tickets | 1 |
| SLA Assigned | 5 |
| SLA Breached | 3 |
| SLA Breach Rate | 0.600000 |
| Prediction Attempts | 13 |
| Successful Predictions | 9 |
| Failed Predictions | 4 |
| Prediction Success Rate | 0.692308 |
| Persisted Reviews | 2 |
| Completed Reviews | 2 |
| Pending Reviews | 0 |
| Category Overrides | 0 |
| Priority Overrides | 1 |
| Override Rate | 0.500000 |
| Automation Events | 12 |
| Succeeded Events | 6 |
| Failed Events | 1 |
| Skipped Events | 5 |

Estos valores son evidencia de reconciliación SQL, no evidencia de refresh en
Power BI. Deben volver a calcularse si cambia la base antes de construir el
template.
