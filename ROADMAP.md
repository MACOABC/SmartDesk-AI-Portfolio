# SmartDesk AI — Roadmap y gates

## Regla de avance

Trabajar una fase y un paso por vez. Antes de avanzar, verificar los criterios del gate, conservar evidencia saneada y actualizar `STATUS.md`. Cada comprobación ejecutada se documentará con resultado `PASS` o `FAIL` y evidencia; lo no ejecutado permanecerá pendiente.

La secuencia de fases procede de «00 — Roadmap y arquitectura inicial». Fase 1 y Gate 1 incorporan las precisiones de «02 — Base técnica: GitHub + Docker Compose + PostgreSQL». Gate 0, Gate 1, Gate 2, Gate 3, Gate 4, Gate 5 y Gate 6 están aprobados. Los criterios de fases posteriores concretan los objetivos del diseño para su futura validación; no representan pruebas ejecutadas ni aprobaciones anticipadas.

## Secuencia acordada

| Fase | Alcance | Gate / hito | Estado |
| --- | --- | --- | --- |
| 0 | Hardening OCI, Ubuntu y Docker. | Gate 0. | APROBADO. |
| 1 | Repositorio, Docker Compose, PostgreSQL y base de n8n. | Gate 1. | APROBADA. |
| 2 | Webhook, validación y persistencia inicial. | Gate 2. | COMPLETADA / APROBADO. |
| 3 | IA, salida estructurada y versionado de prompts. | Gate 3. | COMPLETADA / APROBADO. |
| 4 | Reglas, Telegram y manejo básico de errores. | Gate 4. | COMPLETADA / APROBADO. |
| 5 | V1 completa, desplegada y probada de extremo a extremo. | Gate 5 / release v1.0. | COMPLETADA / APROBADO. |
| 6 | Confiabilidad, reintentos, manejo de errores, revisión humana y SLA. | Gate 6. | COMPLETADA / APROBADO. |
| 7 | Dataset sintético y evaluación de IA. | Gate 7. | EN CURSO / Gate no aprobado. |
| 8 | SQL analítico y Power BI. | Gate 8. | Pendiente. |
| 9 | CI/CD, monitoreo, health checks, backups y hardening adicional. | Gate 9. | Pendiente. |
| 10 | Portafolio, documentación, demo, métricas reales, CV, LinkedIn y entrevista. | Gate 10 / cierre integral. | Pendiente. |

El roadmap original nombró explícitamente Gates 0–4 y estableció un gate por fase. Aquí se extiende esa numeración a 5–10 para mantener una referencia uniforme, sin alterar el orden acordado.

## Fase 0 — Hardening

Gate 0 exige SSH por clave, autenticación por contraseña y acceso root deshabilitados, denegación entrante por defecto, puertos internos y administrativos sin exposición, revisión de servicios y actualizaciones, funcionamiento de Docker tras reiniciar y comprobación externa de la superficie expuesta.

Fue aprobado en «01 — Fase 0: Hardening OCI». Su cierre y los límites de la evidencia constan en `STATUS.md`. `80/443` permanecen cerrados hasta necesitar el proxy.

## Fase 1 — Base técnica

Entregables: repositorio Git `SmartDesk-AI`, estructura con propósito, documentación, `.gitignore`, `.env.example`, configuración externa de secretos y `compose.yaml`. El stack debe incluir PostgreSQL persistente, bases `n8n_db` y `smartdesk_db` con permisos diferenciados, n8n, redes aisladas, volúmenes, health checks razonables e imágenes ARM64.

Gate 1 requiere demostrar:

- Repositorio creado y limpio, sin secretos versionados.
- `docker compose config` válido, sin divulgar valores reales en la evidencia.
- PostgreSQL healthy y n8n funcionando.
- Separación de bases y permisos; comunicación interna correcta entre servicios autorizados.
- Datos PostgreSQL y datos/configuración de n8n persistentes tras reiniciar contenedores.
- PostgreSQL inaccesible desde Internet y sin publicar `5432`; n8n sin exposición pública en `5678`.
- Acceso temporal a n8n por `127.0.0.1:5678:5678` y túnel SSH, si se necesita su interfaz.
- Stack capaz de detenerse y volver a levantarse; política de reinicio comprobada.
- `docker ps` mostrando únicamente los contenedores esperados.

