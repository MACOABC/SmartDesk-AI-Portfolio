# SmartDesk AI — Script hablado de la demo

Duración objetivo: **3:10**. Este guion corresponde al recorrido estático
seguro definido en `docs/DEMO.md`.

| Tiempo | Qué mostrar | Acción | Talking points exactos |
| --- | --- | --- | --- |
| 0:00–0:20 | README y arquitectura | Mantener visible el título y abrir el diagrama. | “SmartDesk AI automatiza el procesamiento inicial de solicitudes de soporte. Valida el ticket, lo clasifica con IA estructurada y conserva trazabilidad para automatización y análisis.” |
| 0:20–0:40 | `architecture-overview.png` | Recorrer visualmente de izquierda a derecha. | “La entrada llega por HTTPS a Caddy y n8n. El ticket se valida y se guarda antes de llamar a OpenAI. Después se valida el JSON, se aplican reglas y los datos quedan disponibles en PostgreSQL y Power BI.” |
| 0:40–1:15 | `demo/tickets.json`, caso `DEMO-LOW-001` | Mostrar solo el fixture; no abrir una URL. | “Este es el fixture principal: una solicitud sintética para cotizar un segundo monitor. Usa un correo example.com y no contiene información real. La etiqueta esperada es service request con prioridad low; esa etiqueta es ground truth, no una predicción garantizada.” |
| 1:15–1:40 | `ticket-ai-response.png` | Señalar los tres campos del resultado. | “Esta segunda evidencia pertenece al caso congelado SD-EVAL-TEST-083, no al fixture anterior. Muestra una salida real con category, priority y summary. El modelo usa Structured Outputs y el workflow vuelve a validar el resultado con JSON Schema.” |
| 1:40–2:05 | Secuencia de tres capturas n8n | Pasar una vez por intake, AI processing y outcome. | “El workflow valida, persiste primero, ejecuta hasta tres intentos acotados ante fallos transitorios y registra éxito o error. Luego aplica reglas deterministas y decide entre notificación, revisión humana o respuesta final.” |
| 2:05–2:25 | `powerbi-data-model.png` | Señalar `FactTickets` y sus tres relaciones. | “La capa analítica expone cuatro vistas con grains definidos. Power BI relaciona tickets con predicciones, revisiones y eventos de automatización mediante un rol read-only. Esta imagen muestra el modelo, no filas operacionales.” |
| 2:25–2:45 | Tabla Evaluación de IA del README | Señalar solo las dos métricas principales. | “La evaluación oficial usó 120 casos sintéticos etiquetados y congelados. Obtuvo 89.17 por ciento de accuracy de categoría y 76.67 por ciento de prioridad. No son métricas de producción.” |
| 2:45–3:05 | `github-actions-ci.png` | Señalar `Success` y `validate`. | “El candidato ejecuta CI alojado con 35 tests, migraciones y contratos SQL. El deployment, monitoring y backup fueron verificados en el repositorio operativo, que permanece privado y separado.” |
| 3:05–3:15 | Inicio del README | Dejar la pantalla quieta. | “SmartDesk AI integra automation, applied AI, SQL y BI, y cloud operations en un sistema desplegado y verificable.” |

## Reglas de entrega

- No improvisar métricas ni resultados.
- No afirmar que la captura `ticket-ai-response.png` corresponde a
  `DEMO-LOW-001`.
- No mostrar una URL, hostname, IP, credential, execution ID o response ID.
- Si se usa el request live opcional, sustituir solo el bloque 0:40–1:15 y
  mostrar el resultado real; no cambiar el resto del guion.
- Terminar antes de 4:00 aunque una pantalla tarde en cargar.
