# SmartDesk AI — Estado actual

```text
Gate 0 = PASS
Gate 1 = PASS
Gate 2 = PASS
Gate 3 = PASS
Gate 4 = PASS
Gate 5 = PASS
Gate 6 = PASS
Gate 7 = NOT YET PASS
SmartDesk AI V1 = COMPLETE
Phase 6 = COMPLETE
Phase 7 = IN PROGRESS
Current subphase = Phase 7B complete; live smoke and formal evaluation pending
```

- **Gate 0: APROBADO.**
- **Gate 1: APROBADO.**
- **Gate 2: APROBADO.**
- **Gate 3: APROBADO.**
- **Gate 4: APROBADO.**
- **Gate 5: APROBADO.**
- **Gate 6: APROBADO.**
- **Fase 1 — Repositorio + Docker Compose + PostgreSQL + base de n8n: COMPLETADA.**
- **Fase 2 — Webhook + validación + persistencia inicial: COMPLETADA.**
- **Fase 3 — IA, salida estructurada y versionado de prompts: COMPLETADA.**
- **Fase 4 — reglas de negocio + notificación: COMPLETADA.**
- **Fase 5 — V1 completa, desplegada y probada end-to-end: COMPLETADA.**
- **Fase 6 — Reliability + HITL + SLA: COMPLETADA.**
- **SmartDesk AI V1: COMPLETA.**
- **Fase actual: Phase 7 — dataset sintético y evaluación de IA; IN PROGRESS.**
- **Phase 7A — dataset sintético, política y validación local: IMPLEMENTADA; Gate 7 todavía no aprobado.**
- **Phase 7B — harness, scoring offline, contabilidad de caché y protocolo reproducible: IMPLEMENTADA; no hubo llamadas API ni ejecución del test.**
- **Documentos de contexto: REVISADOS Y APROBADOS por el usuario, con la categoría residual fijada como `other`.**
- **Base del repositorio: COMPLETADA; documentación, `.gitignore` y `.env.example` versionados en `main`.**
- **Subparte PostgreSQL de Fase 1: IMPLEMENTADA, VALIDADA EN LA VM ORACLE Y APROBADA por el usuario.**
- **Base de n8n de Fase 1: IMPLEMENTADA Y VALIDADA EN LA VM ORACLE; el túnel SSH fue comprobado manualmente por el usuario.**

## Alcance de este registro

Este estado consolida los chats «00 — Roadmap y arquitectura inicial», «01 — Fase 0: Hardening OCI» y «02 — Base técnica: GitHub + Docker Compose + PostgreSQL», junto con las validaciones posteriores de PostgreSQL, n8n, el intake de tickets, la clasificación mediante IA, la notificación Telegram, el cierre end-to-end de V1 y Phase 6. Gates 0–6 cuentan con aprobación explícita.

## Infraestructura aprobada

Oracle Cloud ARM64, Ubuntu 22.04, 2 OCPU y 12 GB de RAM. Docker Engine y Docker Compose operativos según el cierre y el inicio de Fase 1.

| Comprobación | Estado | Evidencia disponible |
| --- | --- | --- |
| Acceso SSH por clave | PASS | Reconexiones verificadas, incluida una posterior al reinicio de la VM. |
| Contraseña y acceso root por SSH deshabilitados | PASS | Configuración efectiva `PasswordAuthentication no` y `PermitRootLogin no`. |
| Firewall local | PASS | UFW activo, política `deny incoming` y únicamente SSH permitido. |
| Puertos de aplicación y administración | PASS | Cierre de Gate 0 confirma `80`, `443`, `5678`, `9000` y `5432` sin acceso desde Internet. |
| Servicios y contenedores | PASS | Sin servicios administrativos públicos ni contenedores ejecutándose al cierre; `rpcbind` inactivo tras el reinicio. |
| Persistencia del hardening y Docker | PASS | SSH, UFW y Docker validados después del reinicio; ejecución de prueba de Docker exitosa. |
| Revisión de sistema y exposición | PASS | Actualización por el flujo normal del sistema e inspecciones locales y externas documentadas en el chat de Fase 0. |

La configuración OCI validada no tenía un NSG adicional asociado a la VNIC. No se registra como implementado el NSG dedicado que el diseño inicial había sugerido.

