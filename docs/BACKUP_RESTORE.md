# Backup y restore de SmartDesk AI

## Clasificación del estado

### A. Debe respaldarse

- `smartdesk_db`: tickets, predicciones, decisiones, reviews, SLA, eventos y
  analytics derivados del estado transaccional;
- `n8n_db`: workflows publicados, credenciales cifradas, ejecuciones y estado
  de n8n;
- volumen `n8n_data`: configuración/estado local complementario de n8n;
- clave de cifrado n8n y demás secretos de `.env`, mediante custodia separada
  y no dentro del backup de datos.

### B. Reconstruible desde Git o proveedores

- Compose, Caddy, migraciones, prompts, schemas, exports n8n, scripts, docs y
  template Power BI;
- imágenes Docker explícitas;
- certificados TLS de Caddy, renovables mediante ACME. Los volúmenes Caddy no
  son parte del backup crítico.

### C. No debe aparecer en un backup no protegido

- `.env`, private keys, tokens, passwords y claves SSH;
- dumps de PostgreSQL, porque pueden contener PII y credenciales n8n cifradas;
- export de credenciales n8n en texto plano.

## Crear un backup

En producción el timer llama al script con el certificado público configurado:

```bash
sudo systemctl start smartdesk-backup.service
systemctl show smartdesk-backup.service -p Result -p ExecMainStatus
```

Ejecución manual con drill completo:

```bash
SMARTDESK_PROJECT_DIR="$HOME/smartdesk-ai" \
SMARTDESK_BACKUP_RECIPIENT_CERT=/etc/smartdesk-backup/recipient.pem \
SMARTDESK_RESTORE_DRILL=1 \
scripts/ops/backup-smartdesk.sh
```

El resultado esperado es `smartdesk-<UTC>.tar.gz.cms` modo 600 más sidecar
SHA-256. Retención VM: 14 días. El timer diario es persistent y conserva logs
en journald.

## Copia off-host

Desde Windows, sin escribir host ni rutas privadas en Git:

```powershell
scripts/ops/pull-offhost-backups.ps1 `
  -SshTarget '<ssh-alias>' `
  -DestinationDirectory '<private-synced-directory>' `
  -RetentionDays 30
```

La transferencia descarga únicamente `.cms`, compara SHA-256 remoto/local y
publica el archivo final solo después de verificarlo. La tarea programada
`SmartDesk Off-host Backup Sync` ejecuta esta operación diariamente.

## Descifrar para recuperación

La clave privada no está en Git ni en la VM. Está en el certificate store del
usuario Windows que creó el recipient. Descifrar únicamente a una ruta temporal
protegida:

```powershell
scripts/ops/decrypt-backup.ps1 `
  -EncryptedBackup '<backup>.tar.gz.cms' `
  -OutputPath "$env:TEMP\smartdesk-restore.tar.gz"
```

El script verifica que el contenido descifrado sea gzip y restringe el ACL al
usuario actual. El plaintext debe eliminarse después del restore.

## Restore drill aislado

En un host Docker de recuperación:

```bash
scripts/ops/restore-drill.sh /path/to/smartdesk-restore.tar.gz
```

El script:

1. valida `SHA256SUMS`;
2. crea volumen y contenedor PostgreSQL 17 sin puertos y con `--network none`;
3. restaura `smartdesk_db` y `n8n_db` con `--no-owner --no-privileges`;
4. compara conteos por tabla con el origen;
5. valida cuatro vistas analytics y constraints;
6. elimina contenedor, volumen y staging al terminar.

Nunca ejecutar este drill sobre producción.

## Recuperación de desastre

1. levantar host limpio y checkout del SHA deseado;
2. crear `.env` por el canal seguro y modo 600;
3. descifrar y transferir temporalmente el archive;
4. validar con `restore-drill.sh` antes de tocar el destino;
5. restaurar las bases en volúmenes nuevos, no sobre el único volumen
   existente;
6. restaurar `n8n_data`, levantar Compose y ejecutar health/regresión;
7. verificar workflows/credenciales cifradas con la misma
   `N8N_ENCRYPTION_KEY`;
8. eliminar todo plaintext temporal y registrar el SHA desplegado.
