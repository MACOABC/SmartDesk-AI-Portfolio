# SmartDesk AI — Contexto del proyecto

## Producto y problema

SmartDesk AI automatiza el triage inicial de solicitudes internas de soporte: recibe, valida, registra, clasifica, prioriza, resume, aplica reglas y notifica. Busca reducir trabajo manual e inconsistencias y producir datos estructurados para análisis. Esos beneficios son objetivos; todavía no se han medido.

El resultado esperado es un sistema empresarial funcional, desplegado y demostrable. V1 cubre el procesamiento inicial del ticket; no pretende sustituir una plataforma ITSM completa ni resolver automáticamente las incidencias.

## Objetivo profesional

El proyecto debe demostrar capacidades para prácticas preprofesionales en Automatización, IA aplicada, Transformación Digital e integración de sistemas, con Data/BI como segunda línea. Complementa Zoom2TXT, que ya demuestra Python, APIs, automatización, testing, CI y documentación, mediante procesos empresariales, n8n, SQL/PostgreSQL, IA estructurada y despliegue cloud.

Cada decisión debe poder explicarse en entrevista y respaldarse con artefactos o pruebas. No se incorporarán tecnologías ni funcionalidades únicamente para ampliar el CV.

## Usuarios

| Usuario | Necesidad |
| --- | --- |
| Solicitante | Enviar área, asunto y descripción sin requerir un portal completo en V1. |
| Analista de soporte | Recibir el ticket original junto con categoría, prioridad y resumen. |
| Responsable de TI u operaciones | Consultar indicadores operativos y analíticos mediante SQL y Power BI. |
| Administrador técnico | Mantener infraestructura, servicios, configuración y accesos. |

## Arquitectura objetivo

Flujo funcional de V1:

```text
POST al webhook
  → n8n: validación de entrada
  → PostgreSQL: ticket inicial en estado processing
  → API de IA: clasificación, prioridad y resumen
  → n8n: validación del JSON y sus valores permitidos
  → PostgreSQL: predicción asociada al ticket
  → reglas de negocio
  → Telegram: notificación
  → registro del resultado y respuesta con ticket_id y estado

PostgreSQL → vistas analytics → Power BI
```

La persistencia precede a la llamada a la IA para conservar la solicitud si falla un servicio externo. Una respuesta de IA inválida no pasa a las reglas de negocio.

Phase 6 extiende ese flujo con retry selectivo de IA, señal HITL, revisión
humana, decisión operacional final separada, SLA y escalamiento. Una prediction
que requiere review no produce decisión, SLA ni acción hasta ser approved u
overridden. El scheduler reclama deadlines vencidos de forma idempotente.

Despliegue previsto:

```text
Internet → HTTPS → Caddy → n8n
                            ├─ PostgreSQL privado
                            ├─ API de IA
                            └─ Telegram

Oracle Cloud ARM64 + Docker Compose
```

Caddy y HTTPS se incorporaron en Fase 5 con una superficie pública limitada al webhook productivo. La administración de n8n permanece en localhost mediante túnel SSH. PostgreSQL no está expuesto a Internet: el host enlaza `127.0.0.1:5432` para acceso BI mediante túnel SSH y los contenedores autorizados acceden por nombre de servicio. Se mantienen una red de aplicación y una red interna para PostgreSQL, y Caddy solo pertenece a la primera.

La infraestructura disponible es una VM Oracle Cloud ARM64 con Ubuntu 22.04, 2 OCPU y 12 GB de RAM. Docker y Docker Compose ya están disponibles. La operación continua es un objetivo; no existe todavía una medición de disponibilidad. El estado aprobado de seguridad se mantiene en `../STATUS.md`.

## Alcance V1

1. Recibir por HTTP POST `requester_email`, `requester_area`, `title` y `description`; un formulario podrá añadirse como otra interfaz posteriormente.
2. Validar presencia, tipos, textos no vacíos, formato de email y longitudes antes de consumir servicios externos.
3. Generar identificador único, origen, fechas y estado, y persistir la solicitud válida.
4. Obtener de la IA un JSON con `category`, `priority` y `summary`, y validar esquema y valores permitidos.
5. Guardar clasificación y trazabilidad de proveedor, modelo y versión del prompt.
6. Aplicar reglas explícitas en n8n durante la Fase 4 según la clasificación y la prioridad validadas.
7. Notificar por Telegram y registrar éxito o fallo.
8. Responder con `ticket_id` y estado, dejando los datos disponibles para consultas.

Los fallos de clasificación o notificación deben registrarse sin eliminar el ticket. Los reintentos avanzados se desarrollarán después de V1.

El contrato de clasificación V1 admite exactamente las categorías `access`, `hardware`, `software`, `network`, `service_request` y `other`. Las prioridades permitidas son `low`, `medium`, `high` y `critical`. La salida contiene únicamente `category`, `priority` y `summary`; no incluye `confidence` ni razonamiento. El contrato y su integración quedaron implementados y aprobados en Fase 3.

## Datos y trazabilidad

Una instancia PostgreSQL alojará dos bases lógicamente separadas: `n8n_db` para datos internos de n8n y `smartdesk_db` para datos empresariales, con usuarios y permisos diferenciados.

El modelo conceptual empresarial incluye:

