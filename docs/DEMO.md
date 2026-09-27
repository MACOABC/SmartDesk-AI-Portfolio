# SmartDesk AI — Demo final segura

## Grabación final

- **Estado:** RECORDED / REVIEWED / UPLOADED.
- **URL:** https://youtu.be/li0uU9b3e70
- **Duración:** aproximadamente 3m40s.
- **Visibilidad:** YouTube Unlisted.
- **Contenido:** evidencia sintética y saneada, revisada visualmente antes de
  enlazarla desde el portfolio.

## Objetivo y duración

La demo presenta el problema, la arquitectura, un ticket sintético, la salida
IA estructurada, la orquestación, el modelo analítico, la evaluación y CI sin
depender de producción.

- Objetivo: **3:10**.
- Rango recomendado: **2:45–3:30**.
- Máximo: **4:00**.
- Idioma hablado: español, conservando nombres técnicos en inglés.

El recorrido predeterminado usa evidencia estática ya aprobada. Una ejecución
live es opcional y solo se permite en un entorno demo aislado que haya sido
ensayado y saneado antes de grabar.

## Fixture principal

**DEMO_PRIMARY:** `DEMO-LOW-001`, definido en `demo/tickets.json`.

Es una solicitud sintética, breve y planificada para un segundo monitor. Usa
`example.com`, no describe una interrupción y su etiqueta esperada es
`service_request / low`. Si se ejecuta en un entorno demo, una clasificación
LOW debe dejar la automatización en `skipped` y no enviar Telegram. La etiqueta
esperada es ground truth de demo, no una predicción garantizada.

**DEMO_ALERT:** `DEMO-HIGH-001` queda documentado, pero no se usa en la
grabación final. Podría disparar Telegram y no aporta suficiente valor para
justificar esa dependencia.

La imagen `ticket-ai-response.png` corresponde al caso independiente
`SD-EVAL-TEST-083` y a su predicción real conservada en el benchmark
congelado. No debe presentarse como respuesta de `DEMO-LOW-001`.

## Live frente a evidencia estática

| Parte | Modo predeterminado | Alternativa permitida |
| --- | --- | --- |
| Arquitectura | STATIC EVIDENCE: `architecture-overview.png` | Ninguna necesaria. |
| Ticket principal | STATIC EVIDENCE: `demo/tickets.json` | LIVE: un único `DEMO-LOW-001` en entorno demo aislado. |
| Salida IA | STATIC EVIDENCE: `ticket-ai-response.png` | Resultado real de `DEMO-LOW-001` solo si fue ensayado y saneado. |
| n8n | STATIC EVIDENCE: secuencia de tres capturas | LIVE GUI local/demo con paneles cerrados. |
| Power BI | STATIC EVIDENCE: `powerbi-data-model.png` | Ninguna; no usar dashboards rechazados. |
| Evaluación | STATIC EVIDENCE: README | Ninguna necesaria. |
| CI | STATIC EVIDENCE: `github-actions-ci.png` | Run alojado del candidato, sin abrir logs. |

El recorrido estático no requiere OpenAI, Telegram, PostgreSQL, Power BI
Desktop, n8n ni acceso a producción durante la grabación.

## Storyboard definitivo

| Tiempo | Pantalla | Acción | Mensaje clave |
| --- | --- | --- | --- |
| 0:00–0:20 | README + `architecture-overview.png` | Presentar problema y producto. | SmartDesk AI automatiza el procesamiento inicial de solicitudes de soporte. |
| 0:20–0:40 | Arquitectura | Recorrer Caddy, n8n, OpenAI, PostgreSQL, reglas y Power BI. | El ticket se persiste antes de IA y la salida se valida antes de aplicar reglas. |
| 0:40–1:15 | `demo/tickets.json`, `DEMO-LOW-001` | Mostrar input sintético; ejecutar solo si existe entorno demo seguro. | El contrato recibe email, área, título y descripción; el caso no contiene datos reales. |
| 1:15–1:40 | `ticket-ai-response.png` | Señalar `category`, `priority` y `summary`; aclarar que es `SD-EVAL-TEST-083`. | Structured Outputs + JSON Schema, con validación determinista. |
| 1:40–2:05 | Tres capturas n8n | Mostrar intake, procesamiento IA y outcome sin recorrer cada nodo. | Validación, DB-first persistence, bounded retries, rules, Telegram y review. |
| 2:05–2:25 | `powerbi-data-model.png` | Señalar las cuatro tablas y relaciones 1:*. | Cuatro vistas analíticas alimentan Power BI mediante acceso read-only. |
| 2:25–2:45 | README, Evaluación de IA | Mostrar 120 casos, 89.17% y 76.67%. | Benchmark sintético congelado; no confundirlo con métricas operacionales. |
| 2:45–3:05 | `github-actions-ci.png` | Mostrar `Success` y el job `validate`. | CI alojado ejecuta 35 tests; deployment, monitoring y backups viven en el repo operativo. |
| 3:05–3:15 | README | Cerrar en una frase. | SmartDesk AI integra automation, applied AI, SQL/BI y cloud operations en un sistema desplegado. |

