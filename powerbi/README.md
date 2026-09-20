# SmartDesk AI — Power BI setup

## Estado del artefacto

Power BI Desktop no estaba instalado en el entorno de ejecución de Phase 8.
Por ello no se creó un `.pbit` o `.pbix` ficticio. Esta carpeta contiene el
contrato reproducible para construir y verificar el template real.

## Conexión segura

1. Iniciar un túnel SSH local, manteniéndolo abierto durante la carga:

   ```text
   ssh -N -L 15432:127.0.0.1:5432 <ssh-alias-or-user-and-host>
   ```

2. En Power BI Desktop seleccionar **Get data → PostgreSQL database**.
3. Configurar:

   ```text
   Server: localhost:15432
   Database: smartdesk_db
   Data connectivity mode: Import
   ```

4. Elegir **Database authentication** con el usuario
   `smartdesk_bi_reader`. Obtener su contraseña mediante el procedimiento
   privado del despliegue; no copiarla a este repositorio ni convertirla en un
   parámetro de Power Query.
5. Importar únicamente las cuatro vistas del esquema `analytics`.

PostgreSQL no está publicado en Internet. El único bind del host es
`127.0.0.1:5432`; Power BI accede a él a través de SSH.

## Parámetros no secretos

Crear dos parámetros de texto:

```text
pServer = localhost:15432
pDatabase = smartdesk_db
```

No crear un parámetro de password. Las credenciales deben quedar en el
almacén local de Power BI Desktop.

## Consultas Power Query

Cada tabla usa el conector PostgreSQL y modo Import. Ejemplo para
`FactTickets`:

```powerquery
let
    Source = PostgreSQL.Database(
        pServer,
        pDatabase,
        [CreateNavigationProperties = false]
    ),
    FactTickets = Source{
        [Schema = "analytics", Item = "v_ticket_lifecycle"]
    }[Data]
in
    FactTickets
```

Repetir únicamente el selector final:

| Vista PostgreSQL | Nombre Power BI |
| --- | --- |
| `analytics.v_ticket_lifecycle` | `FactTickets` |
| `analytics.v_ai_predictions` | `FactAIPredictions` |
| `analytics.v_hitl_reviews` | `FactHITLReviews` |
| `analytics.v_automation_events` | `FactAutomationEvents` |

No habilitar DirectQuery. No importar tablas de `public`.

## Refresh y reconciliación

1. Abrir el túnel SSH.
2. Ejecutar **Refresh** en Power BI Desktop.
3. Confirmar que carguen exactamente cuatro tablas y que no haya errores de
   credenciales, PostgreSQL o Power Query.
4. Ejecutar `sql/analytics/gate8_checks.sql` contra la misma base.
5. Comparar cada card con las consultas KPI de referencia. La igualdad debe
   ser exacta; no se aceptan aproximaciones.
6. Probar filtros de fecha, área, categoría final, prioridad final y estado
   contra consultas SQL equivalentes.
7. Guardar finalmente `powerbi/SmartDeskAI.pbit`, no un `.pbix` con datos
   productivos importados.

## Semántica y límites

- `FactTickets` tiene exactamente una fila por ticket.
- `FactAIPredictions` tiene una fila por prediction persistida; sus tasas son
  prediction-level, no ticket-level.
- No existe una prediction universal autoritativa. Las columnas
  `decision_prediction_*` de `FactTickets` representan solo la prediction
  referenciada por la decisión final.
- Confidence es una señal operacional no calibrada, no una probabilidad de
  corrección.
- `category_changed` y `priority_changed` son comparaciones explícitas, no
  accuracy.
- `resolution_minutes` son minutos corridos desde la creación persistida del
  ticket hasta la resolución persistida del SLA.
- Un SLA sin fila es desconocido/no asignado; no equivale a compliant.
- El benchmark experimental de Gate 7 no forma parte de estas tablas.
- Las vistas excluyen email, título, descripción, summaries, reviewer,
  comentarios, resolved_by, mensajes y datos de Telegram.

## Datos de demo

No se añadieron fixtures en esta etapa. Las 13 filas operacionales existentes
son suficientes para validar grain, refresh y reconciliación técnica, pero no
se usarán en screenshots públicos. Si se requieren screenshots de portfolio,
debe crearse después una base demo separada con seed sintético determinista.
