# SmartDesk AI — Plan de assets de portafolio

Las capturas y la grabación requieren ejecución manual. No deben fabricarse ni
tomarse desde producción sin sanitización. Formato recomendado general: PNG a
1600×900 o superior, crop 16:9, texto legible al 100% y sin ventanas ajenas.

## Inventario priorizado

| Prioridad | Asset | Qué debe verse | Qué ocultar | Historia que cuenta |
| ---: | --- | --- | --- | --- |
| 1 | Arquitectura | Mermaid renderizado de `docs/ARCHITECTURE.md`, con flujo y límites | Hostnames, IPs, rutas locales | El sistema integra automatización, IA, datos, BI y operación sin complejidad artificial. |
| 2 | Workflow n8n | Canvas completo de Ticket Intake y nombres funcionales de nodos | Panel de credentials, IDs internos, executions antiguas | La orquestación valida, persiste, clasifica y aplica reglas. |
| 3 | Request/response sintéticos | Payload `DEMO-HIGH-001`, HTTP 201 y campos estructurados | URL real, headers, token, response/provider IDs | El flujo acepta una entrada ficticia y devuelve trazabilidad estructurada. |
| 4 | PostgreSQL + HITL/SLA | Consulta saneada de ticket, prediction, decision y SLA de demo | Emails, texto libre, UUID completos, conexión/usuario | La solución conserva estados separados y auditables. |
| 5 | Power BI Overview | Página ejecutiva con filtros y KPIs sobre base demo | Las 13 filas operacionales de Gate 8 y cualquier PII | Analytics usable sobre datos sintéticos. |
| 6 | Power BI AI | Página de predictions, status, categoría y prioridad | Response IDs, summaries o texto del ticket | Calidad operativa y trazabilidad a grain prediction. |
| 7 | Power BI SLA | Página SLA/HITL con datos demo preparados | Reviewer, comentarios y nombres | El proceso incluye revisión y deadlines, sin afirmar mejora de accuracy. |
| 8 | CI verde | Run final con validación, 35 tests y PostgreSQL temporal | Logs con rutas del runner si distraen; ningún secret | La calidad está automatizada y aislada de producción. |
| 9 | FAIL → recovery | Dos estados: negative CI esperado y recovery PASS | Cualquier artefacto temporal irrelevante | El pipeline detecta defectos y confirma la corrección. |
| 10 | Deploy por SHA | Input SHA, job PASS, health y smoke | Host, usuario SSH, known_hosts y secret names innecesarios | El despliegue es deliberado, reproducible y verificable. |

## Composición recomendada

- Usar máximo 5–6 capturas en el README futuro; el resto puede vivir en una
  carpeta `docs/assets/` cuando existan.
- Priorizar arquitectura, n8n, request/response, Power BI Overview y CI.
- Añadir un caption factual de una línea; no superponer cifras de impacto.
- Mantener el mismo tema visual y relación de aspecto.
- Si una captura necesita blur para ser segura, repetirla en un entorno demo
  hasta que el dato sensible no exista en origen.

## Checklist antes de guardar cada imagen

- [ ] Datos exclusivamente sintéticos.
- [ ] Dominio `example.com` o placeholder visible.
- [ ] Sin `.env`, tokens, chat IDs, passwords, claves ni páginas de credentials.
- [ ] Sin IP, hostname, alias SSH o rutas personales.
- [ ] Sin provider response IDs ni logs productivos.
- [ ] Métricas coherentes con `PORTFOLIO_METRICS.md`.
- [ ] Crop legible y sin notificaciones personales.
- [ ] Nombre neutral, por ejemplo `architecture.png` o `powerbi-overview.png`.

## Video de 2–4 minutos

La grabación debe seguir `docs/DEMO.md`. Exportar una versión final después de
revisarla cuadro por cuadro. No mostrar en vivo la edición de credenciales ni
usar el webhook productivo como endpoint público de demostración.

