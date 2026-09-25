# SmartDesk AI v1.1.0 — Portfolio Release

## Release status

**Prepared, not released.** No existe todavía el tag `v1.1.0` ni una GitHub
Release. Ambos requieren assets aprobados, revisión visual y autorización del
propietario.

## Highlights

- automatización desplegada de intake y triage de tickets;
- validación y persistencia PostgreSQL antes de invocar IA;
- clasificación estructurada mediante JSON Schema;
- reglas deterministas y notificación Telegram auditable;
- retries selectivos, HITL, decisión final y SLA;
- cuatro vistas analytics y template Power BI de tres páginas;
- CI determinista, CD manual por SHA y rollback;
- monitoring interno/externo y backup cifrado con restore drill;
- ingress HTTPS restringido mediante Caddy;
- documentación de portfolio, demo segura y métricas trazables.

## Verification

| Check | Verified result |
| --- | ---: |
| Intake E2E | 30/30 |
| Business rules | 19/19 |
| Offline CI tests | 35/35 |
| Synthetic benchmark | 120 labeled cases |
| Category accuracy | 89.17% |
| Priority accuracy | 76.67% |
| Exact match | 67.50% |
| Latency p50 / p95 | 1504.76 / 4310.11 ms |
| HITL reviewed / error escapes | 0/120 / 39/120 |
| Analytics / Power BI | 4 views / 3 pages |

Las fuentes y caveats están en `docs/PORTFOLIO_METRICS.md`. Ninguna cifra
representa ahorro, volumen o impacto empresarial.

## Known limitations

- El benchmark es sintético y no acredita calidad en producción.
- La señal `confidence` no está calibrada y no discriminó los errores con el
  threshold observado.
- La arquitectura utiliza una sola VM y no ofrece alta disponibilidad.
- OpenAI y Telegram son dependencias externas.
- No hay identidad corporativa, rate limiting ni WAF en el webhook.
- El repositorio de portfolio no contiene secrets y no puede desplegar ni
  monitorizar producción.
- Screenshots y video requieren captura y revisión manual.

## Security

- Secrets, credenciales y endpoints productivos permanecen externalizados.
- El historial del candidato fue sanitizado y contiene únicamente refs de
  portfolio aprobadas.
- El repositorio privado original sigue siendo la única autoridad de
  deployment.
- Los workflows operativos del candidato están bloqueados por identidad de
  repositorio y no tienen environments productivos.

## Version strategy

### v1.0

Hito histórico estable de la aplicación, preservado exactamente en
`fc42c911725aa589e3b36207d0be5b95b9f08063`.

### v1.1.0

Release de portfolio: licencia MIT, historia sanitizada, documentación,
evidencia, demo y assets revisados. No implica una ruptura funcional y por eso
no se utiliza `v2.0`.