Cerrar con tabla `PASS / FAIL / evidencia`. Esta fase excluye IA, webhook empresarial, clasificación, Telegram, Power BI, Caddy público y CI/CD. La tarea documental actual no implementa ningún servicio de esta fase.

## Fase 2 — Entrada y persistencia

Implementar el webhook y el contrato de entrada, generar `ticket_id` y guardar el ticket válido antes de cualquier llamada a IA.

Gate 2: una entrada válida queda persistida y relacionada con su identificador; campos ausentes, tipos incorrectos, valores no permitidos y longitudes excesivas se rechazan con error comprensible. Verificar restricciones, fechas y persistencia. La IA todavía no forma parte de esta fase.

Gate 2 fue aprobado el 2026-09-17 tras una batería controlada de 30 solicitudes end-to-end. La evidencia saneada se conserva en `docs/testing/GATE_2.md` y el contrato implementado en `docs/INTAKE.md`.

## Fase 3 — Clasificación con IA

Integrar el proveedor elegido, versionar el prompt y validar el esquema de salida y las taxonomías. Registrar predicción, proveedor, modelo, versión del prompt y resultado de ejecución.

Gate 3: un ticket de prueba obtiene categoría, prioridad y resumen válidos; JSON inválido, valores fuera de contrato, timeout y error del proveedor se gestionan sin perder el ticket ni ejecutar reglas con una salida inválida. Una prueba funcional no acredita accuracy.

Gate 3 fue aprobado el 2026-09-17 después de integrar la clasificación estructurada en el intake real, persistir su ciclo `pending → succeeded/failed` y superar la regresión final 30/30 de Gate 2 sobre el workflow final. La evidencia saneada se conserva en `docs/testing/GATE_3.md`.

## Fase 4 — Reglas y notificaciones

Aplicar condiciones explícitas según clasificación/prioridad, integrar Telegram y registrar eventos y errores básicos.

Gate 4: casos conocidos activan las ramas previstas, la notificación llega al destino de prueba y queda registrada; un fallo de Telegram conserva la clasificación y registra estado `failed` con `TELEGRAM_SEND_FAILED`. Los fallos de IA conservan el ticket y su estado de error. No introducir un motor de reglas ni reintentos avanzados.

Gate 4 fue aprobado el 2026-09-19 después de verificar la entrega Telegram
real para HIGH y CRITICAL, las transiciones a `succeeded`, LOW/MEDIUM como
`skipped`, la exclusión de predicciones fallidas, el manejo
`failed / TELEGRAM_SEND_FAILED`, regresión, seguridad, limpieza y deployment.
La evidencia saneada se conserva en `docs/testing/GATE_4.md`.

## Fase 5 — V1 desplegada y release v1.0

Resolver dominio/DNS, incorporar Caddy y HTTPS, proteger la administración y habilitar únicamente los puertos públicos necesarios. Integrar y comprobar el flujo completo en Oracle Cloud.

Gate 5 / aceptación de V1:

| Caso | Evidencia requerida |
| --- | --- |
| Solicitud válida | UUID, persistencia inicial, JSON válido, predicción guardada, regla correcta, mensaje recibido en Telegram, respuesta y estado final coherentes. |
| Entrada inválida | Rechazo comprensible sin llamada a IA. |
| Fallo de IA | Ticket conservado, clasificación fallida y error registrado. |
| Fallo de Telegram | Ticket y clasificación conservados, fallo de notificación registrado. |
| Reinicio | Tickets y configuración persisten. |
| Exposición | Acceso de aplicación mediante HTTPS/proxy; `5678`, `5432` y `9000` no accesibles públicamente; SSH conserva su protección. |
| Reproducibilidad | Versiones, configuración de ejemplo, instrucciones y evidencia suficientes para repetir el despliegue y las pruebas. |

