# SmartDesk AI — Guion de demo segura

## Objetivo y fixtures

Duración objetivo: **3 minutos**; rango aceptable: 2–4 minutos.

- **DEMO_PRIMARY:** `DEMO-LOW-001`. Solicitud planificada, ideal para mostrar
  el flujo completo con automation `skipped` y sin Telegram.
- **DEMO_ALERT:** `DEMO-HIGH-001`. Opcional y solo en un entorno demo aislado
  con destino Telegram de prueba. No usarlo si pudiera notificar producción.

Ambos payloads viven en `demo/tickets.json`, usan `example.com` y son
sintéticos. La etiqueta esperada debe validarse durante el ensayo; nunca se
presenta como resultado garantizado del modelo.

## Preparación del entorno

1. Usar una base demo separada de producción y cargar únicamente fixtures
   sintéticos.
2. Configurar hostname, webhook y credenciales de demo fuera de Git.
3. Importar los workflows y mapear credenciales sin grabar esas pantallas.
4. Ensayar `DEMO_PRIMARY` y guardar una ejecución limpia para el plan B.
5. Poblar Power BI desde la base demo, nunca desde las filas operacionales de
   reconciliación de Gate 8.
6. Abrir previamente arquitectura, payload, respuesta, vista de persistencia,
   Power BI y el run CI candidato.

## Checklist inmediatamente antes de grabar

- [ ] Browser tabs sanitized.
- [ ] Notifications disabled.
- [ ] `.env` closed.
- [ ] Terminal history safe.
- [ ] SSH aliases hidden.
- [ ] Public IP hidden.
- [ ] Production URL hidden.
- [ ] n8n credentials hidden.
- [ ] Telegram chat IDs hidden.
- [ ] OpenAI data and provider response IDs hidden.
- [ ] Database passwords and connection details hidden.
- [ ] Only synthetic tickets visible.
- [ ] Power BI connected only to safe demo data.
- [ ] GitHub candidate repository used where appropriate.
- [ ] Microphone, crop and 16:9 recording area verified.

## Guion ejecutable

### 0:00–0:20 — Problema

**Pantalla:** título del README o slide limpia.

**Narración sugerida:** “SmartDesk AI automatiza el procesamiento inicial de
tickets internos. Valida la entrada, conserva el ticket, obtiene una
clasificación estructurada y deja trazabilidad para reglas y análisis; no
pretende reemplazar una plataforma ITSM completa.”

### 0:20–0:45 — Arquitectura

**Pantalla:** Mermaid renderizado de `docs/ARCHITECTURE.md`.

**Acción:** recorrer de izquierda a derecha: request → Caddy/HTTPS → n8n →
validación → PostgreSQL/OpenAI → reglas → HITL/SLA → analytics/Power BI.

**Mensaje clave:** la persistencia ocurre antes de la llamada IA y la salida
JSON se valida antes de aplicar reglas.

### 0:45–1:20 — Ticket sintético

**Pantalla:** request de `DEMO-LOW-001` y cliente HTTP saneado.

**Acción:** enviar exactamente un ticket al entorno demo. Mostrar HTTP result
y respuesta sin revelar URL ni headers. Si la API externa introduce
variabilidad, usar la ejecución ensayada.

**Mensaje clave:** email `example.com`, contenido sintético y contrato de
entrada explícito.

### 1:20–1:45 — IA estructurada

**Pantalla:** JSON real de la ejecución.

**Acción:** señalar `category`, `priority` y `summary`.

**Mensaje clave:** Structured Outputs + JSON Schema; la respuesta se valida de
forma determinista y no se confía en texto libre.

### 1:45–2:05 — Persistencia y automatización

**Pantalla:** consulta saneada que relaciona ticket, prediction, decision/SLA y
automation event.

**Acción:** con `DEMO_PRIMARY`, mostrar `skipped` por prioridad baja. Usar
`DEMO_ALERT` únicamente si el ensayo aislado y el destino de prueba están
confirmados.

**Mensaje clave:** el evento queda auditado incluso cuando no se envía una
notificación.

### 2:05–2:30 — Reliability, HITL y SLA

**Pantalla:** entidades o vista preparada con datos demo.

**Acción:** mostrar brevemente review, decisión final y deadline.

**Mensaje clave:** predicción y decisión operacional están separadas. La señal
`confidence` no está calibrada y el benchmark no demostró mejora por HITL.

### 2:30–2:50 — Power BI

**Pantalla:** página Overview y, si el tiempo permite, AI Quality.

**Acción:** señalar filtros, KPIs y grains; indicar que los datos son
sintéticos.

**Mensaje clave:** cuatro vistas PostgreSQL alimentan un modelo Power BI de
tres páginas; los conteos no representan impacto empresarial.

### 2:50–3:10 — Calidad de ingeniería

**Pantalla:** GitHub Actions del candidato.

**Acción:** mostrar CI PASS, 35 tests y PostgreSQL temporal.

**Cierre sugerido:** “El proyecto combina automatización, IA estructurada,
persistencia, BI y operación verificable, con secretos y producción separados
del repositorio de portfolio.”

## Plan B seguro

- OpenAI inestable: usar la ejecución demo ensayada y explicar el manejo de
  fallo persistido.
- Telegram no disponible: mantener `DEMO_PRIMARY`; no generar una alerta
  real para mejorar la grabación.
- Power BI sin refresh: usar capturas previamente aprobadas sobre la misma base
  demo.
- Etiqueta diferente: mostrar el resultado real y explicar la separación entre
  expected label, prediction y decisión.
- Fallo durante la grabación: detener, sanear el estado y repetir; no editar
  una respuesta ficticia.

## Revisión posterior

- [ ] Duración entre 2 y 4 minutos.
- [ ] Flujo comprensible sin contexto adicional.
- [ ] Solo datos sintéticos.
- [ ] Cero endpoints, IPs, secrets o identificadores productivos visibles.
- [ ] Métricas coherentes con `PORTFOLIO_METRICS.md`.
- [ ] Limitación HITL y naturaleza sintética expresadas con claridad.
- [ ] Revisión cuadro por cuadro completada antes de enlazar el video.