Los aparentes puertos adicionales detectados por un escaneo externo se documentaron como resultados no atribuibles a la VM tras contrastarlos con listeners, reglas locales, captura de tráfico y una prueba de control. No se identificó de forma concluyente el componente externo causante.

## Trabajo documental realizado

- `AGENTS.md`: instrucciones permanentes y concisas para Codex.
- `docs/PROJECT_CONTEXT.md`: producto, objetivo profesional, arquitectura, V1 y tecnologías justificadas.
- `docs/INTAKE.md`: contrato HTTP, validación, persistencia, respuestas y límites del intake V1.
- `docs/testing/GATE_2.md`: evidencia saneada de la batería controlada y cierre de Gate 2.
- `ROADMAP.md`: fases, gates y criterios de cierre.
- `STATUS.md`: estado confirmado, pendientes y siguiente paso.

Los cuatro documentos fueron revisados y aprobados por el usuario. Se incorporó la corrección que fija el identificador de categoría residual como `other`. Esta aprobación documental no aprueba Gate 1 ni acredita un repositorio remoto o un despliegue.

## Base local de Fase 1

El repositorio local `SmartDesk-AI` está inicializado en `main`. La documentación de contexto y el manejo inicial de configuración y secretos quedaron registrados en los commits `1e76317` y `063b6b9`.

- `.gitignore` excluye `.env`, variantes locales, credenciales, claves, temporales y dumps locales; `.env.example` permanece versionable.
- `.env.example` contiene únicamente placeholders y configuración no secreta conocida.
- Las credenciales reales de ejecución permanecen en `.env`, fuera de Git.
- No hay remotos configurados.

## PostgreSQL de Fase 1

La base PostgreSQL fue desplegada y validada dinámicamente en la VM Oracle ARM64 mediante Docker Compose. Todas las pruebas de esta subparte finalizaron con resultado `PASS`.

| Comprobación | Estado | Evidencia saneada |
| --- | --- | --- |
| Imagen y arquitectura | PASS | `postgres:17.11-bookworm` ejecutada como `arm64`. |
| Persistencia | PASS | Volumen Docker nombrado conservó el dato de prueba tras recrear el contenedor; el dato temporal fue eliminado. |
| Red de base de datos | PASS | Red Docker interna, sin publicación de puertos al host. |
| Exposición de PostgreSQL | PASS | Sin binding de host para `5432`; el puerto existe solo dentro del contenedor. |
| Bases separadas | PASS | `n8n_db` y `smartdesk_db` creadas automáticamente. |
| Roles separados | PASS | `n8n_app` y `smartdesk_app`, sin superusuario, `CREATEDB`, `CREATEROLE`, replicación ni bypass RLS. |
| Acceso por aplicación | PASS | Cada rol conecta a su propia base; el acceso cruzado entre bases fue denegado. |
| Bootstrap desde cero | PASS | El entrypoint oficial ejecutó automáticamente `db/init-databases.sh` sobre un volumen vacío y creó bases, roles y permisos sin intervención manual. |
| Repetición del bootstrap | PASS | Una ejecución adicional no duplicó recursos y reaplicó de forma segura atributos y permisos. |
| Salud del servicio | PASS | El contenedor principal y el contenedor temporal alcanzaron estado `healthy`. |
| Limpieza de la prueba aislada | PASS | El proyecto temporal, su red y su volumen se eliminaron sin afectar el volumen ni las bases principales. |

Al cierre de Gate 1 no se habían creado tablas empresariales. En Fase 2 se añadió `public.tickets` mediante una migración versionada, sin alterar la separación de bases ni la exposición de PostgreSQL.

## n8n de Fase 1

n8n fue incorporado al stack y validado dinámicamente en la VM Oracle ARM64. La prueba técnica y la comprobación manual del acceso mediante túnel SSH finalizaron correctamente.

