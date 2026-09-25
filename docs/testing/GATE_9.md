# Gate 9 — Evidencia de operación

Fecha inicial local: 2026-09-20. Ejecuciones VM: 2026-09-21 UTC.
Cierre alojado 9.7: 2026-09-24 local / 2026-09-25 UTC.

## Conclusión

**Gate 9: PASS. Phase 9: COMPLETE.**

La aprobación combina la evidencia operativa real previa con la activación
alojada de GitHub verificada en 9.7. El repositorio privado
`MACOABC/SmartDesk-AI` quedó conectado como `origin`; CI demostró la secuencia
PASS → FAIL controlado → PASS y CD desplegó por `workflow_dispatch` un SHA
completo con healthcheck y smoke externo PASS.

## Entornos y baseline

- fuente/control externo: Windows + PowerShell/OpenSSH;
- producción: Ubuntu 22.04 ARM64, Docker Compose 5.5.1;
- imágenes: PostgreSQL 17.11-bookworm, n8n 2.39.6, Caddy 2.11.4-alpine;
- baseline repo: `cab012b3a7af787733a783b1edba6cc95e35e376`;
- tag preservada: `v1.0 = fc42c911725aa589e3b36207d0be5b95b9f08063`;
- HEAD funcional publicado y desplegado en 9.7:
  `0dd4f3604fc85136ecd73ebb9052ace8a69cd486`;
- deployment funcional final previo al cierre documental:
  `f16823ff5829f732b7bb6a866c162f108209918f`.

Baseline remoto: tres contenedores healthy; UFW deny incoming; SSH key-only;
PostgreSQL/n8n loopback; sin CI/CD, timers SmartDesk ni off-host configurado;
sin OCI CLI/credencial Object Storage. Un dump histórico 664 fue endurecido a
600 antes de generar nuevos backups.

## Matriz

| ID | Caso | Resultado | Evidencia real |
| --- | --- | --- | --- |
| G9-01 | Repo/infra baseline read-only | PASS | HEAD/tag/remotes, Compose, mounts, listeners, firewall, SSH, systemd, permisos y storage inspeccionados. |
| G9-02 | Validación repo | PASS | JSON/YAML/n8n/migraciones/imágenes/artefactos/secret patterns. |
| G9-03 | Tests offline | PASS | 35/35 `unittest`; cero red del scorer. |
| G9-04 | PostgreSQL CI temporal | PASS | Container/volume únicos, sin puertos, eliminados por trap. |
| G9-05 | Bootstrap migraciones | PASS | `001→005` desde volumen vacío. |
| G9-06 | Contratos DB | PASS | `phase6_contract_tests=PASS`; analytics Gate 8 completo; migración 005 reaplicada. |
| G9-07 | CI válido | PASS | GitHub Actions run `36079703644` sobre `0dd4f36...`: job `validate` y pipeline completo PASS. |
| G9-08 | CI negativo controlado | PASS | PR temporal #1, SHA `da544f0...`, run `36079465259`: JSON truncado detectado con `JSONDecodeError`; PR no merged. |
| G9-09 | CI recovery | PASS | Mismo PR, SHA `b11498c...`, run `36079518418` PASS; PR cerrado y rama eliminada. |
| G9-10 | CD exact SHA | PASS | `workflow_dispatch` run `36080435344` desplegó `0dd4f36...`; `migration_count=0`. |
| G9-11 | Health/smoke post-deploy | PASS | Run alojado y verificación independiente: tres containers healthy, PostgreSQL/n8n/HTTPS/resources y smoke 404 PASS. |
| G9-12 | Rollback real | PASS | rollback a `e24f6b9...`, healthy; redeploy posterior healthy. |
| G9-13 | Fallos CD detectados | PASS | workspace faltante, CRLF y permisos de prompts fueron detectados, corregidos y reprobados; ningún dato perdido. |
| G9-14 | Backup real | PASS | SmartDesk DB + n8n DB + n8n_data, hashes/list validation. |
| G9-15 | Restore aislado real | PASS | PostgreSQL sin red/puertos; ambos dumps restaurados; conteos, vistas y constraints PASS; cleanup automático. |
| G9-16 | Cifrado | PASS | CMS AES-256; VM solo certificado público; archivo 600. |
| G9-17 | Off-host privado | PASS | archivo cifrado copiado fuera de VM a OneDrive privado; SHA-256 y descifrado verificados. |
| G9-18 | Backup automatizado | PASS | `smartdesk-backup.timer` enabled/active; service manual result success/0. |
| G9-19 | Monitor interno healthy | PASS | service y script PASS. |
| G9-20 | Monitor interno failure | PASS | `SMARTDESK_MONITOR_FORCE_FAIL=1` produjo exit no cero. |
| G9-21 | Alerta/recovery | PASS | OnFailure/journald observado; service volvió a PASS; timer enabled/active. |
| G9-22 | Monitor externo | PASS | workstation recibió 404; puerto inválido detectado; recovery 404. |
| G9-23 | Persistencia externa | PASS | dos Scheduled Tasks ejecutadas con `LastTaskResult=0`. |
| G9-24 | Firewall/SSH | PASS | UFW active deny incoming; root/password/kbd login no; pubkey yes. |
| G9-25 | Exposición | PASS | públicos 22/80/443; 5432/5678 solo 127.0.0.1; 2375/2376 ausentes. |
| G9-26 | Contenedores | PASS | privileged false; no-new-privileges; health/restart/log rotation configurados. |
| G9-27 | Permisos | PASS | `.env` 600; backup dir 700; todos sus archivos 600; authorized_keys 600. |
| G9-28 | Secret scan | PASS | working tree/historial fuerte: 0 hallazgos; `.env` no trackeado. |
| G9-29 | Regresión Gate 0–8 | PASS | HTTPS, inválido 400, válido 201, prediction, decisión/SLA, contratos Phase 6, analytics/Power BI schema. |
| G9-30 | Limpieza | PASS | dos tickets sintéticos eliminados; restore containers/volumes eliminados; servicios healthy. |

