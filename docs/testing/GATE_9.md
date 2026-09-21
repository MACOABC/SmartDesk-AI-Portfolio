# Gate 9 — Evidencia de operación

Fecha local: 2026-09-20. Ejecuciones VM: 2026-09-21 UTC.

## Conclusión

**Gate 9: PASS. Phase 9: COMPLETE.**

La aprobación se basa en ejecución real. No se asume un run alojado de GitHub:
el checkout no tiene remote configurado. Los workflows quedaron versionados y
el pipeline/deployer subyacente se ejecutó contra PostgreSQL temporal y la VM.

## Entornos y baseline

- fuente/control externo: Windows + PowerShell/OpenSSH;
- producción: Ubuntu 22.04 ARM64, Docker Compose 5.5.1;
- imágenes: PostgreSQL 17.11-bookworm, n8n 2.39.6, Caddy 2.11.4-alpine;
- baseline repo: `cab012b3a7af787733a783b1edba6cc95e35e376`;
- tag preservada: `v1.0 = fc42c911725aa589e3b36207d0be5b95b9f08063`;
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
| G9-07 | CI válido | PASS | `ci_pipeline=PASS`. |
| G9-08 | CI negativo controlado | PASS | JSON truncado temporal produjo `JSONDecodeError` y exit no cero. |
| G9-09 | CI recovery | PASS | artefacto roto retirado; `repository_validation=PASS`. |
| G9-10 | CD exact SHA | PASS | package/deploy verificaron SHA completo y `migration_count=0`. |
| G9-11 | Health/smoke post-deploy | PASS | tres containers healthy, PostgreSQL/n8n/HTTPS/resources PASS. |
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

## Evidencia CD y rollback

Deploy aprobado antes del cierre documental:

```text
deploy=PASS sha=f16823ff5829f732b7bb6a866c162f108209918f
migration_count=0
health_check=PASS
```

Se probó rollback real de un deploy Phase 9 a `e24f6b9...`: los tres servicios
volvieron healthy. Se redesplegó el release Phase 9 y se verificó health otra
vez. Los intentos fallidos previos fueron útiles: uno encontró CRLF en scripts
y otro permisos 700 en prompts. El rollback conservó la aplicación disponible;
las correcciones añadieron normalización LF y permisos explícitos.

El workflow alojado requiere remote GitHub y secrets externos; esta es la única
limitación externa del bloque GitHub. El deployment real no quedó bloqueado.

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
estación ejecute el scheduler; GitHub Actions alojado requiere conectar el
remote y configurar secrets. Ninguna impide la operación real probada y el
backup off-host existe.

Phase 10 no fue implementada.
