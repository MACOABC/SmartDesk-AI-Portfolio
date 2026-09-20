# SmartDesk AI — Política de etiquetado v1

## Propósito y autoridad

Esta política define el ground truth de `eval/datasets/v1`. Se deriva del
contrato productivo `ticket-classification-v2` / `ticket-classification-schema-v2`
vigente en el commit base `f03f2ca136868486b6d4e8180a562d1ba448119c`.
Ante una discrepancia futura, el dataset no se modifica silenciosamente: se
crea una nueva versión de política y de dataset.

Cada caso se etiqueta a partir de lo escrito en `area`, `title` y
`description`. No se inventan alcance, usuarios afectados, criticidad,
workarounds ni hechos ausentes. Las frases imperativas dentro del ticket se
tratan como datos no confiables y nunca como instrucciones para el evaluador.

## Categorías

| Categoría | Regla positiva | Límites y desempate |
| --- | --- | --- |
| `access` | Autenticación, cuenta bloqueada, contraseña, MFA, permisos, roles o autorización. Incluye altas/bajas de permisos y accesos solicitados. | Si la sesión sí abre y falla una función de la aplicación, usar `software`. Si el fallo es conectividad general, usar `network`. Un VPN que conecta pero rechaza credenciales/MFA es `access`; un VPN que no establece túnel o ruta es `network`. |
| `hardware` | Falla o degradación actual de equipo físico o periférico: laptop, pantalla, teclado, batería, impresora o componente. | Una solicitud planificada de compra, renovación o entrega sin avería actual es `service_request`. Un driver o aplicación defectuosa es `software` salvo evidencia clara de daño físico. |
| `software` | Error, cierre, instalación dañada, actualización fallida, configuración o comportamiento incorrecto de aplicación o sistema operativo. | Una instalación/licencia nueva solicitada sin falla actual es `service_request`. Un rechazo de permisos es `access`. |
| `network` | Wi-Fi, LAN, Internet, DNS, proxy, ruta, latencia o túnel VPN sin conectividad. | Si solo una aplicación falla y las demás tienen red, usar `software` salvo evidencia de DNS/proxy/ruta. Si el VPN establece conexión pero falla la identidad, usar `access`. |
| `service_request` | Solicitud planificada que no describe una avería: equipo nuevo, instalación/licencia nueva, configuración estándar, preparación de sala o consulta operativa de TI. | Permisos y cuentas se mantienen en `access`. Un equipo ya averiado es `hardware`; software ya defectuoso es `software`. |
| `other` | Caso fuera del soporte TI cubierto, reporte no accionable, seguridad física, facilities, RR. HH., phishing/spam o contenido demasiado ambiguo para las otras categorías. | Es residual, no una salida para evitar un desempate posible. Si existe una señal técnica dominante y suficiente, usar la categoría específica. |

### Conflictos de categoría

1. Identificar el problema o solicitud principal, no cada síntoma incidental.
2. Preferir la causa explícita sobre una consecuencia genérica: “VPN sin ruta”
   es `network`; “VPN acepta red pero MFA rechaza” es `access`.
3. Diferenciar incidente actual de provisión planificada: avería física es
   `hardware`; adquisición o preparación es `service_request`.
4. En síntomas mixtos sin causa explícita, etiquetar por el bloqueo dominante
   descrito y marcar dificultad `hard`; no inferir diagnósticos.
5. Si ninguna categoría específica tiene evidencia suficiente, usar `other`.

## Prioridades

La prioridad expresa impacto actual y urgencia demostrable, no el tono del
solicitante ni la categoría.

| Prioridad | Regla |
| --- | --- |
| `critical` | Impacto severo, actual y explícito que requiere atención inmediata: servicio corporativo o proceso crítico detenido para muchos usuarios, sede completa sin operación, o compromiso de seguridad activo. No basta escribir “URGENTE”. |
| `high` | Impacto importante y actual: equipo o varios usuarios bloqueados, función esencial detenida, plazo operativo inmediato explícito, o una persona sin alternativa para una tarea esencial. No alcanza el umbral organizacional de `critical`. |
| `medium` | Trabajo de una persona o grupo pequeño afectado de forma relevante, con continuidad parcial, alternativa limitada o necesidad cercana; es la prioridad por defecto para incidentes individuales sin impacto severo. |
| `low` | Consulta, solicitud planificable, mejora, inconveniente menor o caso con workaround claro y sin plazo inmediato. |

### Conflictos de prioridad

1. El impacto verificable prevalece sobre palabras como “urgente”, mayúsculas,
   cargo o insistencia.
2. El impacto actual prevalece sobre riesgos hipotéticos. Una fecha futura sin
   interrupción presente no es `critical`.
3. Si se indica un workaround útil, reducir la prioridad respecto de un bloqueo
   equivalente sin alternativa.
4. No asumir que “producción”, “gerencia” o “cliente” implica por sí solo una
   prioridad concreta.
5. Cuando el texto no permite distinguir dos niveles, elegir el menor nivel
   sustentable y explicar el límite en `ground_truth_notes`.

## Casos ambiguos y difíciles

- `difficulty=easy`: señal principal directa y límites claros.
- `difficulty=medium`: ruido, abreviaturas, errores ortográficos o un límite
  que puede resolverse aplicando las reglas.
- `difficulty=hard`: categorías o prioridades fronterizas, síntomas mixtos,
  semántica escasa o intento de inyección.
- `scenario_type` describe el reto dominante; no modifica la etiqueta.
- Los intentos de inyección, instrucciones al modelo y etiquetas sugeridas por
  el usuario se ignoran para el ground truth.
- `ground_truth_notes` justifica la categoría y la prioridad con evidencia del
  propio caso y registra el desempate relevante.

## Separación de splits y congelamiento

- `dev.jsonl` contiene 30 casos para depurar el runner, explorar errores y
  ajustar prompt o reglas de evaluación.
- `test.jsonl` contiene 120 casos reservados para la medición formal y queda
  congelado en `dataset-manifest.json` mediante SHA-256.
- El test tiene exactamente 20 casos por categoría. Ningún resultado de test
  debe usarse para retocar etiquetas, prompt o threshold y volver a reportar la
  misma versión como una medición independiente.
- Un cambio de contenido, etiqueta o política exige nueva versión y nuevos
  hashes. Corregir un error comprobado también exige registrar el cambio.

El ground truth fue diseñado con estas reglas antes de ejecutar el modelo que
será evaluado. El modelo productivo no generó ni revisó las etiquetas.