## Evidencia CI detallada

Run equivalente real sobre VM, aislado de producción:

```text
repository_validation=PASS
Ran 35 tests ... OK
phase6_contract_tests=PASS
database_schema_validation=PASS
database_integration=PASS
ci_pipeline=PASS
```

Negativo/recovery:

```text
FAIL invalid_json file=smartdesk-controlled-invalid.json error=JSONDecodeError
repository_validation=FAIL failures=1
controlled_negative=PASS
repository_validation=PASS
ci_recovery=PASS
```

OpenAI real, Telegram productivo y DB productiva usados por CI: **0 / 0 / 0**.

## Evidencia GitHub alojada 9.7

- repositorio: `https://github.com/MACOABC/SmartDesk-AI` (privado);
- branch publicada: `main`; `origin/main` y HEAD funcional coincidieron en
  `0dd4f3604fc85136ecd73ebb9052ace8a69cd486` antes del commit documental;
- CI PASS inicial: workflow `CI`, run `36079397135`, SHA
  `e54398e500501555556b1e451252699c15404fbe`, evento `push`, conclusión
  `success`;
- CI negativo: branch `test/gate9-ci-negative`, PR #1, SHA
  `da544f02e9dddccc215d95891c09a8fa6580bc73`, run `36079465259`, conclusión
  `failure` esperada en `Run deterministic CI` por
  `n8n/workflows/gate9-ci-negative.json` inválido;
- recovery del PR: SHA `b11498ccd179a1d7e89b58eb6668fe20e4e418be`,
  run `36079518418`, conclusión `success`; PR cerrado sin merge y branch
  temporal eliminada local/remotamente;
- CI final funcional de `main`: run `36079703644`, SHA
  `0dd4f3604fc85136ecd73ebb9052ace8a69cd486`, conclusión `success`;
- un re-run manual `36079597156` detectó una carrera real del healthcheck
  PostgreSQL durante el servidor temporal de inicialización. Se corrigió el
  readiness CI para usar TCP y el run final anterior confirmó la corrección;
- la tag local `v1.0` permaneció en
  `fc42c911725aa589e3b36207d0be5b95b9f08063`; no se recreó ni movió y no se
  publicó automáticamente al remote.

