# Backend — Módulo de Preguntas Aprueba

Servicios REST en **Node.js + Express** sobre **Firestore (Firebase Admin SDK)** para el módulo de práctica de la app Aprueba.

## Arquitectura

- **Router base:** `/api/v1`
- **Envelope estándar:** Todas las respuestas respetan el formato:
  ```json
  {
    "data": { ... } | null,
    "error": { "code": "...", "message": "...", "details": null, "field": null } | null,
    "meta": { "requestId": "req_...", "timestamp": "2026-09-15T..." }
  }
  ```
- **Catálogo de errores:** Centralizado en `src/errors/catalog.js` (10 errores estándar HTTP + 9 errores de dominio).
- **Autenticación:** Middleware JWT `src/middleware/auth.js` validando `Authorization: Bearer <token>`.
- **Regla de integridad:** Función `sanitizeQuestion(doc)` en `src/services/questionService.js` que elimina incondicionalmente `correctAnswer` antes de enviar una pregunta al estudiante.

## Comandos

```bash
# Instalar dependencias
npm install

# Copiar variables de entorno
cp .env.example .env

# Iniciar emulador de Firestore (en otra terminal)
npm run emulator

# Cargar datos semilla
npm run seed

# Iniciar servidor en modo desarrollo
npm run dev

# Iniciar en modo producción
npm start
```

## Verificación de Salud

Endpoint de comprobación de salud disponible en:
```
GET http://localhost:4000/api/v1/health
```

Respuesta:
```json
{
  "data": {
    "status": "ok",
    "service": "aprueba-questions-backend",
    "version": "1.0.0",
    "uptimeSeconds": 12,
    "environment": "development"
  },
  "error": null,
  "meta": {
    "requestId": "req_84f2...",
    "timestamp": "2026-09-15T14:00:00.000Z"
  }
}
```
