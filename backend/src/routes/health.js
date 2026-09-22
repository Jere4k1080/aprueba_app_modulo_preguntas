const express = require('express');

const router = express.Router();

/**
 * GET /api/v1/health
 * Endpoint de verificación de salud del backend. Demuestra el funcionamiento
 * del envelope estándar { data, error, meta }.
 */
router.get('/health', (req, res) => {
  res.sendData({
    status: 'ok',
    service: 'aprueba-questions-backend',
    version: '1.0.0',
    uptimeSeconds: Math.floor(process.uptime()),
    environment: process.env.NODE_ENV || 'development',
  });
});

module.exports = router;