Secrets configurados únicamente en el environment `production`:
`SMARTDESK_DEPLOY_SSH_KEY`, `SMARTDESK_DEPLOY_KNOWN_HOSTS`,
`SMARTDESK_DEPLOY_HOST`, `SMARTDESK_DEPLOY_USER` y
`SMARTDESK_MONITOR_URL`. La ruta no sensible se configuró como variable
`SMARTDESK_DEPLOY_PATH`. Ningún valor fue impreso ni versionado.

## Evidencia CD y rollback

Deploy aprobado antes del cierre documental:

```text
deploy=PASS sha=f16823ff5829f732b7bb6a866c162f108209918f
migration_count=0
health_check=PASS
```

Deploy alojado 9.7:

```text
workflow=Controlled production deployment
event=workflow_dispatch
run_id=36080435344
requested_sha=0dd4f3604fc85136ecd73ebb9052ace8a69cd486
deployed_sha=0dd4f3604fc85136ecd73ebb9052ace8a69cd486
database_integration=PASS
ci_pipeline=PASS
migration_count=0
health_check=PASS
deployment_external_smoke=PASS status=404
```

Dos intentos anteriores (`36079945740` y `36080025743`) fallaron antes de
modificar producción porque la primera clave dedicada se había creado con una
passphrase no interactiva incorrecta. La clave fue reemplazada por otra
dedicada, sin passphrase, restringida y verificada; la entrada autorizada
obsoleta se retiró. El run final pasó todos los steps.

Se probó rollback real de un deploy Phase 9 a `e24f6b9...`: los tres servicios
volvieron healthy. Se redesplegó el release Phase 9 y se verificó health otra
vez. Los intentos fallidos previos fueron útiles: uno encontró CRLF en scripts
y otro permisos 700 en prompts. El rollback conservó la aplicación disponible;
las correcciones añadieron normalización LF y permisos explícitos.

El workflow alojado quedó activado con remote, environment, secrets mínimos y
variable de ruta externos a Git. El deployment real no quedó bloqueado.

## Evidencia backup/restore

Drill backup: `smartdesk-20260921T024952Z.tar.gz.cms`.

```text
restore_environment=isolated_no_published_ports
restore_row_counts=PASS
restore_constraints=PASS
restore_drill=PASS
backup_encryption=PASS
backup_validation=PASS
offhost_backup_sync=PASS copied=1
offhost_decryption=PASS
```

Un segundo run por systemd obtuvo `Result=success`, `ExecMainStatus=0` y archivo
modo 600. Retención: VM 14 días, off-host 30 días.

## Evidencia monitoring

```text
monitor_healthy=PASS
health_check=FAIL reason=forced_test_failure
monitor_failure_detection=PASS
monitor_alert=PASS
monitor_recovery=PASS
external_monitor=PASS status=404
external_monitor_failure_detection=PASS
external_monitor_recovery=PASS
```

No se detuvo producción y el monitor no hizo POST, no creó tickets y no llamó
OpenAI/Telegram.

## Regresión y coste externo

- payload inválido: HTTP 400, sin IA;
- primer ticket válido: HTTP 201 pero `AI_CONTRACT_LOAD_ERROR`, intentos 0;
  detectó el permiso incorrecto del release y originó la corrección;
- segundo ticket válido tras redeploy: HTTP 201, prediction succeeded, 1
  intento, contrato v2, decisión y SLA únicos, review 0, analytics 1:1;
- prioridad final low y evento Telegram `skipped`;
- contratos Phase 6 y reconciliación analytics/Power BI PASS;
- ambos tickets sintéticos fueron eliminados y el conteo remanente fue 0.

Llamadas OpenAI reales durante Phase 9: **1**. Envíos Telegram reales: **0**.
No se estima coste porque esta ejecución productiva no dejó evidencia de precio
facturado suficiente para calcularlo.

## Seguridad, límites y cierre

No se versionaron secretos, dumps, URLs privadas, IPs ni claves. La clave
privada de backup está fuera del repositorio y fuera de la VM.

Limitaciones conservadas: VM única; tareas externas Windows requieren que la
estación ejecute el scheduler. Ninguna impide la operación real probada y el
backup off-host existe. En el cierre 9.7 hubo **0** llamadas OpenAI y **0**
envíos Telegram adicionales.

Phase 10 no fue implementada.