| Comprobación | Estado | Evidencia saneada |
| --- | --- | --- |
| Imagen y arquitectura | PASS | `docker.n8n.io/n8nio/n8n:2.39.6` ejecutada como `linux/arm64`. |
| Backend PostgreSQL | PASS | n8n conecta al servicio PostgreSQL interno mediante `n8n_app` y utiliza exclusivamente `n8n_db`. |
| Persistencia | PASS | El volumen nombrado `n8n_data`, montado en `/home/node/.n8n`, conservó el marcador temporal y la configuración tras recrear únicamente el contenedor n8n; el marcador fue eliminado. |
| Redes | PASS | n8n está conectado a la red `app`, con salida, y a la red `database`, interna; PostgreSQL permanece conectado únicamente a `database`. |
| Exposición de n8n | PASS | El único binding es `127.0.0.1:5678`; no existe exposición pública de `5678`. |
| Acceso administrativo | PASS | La interfaz respondió mediante el túnel SSH hacia el loopback de la VM; la comprobación fue realizada manualmente por el usuario. |
| Healthcheck y readiness | PASS | El healthcheck basado en `/healthz/readiness` alcanzó estado `healthy` y respondió HTTP 200 desde la VM. |
| Exposición de PostgreSQL | PASS | PostgreSQL continúa sin publicar `5432` al host. |
| Recreación del servicio | PASS | n8n volvió a estado `healthy` después de recrear únicamente su contenedor, sin borrar el volumen ni alterar PostgreSQL. |

Durante una validación, una salida de herramienta incluyó accidentalmente valores sensibles específicos de n8n. Los valores fueron rotados inmediatamente antes de que existieran workflows o credenciales de aplicación; la contraseña anterior quedó invalidada y las claves internas generadas por n8n fueron reemplazadas sin borrar bases ni volúmenes. No se registran valores antiguos ni nuevos en el repositorio.

## Cierre de Fase 1 y Gate 1

La auditoría integral de Gate 1 fue ejecutada sobre el repositorio local y el stack real de la VM Oracle. Todos los criterios finalizaron con resultado `PASS` y el usuario aprobó formalmente Gate 1.

| Criterio de cierre | Estado | Evidencia saneada |
| --- | --- | --- |
| Salud de servicios | PASS | PostgreSQL y n8n alcanzaron y conservaron estado `healthy`. |
| Separación de datos y permisos | PASS | `n8n_db`/`n8n_app` y `smartdesk_db`/`smartdesk_app` permanecen separados, con acceso cruzado denegado y sin privilegios administrativos para los roles de aplicación. |
| Persistencia PostgreSQL | PASS | Un marcador temporal persistió después de bajar y levantar el stack; fue eliminado al concluir la auditoría. |
| Persistencia n8n | PASS | Un marcador temporal persistió en el volumen de n8n después del ciclo completo; fue eliminado al concluir la auditoría. |
| Redes y exposición | PASS | La red `database` es interna; PostgreSQL no publica `5432` y n8n está enlazado únicamente a `127.0.0.1:5678`, sin acceso público directo. |
| Ciclo del stack | PASS | `docker compose down` y `docker compose up -d` se completaron sin borrar volúmenes ni perder datos; ambos servicios recuperaron su estado saludable. |
| Políticas de reinicio | PASS | Ambos servicios declaran y aplican efectivamente `unless-stopped`. |
| Contenedores esperados | PASS | Al cierre solo estaban ejecutándose los contenedores de PostgreSQL y n8n. |

Fase 1 queda completada. Su aprobación no anticipó el cumplimiento de Gate 2; el cierre posterior de Gate 2 se documenta a continuación.

## Fase 2 — Intake y persistencia inicial

Fase 2 implementó y verificó el primer flujo empresarial de SmartDesk AI:

- webhook `POST /webhook/tickets` administrado por n8n;
- contrato V1 para `requester_email`, `requester_area`, `title` y `description`;
- validación de presencia, tipos, formato y longitudes, con acumulación de errores;
- normalización de espacios externos en área, título y descripción;
- persistencia de tickets válidos en PostgreSQL mediante un `INSERT` parametrizado;
- generación en PostgreSQL de UUID, estado `processing` y marcas de tiempo;
- respuestas HTTP 201, 400 y 500 controladas;
- rama nativa de error de n8n para evitar filtrar detalles de persistencia;
- workflow y credencial conservados después de reiniciar n8n y PostgreSQL.

El contrato completo se documenta en `docs/INTAKE.md`.

## Cierre de Fase 2 y Gate 2

La batería formal se ejecutó el 2026-09-17 sobre el commit `73913e279892bf7b4be3a94b120cedaedcdc7063`. Las 30 solicitudes end-to-end cumplieron sus resultados esperados.

