# SmartDesk AI — Medidas DAX

Las medidas siguientes agregan columnas ya definidas en PostgreSQL. No
reimplementan reglas de negocio.

```DAX
Total Tickets :=
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
Prediction Success Rate :=
DIVIDE(
    [Successful Predictions],
    [Successful Predictions] + [Failed Predictions]
)
```

`Prediction Success Rate` es una métrica de filas de prediction. No representa
el porcentaje de tickets resueltos correctamente.

```DAX
Reviews :=
COUNTROWS(FactHITLReviews)
```

```DAX
Completed Reviews :=
CALCULATE(
    COUNTROWS(FactHITLReviews),
    NOT ISBLANK(FactHITLReviews[review_decided_at])
)
```

`review_status` persiste `approved` u `overridden`; no existe un estado
`completed`. La medida usa el timestamp persistido de decisión para contar
reviews completadas.

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
Reviews With Override :=
CALCULATE(
    COUNTROWS(FactHITLReviews),
    FactHITLReviews[review_status] = "overridden"
)
```

```DAX
Override Rate :=
DIVIDE([Reviews With Override], [Completed Reviews])
```

```DAX
Automation Events :=
COUNTROWS(FactAutomationEvents)
```

```DAX
Automation Succeeded :=
CALCULATE(
    COUNTROWS(FactAutomationEvents),
    FactAutomationEvents[event_status] = "succeeded"
)
```

```DAX
Automation Failed :=
CALCULATE(
    COUNTROWS(FactAutomationEvents),
    FactAutomationEvents[event_status] = "failed"
)
```

```DAX
Automation Skipped :=
CALCULATE(
    COUNTROWS(FactAutomationEvents),
    FactAutomationEvents[event_status] = "skipped"
)
```

## Valores de referencia actuales

Antes de aplicar filtros, la ejecución SQL de Gate 8 produjo:

| Medida | Valor PostgreSQL |
| --- | ---: |
| Total Tickets | 13 |
| Resolved Tickets | 1 |
| SLA Assigned | 5 |
| SLA Breached | 3 |
| SLA Breach Rate | 0.600000 |
| Prediction Attempts | 13 |
| Successful Predictions | 9 |
| Failed Predictions | 4 |
| Prediction Success Rate | 0.692308 |
| Reviews (persisted) | 2 |
| Completed Reviews | 2 |
| Pending Reviews | 0 |
| Category Overrides | 0 |
| Priority Overrides | 1 |
| Override Rate | 0.500000 |
| Automation Events | 12 |
| Automation Succeeded | 6 |
| Automation Failed | 1 |
| Automation Skipped | 5 |

Estos valores reconciliaron con Power BI después del refresh de cierre. Deben
volver a calcularse si la base cambia antes de una validación posterior.
