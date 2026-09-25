# SmartDesk AI — Quickstart reproducible

Esta guía permite a un tercero inspeccionar y levantar la base de SmartDesk AI
sin reutilizar credenciales ni datos de producción. El despliegue HTTPS real,
la operación y la recuperación se documentan por separado en
`DEPLOYMENT.md`, `OPERATIONS.md` y `BACKUP_RESTORE.md`.

## Prerrequisitos

- Git;
- Docker Engine y Docker Compose v2;
- Python 3.10 o superior para validación y evaluación offline;
- Bash para ejecutar el pipeline completo local;
- credenciales propias de OpenAI y Telegram si se quiere probar esas
  integraciones;
- Power BI Desktop únicamente para reproducir la capa BI.

## 1. Clonar y configurar

```bash
git clone <SMARTDESK_REPOSITORY_URL> SmartDesk-AI
cd SmartDesk-AI
cp .env.example .env
```

En PowerShell, usar `Copy-Item .env.example .env`. Sustituir todos los valores
`replace_with_...` por valores locales distintos. `.env` está ignorado por Git;
no debe copiarse a tickets, logs, capturas ni commits.

Para una comprobación local sin ingress público, `SMARTDESK_HOST` puede
conservar el hostname de ejemplo. Un deployment con Caddy y TLS necesita un
hostname propio cuyo DNS resuelva al host.

## 2. Servicios y PostgreSQL

En un clon nuevo, levantar primero PostgreSQL y n8n:

```bash
docker compose up -d --wait postgres n8n
docker compose ps
```

El primer arranque de un volumen vacío crea dos bases y roles separados, y
aplica en orden `db/migrations/001` a `005`. Los scripts de init no vuelven a
ejecutarse sobre un volumen existente. No usar `docker compose down -v` sobre
un entorno con datos que deban conservarse.

PostgreSQL se enlaza únicamente a `127.0.0.1:5432`; n8n se enlaza únicamente a
`127.0.0.1:5678`. Ninguno de esos puertos debe abrirse a Internet.

## 3. Importar n8n

Abrir `http://127.0.0.1:5678` localmente o mediante túnel SSH e importar:

```text
n8n/workflows/ticket-intake.json
n8n/workflows/phase6-admin.json
n8n/workflows/phase6-sla-scheduler.json
```

Crear credenciales propias en el almacén de n8n y mapear cada nodo importado:

| Tipo de credencial | Configuración esperada |
| --- | --- |
| PostgreSQL | host `postgres`, puerto `5432`, base y rol SmartDesk definidos en `.env` |
| OpenAI | API key propia; nunca dentro del export JSON |
| Telegram | token de bot propio; el chat ID proviene de `TELEGRAM_CHAT_ID` |

Verificar también `SMARTDESK_ADMIN_TOKEN` en `.env`. Debe ser aleatorio, tener
al menos 32 caracteres y permanecer fuera de Git. Tras mapear credenciales,
activar explícitamente los tres workflows y comprobar sus triggers. El campo
`active` del export no sustituye esa verificación en la instancia destino.

Los prompts y schemas se montan read-only desde
`prompts/ticket-classification/`; no deben copiarse manualmente a nodos Code.

## 4. HTTPS y límites públicos

Para un entorno con DNS propio y puertos 80/443 disponibles:

```bash
docker compose up -d --wait
```

Caddy publica únicamente `POST /webhook/tickets`; las rutas de administración
Phase 6 permanecen en loopback. Antes de exponer el servicio, revisar
`DEPLOYMENT.md`. El repositorio no incluye dominio, IP ni credenciales reales.

## 5. Tests locales

Validación rápida, sin servicios externos:

```bash
python scripts/ci/validate_repo.py
python -m unittest discover -s eval/tests -v
```

Pipeline completo, con Docker y una base temporal aislada:

```bash
python -m pip install -r requirements-ci.txt
scripts/ci/run-ci.sh
```

El pipeline valida JSON/YAML/shell, ejecuta los tests offline, crea PostgreSQL
temporal, aplica migraciones `001`–`005`, comprueba contratos Phase 6 y las
cuatro vistas analytics, y elimina su volumen temporal al terminar. No usa
OpenAI, Telegram ni la base productiva.

## 6. Evaluación offline

Validar el dataset congelado:

```bash
python eval/scripts/validate_dataset.py
```

Recalcular la corrida oficial sin API key ni red, escribiendo la salida fuera
de los artefactos versionados:

```bash
python eval/scripts/score_evaluation.py \
  --predictions eval/runs/official-test-v1-20260920T210544Z/predictions.jsonl \
  --manifest eval/runs/official-test-v1-20260920T210544Z/manifest.json \
  --output-dir <TEMP_OUTPUT_DIRECTORY>
```

No repetir el benchmark pagado solo para comprobar el repositorio. El protocolo
y los guardrails de cualquier futura corrida están en `../eval/README.md`.

## 7. Analytics y Power BI

Las migraciones crean cuatro vistas read-only en el schema `analytics`. Para
crear o rotar el rol BI, definir `SMARTDESK_BI_PASSWORD` únicamente en el
entorno seguro de la sesión y canalizar el SQL al contenedor:

```bash
export SMARTDESK_BI_PASSWORD='<GENERATE_A_PRIVATE_PASSWORD>'
docker compose exec -T -e SMARTDESK_BI_PASSWORD postgres sh -c \
  'psql --username "$POSTGRES_USER" --dbname "$SMARTDESK_DB_NAME" --set=ON_ERROR_STOP=1' \
  < sql/analytics/configure_bi_reader.sql
unset SMARTDESK_BI_PASSWORD
```

No ejecutar ese comando sobre producción sin seguir su procedimiento de
cambio. La conexión Power BI usa un túnel SSH y
`powerbi/SmartDeskAI.pbit`; los pasos completos están en
`../powerbi/README.md`.

## Qué no reproduce este quickstart

- No suministra credenciales de proveedores ni infraestructura cloud.
- No configura DNS, firewall, GitHub Environments ni secrets alojados.
- No convierte el benchmark sintético en métricas de producción.
- No demuestra disponibilidad continua ni impacto empresarial.
- No publica el repositorio, una release ni un endpoint de demo.

