# SmartDesk AI — Intake de tickets V1

## Objetivo

El intake recibe solicitudes internas de soporte, valida y normaliza su contrato de entrada, persiste únicamente tickets válidos y devuelve una respuesta HTTP controlada. Esta implementación corresponde a la Fase 2 y conserva el ticket antes de cualquier integración futura con IA.

```text
HTTP POST
  → n8n
  → validación y normalización
  → PostgreSQL
  → respuesta HTTP
```

## Endpoint

```text
POST /webhook/tickets
Content-Type: application/json
```

## Contrato de entrada

| Campo | Reglas |
| --- | --- |
| `requester_email` | Requerido, `string`, no vacío, máximo 254 caracteres y formato básico de email válido. |
| `requester_area` | Requerido, `string`; después de `trim`, entre 2 y 80 caracteres. |
| `title` | Requerido, `string`; después de `trim`, entre 5 y 150 caracteres. |
| `description` | Requerido, `string`; después de `trim`, entre 10 y 5000 caracteres. |

La validación acumula todos los errores aplicables. `requester_area`, `title` y `description` se persisten sin espacios externos. Los tipos incorrectos se rechazan sin ejecutar la inserción.

Ejemplo sintético:

```json
{
  "requester_email": "solicitante@example.com",
  "requester_area": "Finanzas",
  "title": "No puedo acceder al ERP",
  "description": "Desde esta mañana el sistema rechaza mis credenciales."
}
```

## Respuestas

### Ticket creado — HTTP 201

```json
{
  "success": true,
  "ticket": {
    "id": "7d3b8f4e-8f31-4b33-9f0d-2df62a4f173c",
    "status": "processing",
    "created_at": "2026-09-17T12:00:00.000Z",
    "updated_at": "2026-09-17T12:00:00.000Z"
  }
}
```

La respuesta no devuelve los datos originales del solicitante. PostgreSQL genera `id`, `status`, `created_at` y `updated_at` mediante sus valores por defecto.

### Payload inválido — HTTP 400

```json
{
  "success": false,
  "errors": [
    {
      "field": "title",
      "message": "title must contain between 5 and 150 characters"
    }
  ]
}
```

Un payload inválido no llega al nodo PostgreSQL y no crea ninguna fila.

### Fallo de persistencia — HTTP 500

```json
{
  "success": false,
  "error": {
    "code": "TICKET_PERSISTENCE_ERROR",
    "message": "Unable to create ticket"
  }
}
```

La respuesta es deliberadamente genérica: no incluye SQL, stack traces, host, base de datos, usuario, credenciales ni mensajes internos de n8n o PostgreSQL.

## Persistencia y seguridad

- La inserción utiliza parámetros `$1`, `$2`, `$3` y `$4`; no concatena contenido recibido en el SQL.
- La credencial PostgreSQL es administrada por n8n. El workflow versionado conserva únicamente la referencia técnica necesaria, no el secreto.
- PostgreSQL opera en la red interna de Docker y no publica su puerto al host.
- Los secretos y la configuración real permanecen fuera de Git.
- El artefacto versionado conserva `active: false`; su activación es una responsabilidad del despliegue.

## Fuera de alcance

La Fase 2 no incorpora IA, clasificación, categoría, prioridad, resumen ni notificaciones. Esas capacidades pertenecen a fases posteriores y no deben interpretarse como implementadas.
