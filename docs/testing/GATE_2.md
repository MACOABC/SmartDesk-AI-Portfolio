# Evidencia controlada — Gate 2

## Identificación

- **Fecha de ejecución:** 2026-09-17.
- **Commit probado:** `73913e279892bf7b4be3a94b120cedaedcdc7063` (`feat: finalize ticket intake http contract`).
- **Entorno:** despliegue existente de SmartDesk AI con n8n y PostgreSQL.
- **Resultado:** **Gate 2 PASS**.

Esta evidencia corresponde a una batería controlada de aceptación de Gate 2. No representa tráfico, disponibilidad, rendimiento ni métricas de producción.

## Cobertura y resultados

Se ejecutaron 30 solicitudes HTTP end-to-end sobre `POST /webhook/tickets`.

| Categoría | Casos | Resultado |
| --- | ---: | --- |
| Happy path | 1 | HTTP 201, una fila y campos generados por PostgreSQL. PASS. |
| Normalización | 1 | Espacios externos eliminados y valores normalizados persistidos. PASS. |
| Validaciones individuales | 8 | HTTP 400, errores comprensibles y cero inserciones. PASS. |
| Errores múltiples | 1 | Los cuatro campos inválidos fueron informados; cero inserciones. PASS. |
| Límites mínimos y máximos | 14 | Bordes válidos aceptados y valores fuera de rango rechazados. PASS. |
| Caracteres especiales | 1 | Contenido benigno persistido literalmente mediante SQL parametrizado. PASS. |
| Fallo de PostgreSQL | 1 | HTTP 500 controlado, sin detalles internos y sin inserción. PASS. |
| Recuperación posterior | 1 | La solicitud siguiente respondió HTTP 201 sin intervención manual. PASS. |
| Reinicio de n8n | 1 | Servicio healthy, workflow y credencial persistentes, HTTP 201. PASS. |
| Reinicio de PostgreSQL | 1 | Reconexión automática, tabla intacta y HTTP 201. PASS. |
| **Total** | **30** | **30/30 resultados esperados cumplidos.** |

Los códigos observados coincidieron con el contrato:

- ticket válido y persistido: HTTP 201;
- entrada inválida: HTTP 400;
- fallo de persistencia: HTTP 500 con `TICKET_PERSISTENCE_ERROR`.

## Base de datos e integridad

- Conteo de tickets al inicio: `0`.
- Conteo de tickets al finalizar la limpieza: `0`.
- Se eliminaron únicamente las filas sintéticas creadas por la batería.
- La tabla `public.tickets` permaneció disponible con ocho columnas, primary key, cuatro defaults, ocho restricciones `NOT NULL` y seis restricciones `CHECK`.
- La huella normalizada del esquema coincidió antes y después de las pruebas.

## Seguridad comprobada

- El `INSERT` usa los parámetros `$1`, `$2`, `$3` y `$4`.
- La credencial PostgreSQL continúa administrada por n8n y no está embebida en el workflow.
- PostgreSQL no publica ningún puerto al host.
- n8n conserva únicamente el binding administrativo previamente aprobado sobre loopback.
- Las respuestas HTTP 400 y 500 no exponen SQL, stack traces, credenciales ni detalles internos.
- El artefacto versionado no contiene secretos y conserva `active: false`.

## Conclusión

La entrada válida se valida, normaliza y persiste antes de responder; las entradas inválidas no alcanzan PostgreSQL; los fallos de persistencia producen una respuesta controlada; y la configuración se conserva tras reinicios. **Gate 2: PASS.**