| Criterio de cierre | Estado | Evidencia saneada |
| --- | --- | --- |
| Happy path | PASS | HTTP 201, UUID, estado y timestamps; exactamente una fila persistida. |
| Validación y errores múltiples | PASS | HTTP 400 y todos los campos relevantes informados, sin insertar filas. |
| Normalización y límites | PASS | Espacios externos eliminados y bordes mínimos/máximos aceptados o rechazados según el contrato. |
| SQL parametrizado | PASS | Caracteres especiales benignos persistidos literalmente sin alterar tabla ni esquema. |
| Fallo de persistencia | PASS | HTTP 500 genérico con `TICKET_PERSISTENCE_ERROR`, sin información interna ni inserción. |
| Recuperación | PASS | La solicitud inmediatamente posterior al fallo respondió HTTP 201. |
| Reinicio de servicios | PASS | n8n y PostgreSQL recuperaron salud; workflow, credencial, tabla y conexión permanecieron operativos. |
| Limpieza e integridad | PASS | Conteo `0 → 0`; tabla, ocho columnas, PK, defaults y CHECK constraints intactos. |
| Exposición y secretos | PASS | PostgreSQL sin puerto publicado; workflow versionado sin secretos. |

La evidencia detallada y sus límites se conservan en `docs/testing/GATE_2.md`. Gate 2 queda aprobado; esta prueba controlada no constituye una métrica de producción.

## Fase 3 — Clasificación estructurada mediante IA

Fase 3 integró en el intake real la clasificación de tickets mediante OpenAI Responses API, manteniendo el ticket persistido antes de invocar al proveedor. El workflow utiliza el prompt `ticket-classification-v1` y el schema `ticket-classification-schema-v1` cargados desde archivos versionados y montados read-only.

La salida contiene exactamente `category`, `priority` y `summary`, utiliza Structured Outputs y vuelve a pasar por un validador determinista antes de considerarse confiable. Las predicciones se registran en `ticket_ai_predictions` mediante la transición `pending → succeeded/failed`, separada de `tickets.status`.

Los fallos del proveedor y las respuestas inválidas se manejan de forma controlada: el ticket original se conserva, no se utiliza una clasificación inválida y no se persisten campos parciales como si fueran una predicción exitosa.

## Cierre de Fase 3 y Gate 3

La regresión final reejecutó los 30 casos originales de Gate 2 sobre el workflow final y obtuvo resultado 30/30. También se comprobaron la clasificación exitosa, el fallo controlado del proveedor, el rechazo determinista de una respuesta inválida, la integridad de estados, la limpieza, la seguridad y la sincronización funcional entre workflow desplegado y exportado.

La evidencia detallada se conserva en `docs/testing/GATE_3.md`. Gate 3 queda aprobado y Fase 3 completada; esta evidencia funcional no constituye una medición formal de accuracy ni un benchmark.

Limitación conocida: si PostgreSQL falla después de crear una prediction `pending` pero antes de completar la escritura terminal, la fila puede permanecer pendiente y el workflow puede responder HTTP 500. El ticket original permanece persistido, no se inventa un estado terminal y la recuperación o los retries pertenecen a una fase posterior.

## Fase 4 — Reglas y notificación Telegram

Fase 4 implementó y desplegó:

- la tabla `automation_events` con FK a ticket y prediction, cuatro estados,
  restricciones de outcome, índice y unicidad idempotente;
- la regla determinista `notify_high_or_critical_v1`;
- LOW/MEDIUM → `skipped`, sin Telegram;
- HIGH/CRITICAL → `pending` antes del intento Telegram;
- éxito → `succeeded` y error → `failed / TELEGRAM_SEND_FAILED`;
- texto plano limitado a ticket, área, título, categoría, prioridad y resumen;
- HTTP 201 conservado cuando ticket y prediction ya están persistidos;
- ausencia deliberada de retries y recuperación automática.

La credencial n8n `SmartDesk Telegram` y el destino externo quedaron
configurados sin versionar valores sensibles. Las pruebas reales HIGH y
CRITICAL recibieron `ok=true` de Telegram Bot API y finalizaron con eventos
`succeeded`; LOW/MEDIUM, IA fallida y la rama de fallo Telegram conservaron la
semántica aprobada.

