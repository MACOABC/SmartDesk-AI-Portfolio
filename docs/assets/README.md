# Portfolio assets

Esta carpeta contiene únicamente assets reales, saneados y seleccionados para
el portfolio. La procedencia, clasificación y revisión de seguridad se
documentan en `../PORTFOLIO_ASSETS.md`.

## Inventario final

| Filename | Purpose | Source | Status |
| --- | --- | --- | --- |
| `screenshots/architecture-overview.png` | Arquitectura end-to-end | Arquitectura documentada del proyecto | READY / PASS |
| `screenshots/n8n-ticket-workflow-01-intake.png` | Intake y persistencia | Workflow real `SmartDesk - Ticket Intake` | READY / PASS |
| `screenshots/n8n-ticket-workflow-02-ai-processing.png` | IA, retries y errores | Workflow real `SmartDesk - Ticket Intake` | READY / PASS |
| `screenshots/n8n-ticket-workflow-03-outcome.png` | Reglas, review y outcome | Workflow real `SmartDesk - Ticket Intake` | READY / PASS |
| `screenshots/ticket-ai-response.png` | Resultado IA estructurado | Caso congelado `SD-EVAL-TEST-083` | READY / PASS |
| `screenshots/powerbi-data-model.png` | Modelo analítico | Power BI Desktop validado en Gate 8 | READY / PASS |
| `screenshots/github-actions-ci.png` | CI determinista | GitHub Actions del candidato | READY / PASS |

Los dashboards Power BI Operations Overview, AI & Human Review y SLA /
Automation fueron rechazados para uso público porque contienen las filas
operacionales de reconciliación de Gate 8 o pueden confundir métricas.

No añadir placeholders, mocks ni imágenes generadas que aparenten ser
capturas del sistema.
