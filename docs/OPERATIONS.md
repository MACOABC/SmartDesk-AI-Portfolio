# Operaciones de SmartDesk AI

## Autoridad del repositorio

La copia sanitizada de portfolio conserva estos workflows como evidencia de
implementación, pero no contiene secrets productivos y no es autoridad de
deployment. Los jobs de monitor y despliegue están restringidos al repositorio
privado original `MACOABC/SmartDesk-AI`; en esta copia el monitor tampoco tiene
schedule. Producción continúa operándose exclusivamente desde el repositorio
privado original.

## Salud diaria

```bash
cd "$HOME/smartdesk-ai"
scripts/ops/check-health.sh
docker compose ps
systemctl status smartdesk-health.timer --no-pager
journalctl -u smartdesk-health.service -n 50 --no-pager
```

Resultado healthy: contenedores, PostgreSQL, n8n, HTTPS y thresholds en PASS.
No usar el webhook POST para monitoring: crearía tickets y podría consumir IA.

## Timers

```bash
systemctl list-timers smartdesk-health.timer smartdesk-backup.timer
sudo systemctl start smartdesk-health.service
sudo systemctl start smartdesk-backup.service
```

Los units se instalan con:

```bash
sudo scripts/ops/install-systemd.sh
```

La instalación actual asume el usuario operativo y proyecto definidos en los
units versionados. Cualquier cambio de usuario/ruta debe actualizar los units
antes de desplegar.

## Monitoring externo y sync off-host

La estación Windows registra dos tareas mediante:

```powershell
scripts/ops/register-windows-operations.ps1 `
  -SshTarget '<ssh-alias>' `
  -MonitorBaseUrl 'https://<service-host>' `
  -BackupDestination '<private-synced-directory>'
```

- `SmartDesk External HTTPS Monitor`: cada 30 minutos, espera 404 seguro en
  `/`, sin ticket ni IA;
- `SmartDesk Off-host Backup Sync`: diariamente, descarga backups cifrados y
  verifica SHA-256.

## CI local/equivalente

Requiere Docker, Python 3 y PyYAML pinneado:

```bash
python3 -m pip install -r requirements-ci.txt
scripts/ci/run-ci.sh
```

El pipeline elimina siempre el Compose CI y su volumen temporal. No suministrar
variables productivas.

## Activar GitHub Actions

Al conectar un remote privado, configurar el environment `production` con
estos valores fuera de Git:

| Nombre | Tipo | Uso |
| --- | --- | --- |
| `SMARTDESK_DEPLOY_SSH_KEY` | Secret | clave restringida de deployment |
| `SMARTDESK_DEPLOY_KNOWN_HOSTS` | Secret | host key fijada |
| `SMARTDESK_DEPLOY_HOST` | Secret | host de destino |
| `SMARTDESK_DEPLOY_USER` | Secret | usuario no root |
| `SMARTDESK_MONITOR_URL` | Secret | URL HTTPS completa de la sonda segura de la ruta pública vigente |
| `SMARTDESK_DEPLOY_PATH` | Variable | ruta relativa, normalmente `smartdesk-ai` |

CI se ejecuta en PR/push a main. CD nunca se ejecuta por push: requiere
`workflow_dispatch` y un SHA completo. El environment `production` centraliza
secrets, pero actualmente no tiene required reviewers ni otra regla de
aprobación configurada. Añadir esa protección exige una decisión explícita del
propietario y un reviewer identificable; hasta entonces no debe describirse el
deploy como sujeto a aprobación humana adicional.

## Deployment manual con los mismos scripts

```bash
sha="$(git rev-parse HEAD)"
scripts/deploy/package-release.sh "$sha" /tmp/smartdesk-release.tar.gz
scp /tmp/smartdesk-release.tar.gz '<ssh-alias>:/tmp/'
scp scripts/deploy/remote-deploy.sh '<ssh-alias>:/tmp/'
ssh '<ssh-alias>' \
  "bash /tmp/remote-deploy.sh /tmp/smartdesk-release.tar.gz $sha smartdesk-ai"
```

El resultado devuelve `rollback_id`. Para un release sin migraciones:

```bash
scp scripts/deploy/rollback-remote.sh '<ssh-alias>:/tmp/'
ssh '<ssh-alias>' "bash /tmp/rollback-remote.sh '<rollback-id>' smartdesk-ai"
```

Un rollback cuyo snapshot declare migraciones no es automático: restaurar el
backup verificado siguiendo `docs/BACKUP_RESTORE.md`.

## Incidentes

- Health interno FAIL: revisar journal, Compose, disco/memoria y readiness.
- HTTPS externo FAIL con internos healthy: revisar Caddy, DNS/TLS y firewall.
- PostgreSQL/n8n FAIL: no borrar volúmenes; capturar logs saneados y recuperar
  el servicio antes de reintentar.
- Backup FAIL: no borrar el último backup válido; revisar espacio, permisos,
  certificado y logs del service.
- Secrets expuestos: detener deployment; rotar mediante procedimiento
  explícito y evaluar historial antes de cualquier rewrite.