La regresión relevante final mantuvo Gate 2 y Gate 3 en PASS, incluido el
validador determinista 19/19. La evidencia completa, la limpieza y los límites
se conservan en `docs/testing/GATE_4.md`. Gate 4 queda aprobado y Fase 4
completada.

## Fase 5 — V1 desplegada y probada end-to-end

El 2026-09-19 se desplegó Caddy 2.11.4 como tercer
servicio de Compose para terminar TLS y publicar únicamente
`POST /webhook/tickets`:

- DNS público verificado contra la IP reservada de la VM;
- certificado Let's Encrypt válido para el hostname productivo;
- redirección HTTP 308 hacia HTTPS;
- `/`, `/home`, `/login`, `/rest/*`, `/api/*`, `/workflows/*` y
  `/executions/*` respondieron 404 desde Internet;
- un método GET sobre `/webhook/tickets` respondió 404;
- n8n conservó `127.0.0.1:5678` y su administración respondió por loopback;
- PostgreSQL conservó el mismo contenedor healthy, sin puerto publicado;
- Caddy pertenece únicamente a la red `app` y no puede alcanzar la red
  interna `database`;
- desde el exterior, 80 y 443 estuvieron abiertos y 5678, 5432 y 9000
  permanecieron cerrados.

La prueba de routing permitida envió un único `POST {}`. Respondió HTTP 400 y
la ejecución 170 recorrió solamente recepción, validación, decisión y respuesta
de error. No ejecutó inserción de ticket, OpenAI, Telegram ni automatización;
los conteos de tickets, predictions y automation events permanecieron en cero.

## Cierre de Fase 5, Gate 5 y V1

La matriz final E2E-01 a E2E-06 fue ejecutada y aprobada sobre el commit
realmente probado y desplegado
`fc42c911725aa589e3b36207d0be5b95b9f08063`. Verificó:

- rechazo inválido sin persistencia ni llamadas externas;
- clasificación HIGH y entrega Telegram real exactamente una vez;
- clasificación LOW con evento `skipped` y cero Telegram;
- fallo controlado de IA con ticket conservado;
- fallo controlado de Telegram con clasificación conservada;
- redeploy documentado sin borrar volúmenes, persistencia y smoke posterior;
- correlación SQL de 5 tickets, 5 predictions y 4 eventos;
- cero predictions o eventos pendientes, duplicados o acciones incoherentes;
- HTTPS, routing restringido y ausencia de exposición pública en 5678, 5432 y
  9000.

Las ejecuciones 170–175 realizaron exactamente 5 llamadas OpenAI —4 exitosas y
1 fallida— y 2 intentos Telegram —1 exitoso y 1 fallido—, todos sin retries. La
evidencia completa se conserva en `docs/testing/GATE_5.md`.

Gate 5 queda aprobado, Fase 5 completada y SmartDesk AI V1 completada. El tag
Git local `v1.0` apunta al tested/release commit anterior, no al commit
documental posterior.

## Fase 6 — Reliability, HITL y SLA

Phase 6 se implementó y probó sobre el commit funcional
`ba9fd7b1d32c837a30afc1d35d05a018492e4392`:

- contrato IA v2 con `confidence`, `review_required` y `review_reason`;
- tres intentos máximos de OpenAI, backoff 2 s/4 s y retry solo para errores
  transitorios definidos;
- predicción original, review humana y decisión final en entidades separadas;
- approve/override idempotentes y endpoints admin solo por loopback+túnel SSH,
  protegidos con token externo a Git;
- política `sla-demo-v1`, cálculo desde `tickets.created_at`, resolución,
  breach, scheduler cada cinco minutos y escalamiento único;
- recovery de predictions y eventos Phase 6 stale sin reenvío externo ciego;
- migración `004`, bootstrap `001→004`, workflows admin/scheduler, despliegue,
  regresión y seguridad verificados en OCI ARM64.

La matriz final dejó cero estados pending y cero duplicados lógicos. La
evidencia completa está en `docs/testing/GATE_6.md`. Gate 6 queda aprobado y
Phase 6 completada. `v1.0` permanece en el commit probado de V1.

## Phase 7A — Dataset sintético y base de evaluación

