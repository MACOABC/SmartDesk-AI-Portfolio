# SmartDesk AI — Phase 9: operación, recuperación y entrega controlada

## Objetivo y alcance

Phase 9 convierte el sistema aprobado en Gate 8 en una operación verificable:
CI determinista, deployment manual por SHA, monitoring interno y externo,
backup cifrado con copia off-host, restore ensayado y hardening final. No añade
funcionalidad de negocio y no implementa Phase 10.

## Baseline observado

La inspección inicial encontró tres contenedores healthy en una VM Ubuntu
22.04: PostgreSQL 17.11, n8n 2.39.6 y Caddy 2.11.4. Solo 80/443 y SSH estaban
publicados; PostgreSQL y n8n escuchaban exclusivamente en loopback. UFW estaba
activo con deny incoming, SSH era key-only y root login estaba deshabilitado.

El deployment era una copia de archivos sin working tree Git. No existían
workflows CI/CD, timers SmartDesk, monitor de aplicación ni destino off-host.
Había backups históricos manuales, uno con modo 664, corregido a 600. La VM no
tenía OCI CLI ni otra credencial de Object Storage disponible. El directorio
de producción declaraba un SHA previo mediante `DEPLOYED_COMMIT`.

## Arquitectura final

```text
PR/push/manual
  -> CI GitHub Actions
     -> validación repo/JSON/YAML/shell
     -> 35 tests Python offline
     -> PostgreSQL 17 temporal sin puertos
     -> migraciones 001..005 + contratos Phase 6 + analytics

workflow_dispatch(commit SHA)
  -> prechecks CI
  -> release inmutable
  -> SSH
  -> backup si hay migraciones nuevas
  -> deploy + health + smoke externo
  -> snapshot de rollback

VM
  -> systemd health cada 5 min -> journald/OnFailure
  -> systemd backup diario -> dumps + n8n_data -> restore/list validation
     -> CMS AES-256 cifrado con certificado público

Workstation fuera de la VM
  -> check HTTPS cada 30 min
  -> pull diario de backup cifrado
  -> directorio privado sincronizado por OneDrive
  -> clave privada solo en Windows CurrentUser certificate store
```

## CI

`.github/workflows/ci.yml` usa permisos `contents: read`, versiones explícitas
de actions, timeout y cancelación por concurrencia. `scripts/ci/run-ci.sh`
coordina validación estática, tests offline y PostgreSQL temporal. El Compose
CI no publica puertos ni contiene credenciales productivas.

`scripts/ci/validate_repo.py` valida JSON, YAML, exports n8n, secuencia de
migraciones, imágenes explícitas, artefactos prohibidos y patrones de secretos
sin imprimir valores. El pipeline no usa OpenAI, Telegram, OCI ni PostgreSQL
productivo.

## CD controlado

`.github/workflows/deploy.yml` solo se activa con `workflow_dispatch`, exige un
SHA completo, ejecuta prechecks, empaqueta exactamente ese commit y usa el
environment `production`. Los secretos SSH y la URL del smoke quedan fuera de
Git.

El deploy remoto conserva `.env` y backups, rechaza cambios a migraciones ya
existentes, exige aprobación explícita para migraciones nuevas, conserva un
snapshot de rollback y valida Compose, contenedores, PostgreSQL, n8n, HTTPS,
disco y memoria. Los scripts normalizan LF y permisos antes de sincronizar el
release para que los bind mounts sean legibles por usuarios no root.

El cierre 9.7 conectó el repositorio privado `MACOABC/SmartDesk-AI`, ejecutó el
CI realmente en GitHub Actions, demostró un FAIL controlado en un PR temporal y
su recuperación a PASS, y desplegó el SHA exacto
`0dd4f3604fc85136ecd73ebb9052ace8a69cd486` mediante `workflow_dispatch`.
Los IDs y resultados verificables están en `docs/testing/GATE_9.md`.

## Backup y restore

Se respaldan `smartdesk_db`, `n8n_db` y `n8n_data`. Los dumps son custom-format,
se validan con `pg_restore --list`, el tar de n8n se lista, se registran conteos
por tabla y se calculan hashes SHA-256. El plaintext existe únicamente dentro
de un staging modo 700 durante la operación; el artefacto persistente en la VM
es CMS cifrado modo 600.

La VM conserva 14 días. La estación conserva 30 días en un directorio privado
fuera del repositorio y sincronizado off-host por OneDrive. La VM solo posee el
certificado público; la clave privada permanece en el almacén CurrentUser de
Windows. `scripts/ops/decrypt-backup.ps1` y
`scripts/ops/restore-drill.sh` cubren recuperación y ensayo.

El drill real creó un PostgreSQL 17 aislado, sin puertos ni red, restauró ambas
bases, comparó todos los conteos de tablas, comprobó cuatro vistas analytics y
constraints validadas, y eliminó contenedor y volumen temporales.

## Monitoring

`smartdesk-health.timer` ejecuta cada cinco minutos un check de contenedores,
healthchecks, PostgreSQL, n8n, borde HTTPS, disco y memoria. Un exit no cero
activa `smartdesk-health-alert@.service` y deja evidencia en journald.

Desde fuera de la VM, una tarea Windows comprueba HTTPS cada 30 minutos sin
crear tickets; otra tarea copia diariamente backups cifrados y verifica
SHA-256. `.github/workflows/monitor.yml` ofrece la misma comprobación externa
desde el repositorio GitHub conectado.

## Hardening final

- servicios no privilegiados con `no-new-privileges`;
- logs Docker rotados a 3 × 10 MiB por contenedor;
- imágenes explícitas, restart policies y healthchecks conservados;
- PostgreSQL y n8n únicamente en loopback; Docker API TCP ausente;
- UFW deny incoming, SSH key-only, root login deshabilitado;
- `.env` modo 600, backup dir 700, archivos backup 600;
- systemd oneshot bajo el usuario operativo, grupo Docker, filesystem
  protegido y `NoNewPrivileges=yes`;
- unattended security upgrades habilitado;
- workflows GitHub con permisos mínimos.

## Decisiones y trade-offs

Object Storage no se inventó: no había CLI ni credencial OCI disponible. La
copia cifrada a un directorio OneDrive privado satisface off-host hoy y puede
reemplazarse por Object Storage sin cambiar el formato de backup. Las tareas
externas dependen de que la estación Windows ejecute su scheduler; GitHub
Actions quedó conectado y validado para CI y deployment controlado.

No se añadieron Kubernetes, Terraform, Ansible, Prometheus, Grafana, Loki,
Vault ni servicios con coste. La VM única continúa siendo un punto único de
fallo, mitigado por backup off-host y restore probado, no por alta
disponibilidad.

## Fuera de alcance

Phase 10, cambios funcionales, WAF, rate limiting, alta disponibilidad,
replicación PostgreSQL, evaluación adicional del modelo, material comercial y
portafolio permanecen fuera de Phase 9.