El texto hablado exacto está en `docs/DEMO_SCRIPT.md`.

## Pestañas antes de grabar

Preparar un máximo de cinco pestañas y ordenarlas antes de iniciar:

1. README del repositorio candidato, en la arquitectura.
2. `demo/tickets.json`, ubicado en `DEMO-LOW-001`.
3. README del candidato, en la secuencia n8n y la salida estructurada.
4. README del candidato, en Power BI y evaluación.
5. GitHub Actions del candidato o la captura CI aprobada.

La UI de n8n puede reemplazar la pestaña 3 únicamente si es una instancia
local/demo saneada. Cerrar pestañas no relacionadas y ocultar bookmarks,
perfiles y barra de URL cuando puedan revelar información.

## Preparación de n8n

Workflow exacto: **SmartDesk - Ticket Intake**.

- Cerrar node configuration, credentials, executions y output panels.
- No seleccionar nodos que muestren payloads o headers anteriores.
- Usar canvas sin sidebar y zoom aproximado de 45–55 %.
- Centrar intake → validation → persistence para la primera vista; AI/retries
  para la segunda; classification/review/outcome para la tercera.
- Hacer como máximo dos desplazamientos ensayados.
- Si el texto no resulta legible, usar las tres capturas aprobadas del README.

## Request live opcional

No existe una URL demo versionada. Si Marco prepara un entorno demo aislado,
la URL debe permanecer en una variable de proceso y nunca mostrarse:

```powershell
$case = (Get-Content demo/tickets.json -Raw | ConvertFrom-Json).cases |
  Where-Object id -eq 'DEMO-LOW-001'
Invoke-RestMethod -Method Post -Uri $env:DEMO_WEBHOOK_URL `
  -ContentType 'application/json' -Body ($case.payload | ConvertTo-Json)
```

Antes de usarlo, limpiar la pantalla y verificar que el prompt no incluya una
ruta personal. No ejecutar si `DEMO_WEBHOOK_URL` apunta a producción, si el
destino Telegram no está aislado o si no puede confirmarse el efecto esperado.
La grabación predeterminada no necesita este comando.

## Checklist obligatoria antes de grabar

- [ ] Browser notifications disabled.
- [ ] WhatsApp and webmail closed.
- [ ] Unrelated tabs closed.
- [ ] Bookmarks hidden if necessary.
- [ ] `.env` closed.
- [ ] Terminal history safe.
- [ ] SSH alias hidden.
- [ ] Production hostname hidden.
- [ ] Webhook URL hidden.
- [ ] Public IP hidden.
- [ ] n8n credentials hidden.
- [ ] OpenAI key hidden.
- [ ] Telegram token and chat ID hidden.
- [ ] PostgreSQL password hidden.
- [ ] Local personal paths hidden.
- [ ] Only synthetic tickets visible.
- [ ] No personal emails visible.
- [ ] No provider response IDs visible.
- [ ] No execution IDs unless necessary.
- [ ] No rejected Power BI operational dashboards open.
- [ ] Candidate portfolio repository shown instead of the operational repo where possible.
- [ ] Microphone, crop, zoom and 16:9 recording area verified.

## Power BI y métricas

Usar únicamente `powerbi-data-model.png`. Explicar brevemente
`FactTickets`, `FactAIPredictions`, `FactAutomationEvents` y
`FactHITLReviews`, las relaciones y el acceso read-only. No abrir Operations
Overview, AI & Human Review ni SLA / Automation.

La demo puede mencionar:

- 120 synthetic labeled cases;
- 89.17% category accuracy;
- 76.67% priority accuracy;
- 67.50% exact match, solo si entra de forma natural.

`Prediction Success Rate` operacional no es benchmark accuracy y no debe
aparecer como tal.

## Plan B

- Si una dependencia externa no está estable, usar la evidencia estática.
- Si n8n no puede mostrarse de forma segura, usar sus tres capturas aprobadas.
- Si una ejecución live devuelve otra etiqueta, mostrar el resultado real o
  repetir sin grabar; nunca sustituirlo por una respuesta inventada.
- No generar una alerta HIGH/CRITICAL para mejorar la grabación.
- No abrir dashboards Power BI rechazados como reemplazo del modelo.

## Revisión cuadro por cuadro

- [ ] No secret visible.
- [ ] No endpoint or webhook path visible.
- [ ] No IP visible.
- [ ] No personal notification visible.
- [ ] No personal email visible.
- [ ] No password visible.
- [ ] No SSH information visible.
- [ ] No production URL visible.
- [ ] No real ticket visible.
- [ ] No provider response or execution ID visible.
- [ ] No misleading metric visible.
- [ ] Audio is understandable.
- [ ] Text is readable.
- [ ] Duration is no more than 4 minutes.
- [ ] Workflow is legible.
- [ ] Project objective is clear.
- [ ] Ending is concise.

## Publicación del video

La grabación final fue revisada y está disponible como **YouTube Unlisted** en
https://youtu.be/li0uU9b3e70. El README enlaza esta URL sin afirmar que el video
sea público.
