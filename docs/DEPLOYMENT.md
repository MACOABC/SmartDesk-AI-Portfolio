# SmartDesk AI — Deployment

## Entrada pública

La entrada pública de V1 está limitada a:

```text
POST https://<SMARTDESK_HOST>/webhook/tickets
```

El nodo productivo `Receive Ticket` conserva internamente la ruta
`/webhook/tickets`. Caddy termina TLS y reenvía únicamente esa combinación
exacta de método y ruta a `n8n:5678`. Cualquier otra ruta o método recibe 404 y
no alcanza n8n.

## Arquitectura

```text
Internet :80/:443
        |
      Caddy ── app network ── n8n:5678
                                |
                          database network
                                |
                           PostgreSQL:5432
```

- Caddy solo pertenece a la red `app`.
- PostgreSQL pertenece a la red interna `database`. El host enlaza
  `127.0.0.1:5432` exclusivamente para acceso local o mediante túnel SSH de
  Power BI; `5432` no queda accesible desde Internet.
- n8n mantiene `127.0.0.1:5678:5678` para administración mediante túnel SSH.
- Los volúmenes `caddy_data` y `caddy_config` conservan certificados y estado
  fuera de Git.
- El hostname se configura una sola vez mediante `SMARTDESK_HOST` en `.env`.
- n8n recibe `N8N_WEBHOOK_URL=https://<SMARTDESK_HOST>/` y
  `N8N_PROXY_HOPS=1`; su listener interno continúa usando HTTP.

## Configuración externa

Crear `.env` desde `.env.example` y establecer al menos:

```text
SMARTDESK_HOST=<hostname DNS público>
```

El registro DNS debe resolver a la IP pública reservada de la VM. OCI y UFW
deben permitir TCP 80 y 443. Los puertos 5678, 5432 y 9000 no deben abrirse a
Internet.

## Despliegue acotado

Validar antes de desplegar:

```bash
docker compose config --quiet
docker run --rm -e SMARTDESK_HOST=smartdesk.example.com \
  -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" \
  caddy:2.11.4-alpine caddy validate --config /etc/caddy/Caddyfile
```

Copiar únicamente los artefactos cambiados al directorio del deployment y
recrear solo n8n y Caddy:

```bash
docker compose pull caddy
docker compose up -d --no-deps --force-recreate n8n
docker compose up -d caddy
```

No usar `docker compose down -v`; los volúmenes de PostgreSQL, n8n y Caddy se
conservan.

## Verificación

Comprobar:

```text
http://<SMARTDESK_HOST>/                   -> redirección HTTPS
https://<SMARTDESK_HOST>/                  -> 404
https://<SMARTDESK_HOST>/login             -> 404
GET https://<SMARTDESK_HOST>/webhook/tickets  -> 404
POST https://<SMARTDESK_HOST>/webhook/tickets -> n8n
```

Para verificar el webhook sin consumir servicios externos, utilizar un JSON
inválido que falle en `Validate and Normalize Ticket`, y confirmar en la
ejecución que no se ejecutaron nodos OpenAI, Telegram ni persistencia.

La administración continúa mediante un túnel SSH hacia
`127.0.0.1:5678`; no se publica la interfaz mediante Caddy.

## Operaciones de Phase 6

Además del workflow de intake, Phase 6 despliega:

```text
n8n/workflows/phase6-admin.json
n8n/workflows/phase6-sla-scheduler.json
```

Antes de importar los workflows sobre una instalación existente:

1. crear `SMARTDESK_ADMIN_TOKEN` en `.env` con un valor aleatorio de al menos
   32 caracteres, sin imprimirlo ni versionarlo;
2. aplicar `db/migrations/004_phase6_reliability_hitl_sla.sql` como el rol
   `smartdesk_app` sobre `smartdesk_db`;
3. copiar los prompts v2 y los tres exports;
4. importar/actualizar los workflows con n8n y activarlos;
5. recrear únicamente n8n para cargar la nueva variable y registrar triggers.

Un bootstrap con volumen PostgreSQL nuevo ejecuta `db/apply-migrations.sh`
desde `/docker-entrypoint-initdb.d` y aplica `001` a `004` en orden. Este
mecanismo no vuelve a ejecutar migraciones sobre un volumen existente.

Los endpoints HITL y resolución se consumen únicamente desde la VM o a través
del túnel SSH:

```text
POST http://127.0.0.1:5678/webhook/admin/reviews/decide
POST http://127.0.0.1:5678/webhook/admin/tickets/resolve
```

Ambos exigen `X-SmartDesk-Admin-Token`. Caddy continúa admitiendo públicamente
solo `POST /webhook/tickets`, por lo que esas rutas administrativas reciben
404 desde Internet.

## Trazabilidad del deployment

El directorio de la VM contiene un archivo `DEPLOYED_COMMIT` generado durante
el despliegue. Debe contener únicamente el SHA completo del commit fuente.
Verificarlo junto con los hashes de los artefactos críticos:

```bash
cat DEPLOYED_COMMIT
sha256sum compose.yaml Caddyfile n8n/workflows/ticket-intake.json
```

El SHA debe coincidir con `git rev-parse HEAD` del repositorio fuente y los
hashes deben coincidir con los archivos versionados correspondientes.

## Verificación del ingress de Phase 5

La comprobación controlada del 2026-09-19 obtuvo:

```text
caddy=healthy
n8n=healthy
postgres=healthy
tls_verify=PASS
http_to_https=308
public_root=404
public_admin_routes=404
wrong_webhook_method=404
invalid_webhook_payload=400
invalid_execution_openai_runs=0
invalid_execution_telegram_runs=0
business_rows_after_invalid_test=0|0|0
external_80=open
external_443=open
external_5678=closed
external_5432=closed
external_9000=closed
```

Esta evidencia no sustituye la matriz E2E final de Gate 5.

## Deployment controlado de Phase 9

El mecanismo vigente empaqueta un commit exacto y no depende de un working
tree en la VM. El workflow manual está en `.github/workflows/deploy.yml`; los
scripts reutilizables están en `scripts/deploy/`.

Un release:

- incluye `DEPLOYED_COMMIT` con el SHA completo;
- nunca incluye `.env`;
- normaliza LF y permisos runtime;
- rechaza una migración existente modificada;
- exige `ALLOW_MIGRATIONS=1` para una migración nueva y toma backup antes;
- conserva un snapshot de archivos y devuelve `rollback_id`;
- ejecuta Compose wait, health interno y smoke HTTPS.

El rollback automático solo aplica cuando el snapshot declara cero migraciones.
Si hubo migración, usar el backup verificado y el procedimiento de
`docs/BACKUP_RESTORE.md`. Operación, secrets requeridos y comandos están en
`docs/OPERATIONS.md`.
