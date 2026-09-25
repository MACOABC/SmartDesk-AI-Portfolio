# SmartDesk AI — Contrato de demo segura

## Objetivo

Demostrar en 2–4 minutos un flujo real y auditable sin exponer producción ni
convertir resultados experimentales en impacto empresarial. La demo debe usar
únicamente datos sintéticos en un entorno local o de demo aislado.

## Preparación obligatoria

1. Usar una base separada de producción y cargar solo fixtures sintéticos.
2. Confirmar que el hostname, webhook y credenciales visibles son placeholders.
3. Mapear credenciales de demo en n8n sin abrir sus pantallas durante la toma.
4. Ejecutar previamente el caso elegido y limpiar IDs o logs innecesarios.
5. Poblar Power BI desde la base demo, nunca desde las 13 filas operacionales
   usadas para reconciliación de Gate 8.
6. Preferir una grabación validada si una API externa introduce latencia o
   variación que perjudique una demostración en vivo.

## Storyboard de 2–4 minutos

### 0:00–0:20 — Problema

Explicar que el triage manual de tickets produce entradas inconsistentes y poca
trazabilidad. SmartDesk AI valida, estructura y enruta el ticket; no pretende
ser una plataforma ITSM completa ni resolver automáticamente la incidencia.

### 0:20–0:45 — Ticket sintético

Mostrar un payload de `demo/tickets.json`, preferentemente `DEMO-HIGH-001`.
Debe ser visible la marca de dato sintético y el dominio `example.com`.

### 0:45–1:15 — Intake y clasificación

Enviar el payload a `<SMARTDESK_WEBHOOK_URL>`. Mostrar HTTP 201, el
`ticket_id` recién generado y la salida estructurada `category`, `priority` y
`summary`. No mostrar el endpoint real ni IDs de ejecuciones anteriores.

### 1:15–1:45 — Persistencia y regla

Mostrar una consulta saneada que relacione ticket, predicción, decisión y
evento de automatización. Si la predicción es HIGH o CRITICAL, mostrar que la
regla crea el evento de notificación. La etiqueta esperada del fixture debe
validarse en el ensayo; no se presenta como resultado garantizado del modelo.

### 1:45–2:15 — Reliability, HITL y SLA

Enseñar brevemente las entidades de review, decisión y SLA o una ejecución
controlada ya preparada. Explicar que la señal `confidence` no está calibrada:
en el benchmark oficial no derivó errores a revisión, por lo que no se afirma
que el HITL haya mejorado accuracy.

### 2:15–2:50 — Analytics y Power BI

Mostrar las cuatro vistas y las tres páginas Power BI alimentadas únicamente
con datos sintéticos de demo. Explicar grains, filtros y reconciliación SQL/DAX;
no presentar conteos de demo como resultados empresariales.

### 2:50–3:20 — Calidad de ingeniería

Cerrar con evidencia breve: CI 35/35, prueba negativa que falla como se espera,
recovery PASS y deployment manual por SHA. No abrir secrets, logs crudos ni la
configuración SSH.

## Plan B seguro

- Si OpenAI no responde: usar la grabación validada y explicar el manejo de
  fallo persistido, sin reintentar de forma indefinida.
- Si Telegram no está disponible: mostrar el evento `failed` o una captura
  saneada de una ejecución previa de demo.
- Si Power BI no refresca: usar capturas obtenidas desde la base demo y
  conservar las consultas de reconciliación como evidencia.
- Si la etiqueta del modelo difiere de la esperada: no ocultarla; explicar la
  separación entre predicción, revisión y decisión final.

## Información prohibida en pantalla

- hostname, webhook, IP pública o alias SSH reales;
- `.env`, API keys, tokens, passwords o chat IDs;
- páginas de credenciales n8n y configuración de GitHub secrets;
- rutas personales o configuración local del propietario;
- response IDs del proveedor y logs productivos sin sanitizar;
- tickets, emails o datos de producción;
- el dashboard conectado a la base operacional.

## Criterios de aceptación de la futura grabación

- duración entre 2 y 4 minutos;
- flujo comprensible sin narración adicional;
- datos exclusivamente sintéticos;
- cero secretos o endpoints operativos visibles;
- cada métrica coincide con `PORTFOLIO_METRICS.md`;
- limitación HITL y naturaleza sintética del benchmark expresadas con claridad.