Publicar la release v1.0 únicamente después de superar el gate. Esto completa V1; todavía no cierra el proyecto de portafolio.

Gate 5 fue aprobado el 2026-09-19 después de completar E2E-01 a E2E-06 sobre
el tested/release commit `fc42c911725aa589e3b36207d0be5b95b9f08063`.
La matriz verificó entrada inválida, HIGH con Telegram real, LOW sin Telegram,
fallos controlados de IA y Telegram, correlación SQL, ausencia de duplicados y
pendientes, redeploy con persistencia, HTTPS y regresión de exposición. La
evidencia saneada se conserva en `docs/testing/GATE_5.md`. El tag local `v1.0`
apunta al commit probado, no al commit documental de cierre. Fase 5 y
SmartDesk AI V1 quedan completados; después del cierre descrito a continuación,
las fases 7–10 permanecen pendientes.

## Fase 6 — Reliability, HITL y SLA

Gate 6 fue aprobado el 2026-09-20 sobre el commit funcional desplegado
`ba9fd7b1d32c837a30afc1d35d05a018492e4392`. Se verificaron retries selectivos
y limitados, errores permanentes sin retry, recuperación de estados stale,
review pending/approve/override, preservación de la predicción original,
decisión final separada, SLA versionado desde `tickets.created_at`, resolución,
breach y escalamiento idempotentes, restart, regresión y seguridad.

La evidencia saneada está en `docs/testing/GATE_6.md`. Phase 6 queda completa;
la fase actual pasa a Phase 7. El tag `v1.0` no fue modificado.

## Phase 7 — Dataset sintético y evaluación de IA

Phase 7 está **IN PROGRESS** y Gate 7 permanece **NOT YET PASS**. La subfase 7A
dejó versionados la política de etiquetado, el schema, 30 casos `dev`, 120 casos
de test congelado, el manifiesto con hashes y la validación local reproducible.
No se llamó a la API oficial ni se generaron métricas del modelo.

El trabajo restante debe implementar el runner, validarlo con `dev`, fijar el
protocolo y costo de la corrida, ejecutar el test congelado una sola vez y
documentar resultados y análisis de errores. Solo esa evidencia podrá evaluarse
contra los criterios de Gate 7.

## Fases posteriores a V1

Los siguientes criterios orientan el cierre; sus contratos, umbrales y pruebas detalladas se acordarán al iniciar cada fase, sin inventar objetivos numéricos.

| Fase | Criterio de cierre |
| --- | --- |
| 6 — Confiabilidad | Reintentos y recuperación probados, revisión humana trazable y reglas de SLA verificadas con casos controlados. Definir antes estados, límites y comportamiento ante fallos. |
| 7 — Evaluación IA | Dataset sintético etiquetado y versionado; evaluación reproducible con resultados reales, configuración del experimento y análisis de errores. Medir categoría, prioridad, latencia y fallos; revisión humana cuando aplique. |
| 8 — Data/BI | Consultas SQL verificadas y dashboard reproducible por categoría, prioridad, área, estado y tiempo. Conciliar los indicadores con la base; usar SLA y resolución solo si hay datos y procesos implementados. |
| 9 — Operación | CI/CD probado, controles de salud y monitoreo verificables, backups con restauración ensayada y revisión de hardening. Los controles básicos de seguridad, errores y salud necesarios antes se mantienen desde sus fases iniciales. |
| 10 — Portafolio | Repositorio público profesional, README, arquitectura, instrucciones, seguridad, tests y CI, capturas, demo segura, métricas con evidencia, release estable, CV y LinkedIn actualizados, explicación de entrevista y preguntas técnicas preparadas. |

El proyecto termina al superar el cierre integral, no solo al lograr que un ticket funcione. Las extensiones nuevas deben justificar su utilidad y su retorno profesional antes de incorporarse.
