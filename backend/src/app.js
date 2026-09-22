const express = require('express');
const cors = require('cors');
const envelopeMiddleware = require('./middleware/envelope');
const errorHandlerMiddleware = require('./middleware/errorHandler');
const routes = require('./routes');
const { AppError } = require('./errors/catalog');
const config = require('./config');
const { initFirebase } = require('./config/firebase');

initFirebase();

const app = express();

// Middlewares base
app.use(cors({
  origin(origin, callback) {
    callback(null, Boolean(origin && (
      config.cors.allowedOrigins.includes(origin) ||
      config.cors.allowedOriginPattern?.test(origin)
    )));
  },
}));
app.use(express.json());

// Envelope estándar { data, error, meta }
app.use(envelopeMiddleware);

// Rutas de la API bajo /api/v1
app.use('/api/v1', routes);

// Captura de rutas no encontradas (404)
app.use((req, res, next) => {
  next(new AppError('NOT_FOUND', `La ruta ${req.method} ${req.originalUrl} no existe.`));
});

// Manejador centralizado de errores
app.use(errorHandlerMiddleware);

module.exports = app;
