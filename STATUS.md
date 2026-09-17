# SmartDesk AI — Estado actual

- **Gate 0: APROBADO.**
- **Gate 1: APROBADO.**
- **Fase 1 — Repositorio + Docker Compose + PostgreSQL + base de n8n: COMPLETADA.**
- **Fase actual: Fase 2 — Webhook + validación + persistencia inicial.**
- **Documentos de contexto: REVISADOS Y APROBADOS por el usuario, con la categoría residual fijada como `other`.**
- **Base del repositorio: COMPLETADA; documentación, `.gitignore` y `.env.example` versionados en `main`.**
- **Subparte PostgreSQL de Fase 1: IMPLEMENTADA, VALIDADA EN LA VM ORACLE Y APROBADA por el usuario.**
- **Base de n8n de Fase 1: IMPLEMENTADA Y VALIDADA EN LA VM ORACLE; el túnel SSH fue comprobado manualmente por el usuario.**

## Alcance de este registro

Este estado consolida los chats «00 — Roadmap y arquitectura inicial», «01 — Fase 0: Hardening OCI» y «02 — Base técnica: GitHub + Docker Compose + PostgreSQL», junto con las validaciones posteriores de PostgreSQL y n8n. Gate 0 y Gate 1 cuentan con aprobación explícita del usuario.

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

El servicio PostgreSQL principal permanece `healthy`, con su volumen persistente y las dos bases intactas. No se crearon tablas empresariales.

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

Fase 1 queda completada. Esta aprobación no anticipa el cumplimiento de Gate 2 ni autoriza funcionalidades fuera del alcance de Fase 2.

## Siguiente paso

Iniciar Fase 2 únicamente mediante una instrucción explícita y comenzar por el contrato del webhook, su validación y la persistencia inicial. No incorporar todavía IA, Telegram ni otras fases posteriores.

Se mantiene el método: explicar el paso y su motivo, entregar solo los comandos necesarios, indicar el resultado esperado, esperar la salida del usuario y validarla.

## Límites actuales

- No hay V1 desplegada ni pruebas funcionales de tickets documentadas.
- No hay métricas de clasificación, rendimiento, disponibilidad o impacto empresarial obtenidas en esta tarea.
- El webhook empresarial, su validación y la persistencia inicial corresponden a Fase 2 y todavía no están implementados. IA, Telegram, Power BI, Caddy público y CI/CD permanecen fuera del paso actual.
- Proveedor/modelo de IA, versiones de imágenes, límites del contrato y dominio/DNS se concretarán en su fase. El identificador de categoría residual ya está aprobado como `other`.
- Ningún gate posterior a Gate 1 está aprobado.