| Entidad | Responsabilidad |
| --- | --- |
| `tickets` | Entrada original, estado propio del ticket y marcas de tiempo. |
| `ticket_ai_predictions` | Predicción, proveedor, modelo, versiones del prompt y schema, estado y error, relacionados con el ticket sin sobrescribir su historial. |
| `ticket_reviews` | Estado y resultado trazable de approve/override humano. |
| `ticket_decisions` | Clasificación operacional final, separada de la predicción original. |
| `sla_policies` | Política SLA interna y versionada por prioridad. |
| `ticket_sla` | Deadline, estado, resolución y breach relacionados con la decisión final. |
| `sla_breaches` | Breach único y resultado de su escalamiento. |
| `automation_events` | Acciones automáticas relacionadas con prediction/decision/breach, sin secretos. |

La clasificación de IA tiene persistencia separada con los estados `pending`, `succeeded` y `failed`; `error_code` distingue la causa concreta de un fallo. La tabla y su uso desde n8n fueron creados y verificados. Fase 4 añadió `automation_events` con `pending`, `succeeded`, `failed` y `skipped`, sin modificar el lifecycle ni los valores de `tickets.status`. HIGH y CRITICAL fueron entregados realmente por Telegram y Gate 4 quedó aprobado.

Phase 6 añadió el contrato `ticket-classification-v2`, trazabilidad de intentos
y `confidence` como señal operacional no calibrada. PostgreSQL materializa de
forma transaccional la review o la decisión+SLA+evento. Las restricciones
únicas impiden reviews, decisiones, breaches y acciones duplicadas para el
mismo evento lógico interno.

## Tecnologías y justificación

| Tecnología | Problema que resuelve | Momento |
| --- | --- | --- |
| Oracle Cloud VM | Infraestructura real para desplegar y operar el servicio. | Base disponible. |
| Docker y Docker Compose | Aislamiento y definición reproducible de servicios, redes y volúmenes. | Fase 1. |
| n8n | Orquestación e integración del proceso de negocio. | Base en Fase 1; flujo desde Fase 2. |
| PostgreSQL y SQL | Persistencia, integridad, trazabilidad y consultas. | Base en Fase 1; modelo desde Fase 2. |
| REST/webhooks | Contrato de entrada desacoplado. | Fase 2. |
| API de IA | Comprensión semántica, clasificación, prioridad y resumen estructurados. | Fase 3. |
| Telegram | Validar la integración de notificaciones con una configuración acotada. | Fase 4, completada; email posterior. |
| Caddy y HTTPS | Proxy inverso y transporte cifrado para la publicación. | Despliegue de V1. |
| Git y GitHub | Historial, revisión y documentación reproducible. | Desde Fase 1. |
| Python, si aporta valor | Evaluación del clasificador y análisis del dataset. | Fase 7; no necesario en el flujo V1. |
| Power BI | Visualización de información operativa basada en SQL. | Fase 8. |
| GitHub Actions | Automatizar comprobaciones y, posteriormente, despliegues. | Fase 9. |

## Límites y evolución

V1 excluye portal completo, autenticación corporativa, asignación inteligente, resolución automática, RAG, embeddings, base vectorial, chatbot, ML propio, backend personalizado, microservicios, Redis, Kafka y Kubernetes.

Después de V1 se completaron confiabilidad, reintentos selectivos, revisión
humana y SLA en Phase 6; evaluación de IA en Phase 7; SQL analítico y Power BI
en Phase 8; y CI/CD, monitoring, backups y hardening adicional en Phase 9.
Phase 10 prepara la documentación, demo y evidencia profesional sin ampliar el
producto. La detección de tickets duplicados y otras extensiones solo se
considerarán por su valor. Portainer no forma parte del producto.

## Calidad, seguridad y evidencia

- Imágenes compatibles con `linux/arm64`, volúmenes persistentes y permisos mínimos.
- Secretos externos a Git; `.env.example` solo con valores ficticios. Datos sintéticos en pruebas, demos y capturas.
- PostgreSQL privado y n8n sin exposición pública directa en `5678`; administración protegida y publicación mediante HTTPS.
- Pruebas de contratos, JSON inválido, fallos externos, persistencia, reglas e integración completa, con resultados comprobables.
- Evaluación ejecutada sobre un dataset sintético etiquetado y congelado: accuracy de categoría y prioridad, matrices de confusión, latencia, errores, coste y routing HITL, con limitaciones documentadas.
- Análisis implementado por categoría, prioridad, área, estado, tiempo, SLA y resolución mediante cuatro vistas y un template Power BI de tres páginas.
- No se afirmarán ahorros, precisión, disponibilidad ni impacto sin mediciones ejecutadas y reproducibles.

La VM única es un punto único de fallo aceptado inicialmente. Deben contemplarse errores de IA, abuso del webhook, instrucciones maliciosas dentro de tickets, filtración de secretos, consumo de disco e incompatibilidades ARM64. Sus controles se incorporarán en la fase correspondiente, sin declarar resuelto lo que aún no se haya validado.

## Decisiones pendientes y referencias

El hostname y DNS de V1 quedaron resueltos al implementar el ingress HTTPS de Fase 5. La categoría residual permanece fijada como `other` por aprobación del usuario.

Este contexto consolida «00 — Roadmap y arquitectura inicial», «01 — Fase 0: Hardening OCI» y «02 — Base técnica: GitHub + Docker Compose + PostgreSQL». `../STATUS.md` es la fuente del estado actual, `../ROADMAP.md` define fases y gates, `PHASE_X.md` conserva snapshots de implementación y `testing/GATE_X.md` conserva evidencia. El estado más reciente prevalece sobre propuestas o snapshots anteriores.

La historia Git anterior a Phase 10 conserva una referencia al hostname
productivo que fue sustituida por un placeholder en el árbol actual. El
repositorio debe permanecer privado hasta que el propietario decida si autoriza
una sanitización de historia; Phase 10 no reescribe historia ni hace force push.
