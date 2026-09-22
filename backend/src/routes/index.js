const express = require('express');
const healthRoutes = require('./health');

const router = express.Router();

// Rutas base de infraestructura
router.use('/', healthRoutes);

// Nota arquitectónica: Los 13 servicios funcionales del módulo de preguntas
// se implementan a partir de la Iteración 3 (HU-21 en adelante):
// - /practice/next, /questions/:id, /questions/:id/answer, etc.

module.exports = router;