Phase 7A se implementó localmente a partir del commit base
`f03f2ca136868486b6d4e8180a562d1ba448119c`, sin llamadas a la API oficial y
sin cambios en el comportamiento productivo:

- política versionada `labeling-policy-v1`, con reglas de desempate para las
  seis categorías y cuatro prioridades productivas;
- schema JSON de caso individual alineado con
  `ticket-classification-schema-v2`;
- 30 casos `dev` y 120 casos de test congelado, sintéticos y sin datos
  personales reales;
- test balanceado con 20 casos por categoría y cobertura explícita de bordes,
  typos, abreviaturas, lenguaje natural, ruido, entradas breves, semántica
  escasa, prompt injection y síntomas mixtos;
- manifiesto `1.0.0` con commit base, contrato productivo, distribuciones y
  hashes SHA-256;
- validador Python sin dependencias externas y seis tests locales: baseline
  válido más rechazo de ID duplicado, categoría inválida, prioridad inválida,
  JSONL roto y hash inconsistente.

La validación local terminó en PASS para el artefacto de datos y 6/6 tests.
Esto no constituye una evaluación del modelo, no acredita accuracy, latencia,
costo ni calibración, y no aprueba Gate 7. Phase 7 permanece IN PROGRESS.

## Phase 7B — Harness y scoring offline

Phase 7B implementó localmente, desde el commit
`f486fe20b330430800f223c928febab1ac7303f6`:

- runner que carga y hashea el prompt/schema productivos, construye el mismo
  request de Responses API y excluye todo ground truth del input;
- Structured Outputs estricto, validación determinista y routing HITL idéntico
  a producción (`confidence < 0.75`);
- tres intentos máximos, backoff 2 s/4 s y elegibilidad transitoria idéntica a
  Phase 6;
- manifest de run, escritura incremental de predicciones/intentos y protección
  contra sobrescritura;
- precios y límites obligatorios, estimación conservadora antes del run y
  guardrails por casos, llamadas y coste;
- scoring completamente offline de calidad, HITL, reliability, latencia,
  tokens y coste, con denominadores auditables;
- contabilidad de coste que distingue input ordinario, lectura de caché,
  escritura de caché y output; un `cache_write_tokens` ausente queda explícito
  y no se monetiza como cero;
- documentación en `eval/README.md` y `docs/PHASE_7.md`.

La suite local, incluida la corrección de accounting de caché, terminó con
35/35 tests PASS y el CLI de preflight fue probado
sobre cinco casos `dev` con valores monetarios marcados exclusivamente para
validación. No se proporcionó API key, no se creó un run real, no se llamó a
OpenAI y no se ejecutó `test.jsonl`. Su SHA-256 permaneció intacto.

Phase 7 sigue IN PROGRESS y Gate 7 NOT YET PASS porque aún no existen métricas
reales del modelo ni análisis de errores sobre la corrida formal.

## Siguiente paso

Decidir y autorizar una única corrida live inicial de tres casos `dev`, después
de verificar precios oficiales vigentes, preflight, presupuesto y API key
externa a Git. Su fin será validar la integración y los artefactos, no medir
accuracy. Phase 7C y la corrida formal del test congelado permanecen pendientes
y no deben iniciarse automáticamente.

## Límites actuales

- V1 y Phase 6 disponen de ingress HTTPS restringido y matrices E2E aprobadas, pero no acreditan accuracy, rendimiento, disponibilidad, ahorro o impacto empresarial.
- El dataset de evaluación está implementado y congelado, pero la ejecución contra el modelo, sus métricas y el análisis de errores todavía no se han realizado. SQL analítico, Power BI, CI/CD, monitoreo, alertas, backups con restore ensayado, alta disponibilidad, rate limiting y WAF tampoco están implementados.
- La VM única sigue siendo un punto único de fallo. Phase 6 recupera estados internos stale después de 15 minutos, pero una entrega externa interrumpida puede quedar como `DELIVERY_STATE_UNKNOWN` y requiere conciliación manual.
- El webhook no sustituye un portal autenticado ni una plataforma ITSM completa.
- El contrato de intake y sus límites ya están documentados; la categoría residual permanece aprobada como `other`.
- Ningún gate posterior a Gate 6 está aprobado; Phase 7 está en curso y las fases 8–10 permanecen pendientes.
