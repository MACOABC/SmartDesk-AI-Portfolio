# SmartDesk AI — Arquitectura

## Flujo funcional

```mermaid
flowchart LR
    U[Cliente / formulario] -->|POST HTTPS| C[Caddy]
    C -->|Ruta pública permitida| W[n8n: Ticket Intake]
    W --> V[Validación y normalización]
    V -->|Ticket processing| P[(PostgreSQL)]
    V --> O[OpenAI Responses API]
    O --> J[Validación JSON Schema]
    J -->|Predicción y trazabilidad| P
    J --> R[Reglas deterministas]
    R --> T[Telegram]
    R -->|Review o decisión| P
    A[n8n: Admin HITL] -->|Loopback + token| P
    S[n8n: SLA Scheduler] -->|Deadline y breach| P
    S --> T
    P --> Q[4 vistas analytics]
    Q -->|Rol read-only + túnel SSH| B[Power BI]
```

La solicitud se persiste antes de llamar a la IA. Una salida inválida no pasa
a las reglas. Predicción, revisión humana, decisión final, SLA y eventos se
conservan como entidades separadas para mantener auditabilidad.

## Límites de red

```mermaid
flowchart TB
    Internet -->|80 / 443| Caddy
    Caddy -->|app network| n8n
    n8n -->|internal database network| PostgreSQL
    LocalAdmin[Administrador por túnel SSH] -->|127.0.0.1:5678| n8n
    PowerBI[Power BI por túnel SSH] -->|127.0.0.1:5432| PostgreSQL
```

- Caddy solo reenvía `POST /webhook/tickets`.
- Los endpoints HITL y resolución permanecen en loopback y exigen token.
- PostgreSQL y la administración n8n no están expuestos a Internet.
- Secrets y credenciales viven fuera de Git.

## Entrega y operación

```mermaid
flowchart LR
    GitHub[GitHub main] --> CI[CI: validación + 35 tests + PostgreSQL temporal]
    GitHub -->|workflow_dispatch + SHA| CD[CD controlado]
    CD --> VM[Oracle Cloud ARM64 VM]
    VM --> Health[systemd health monitor]
    VM --> Backup[backup cifrado diario]
    Backup --> Offhost[copia privada off-host]
    Hosted[GitHub external monitor] -->|GET seguro; espera 404| VM
```

El CD es manual por SHA completo y no se ejecuta por push. El environment
`production` centraliza secrets, pero actualmente no tiene required reviewers.
Los backups se restauraron en un entorno aislado durante Gate 9.

## Componentes versionados

| Capa | Artefactos principales |
| --- | --- |
| Infraestructura | `compose.yaml`, `Caddyfile`, `ops/systemd/` |
| Orquestación | `n8n/workflows/` |
| Datos | `db/migrations/001`–`005`, `db/tests/` |
| IA | `prompts/ticket-classification/`, `eval/` |
| Analytics | `sql/analytics/`, `powerbi/SmartDeskAI.pbit` |
| Delivery | `.github/workflows/`, `scripts/ci/`, `scripts/deploy/` |
| Operación | `scripts/ops/`, `docs/OPERATIONS.md`, `docs/BACKUP_RESTORE.md` |

