const app = require('./app');
const config = require('./config');

const server = app.listen(config.port, () => {
  console.log(`[Aprueba Backend] Servidor iniciado en puerto ${config.port} (${config.env})`);
  console.log(`[Aprueba Backend] API disponible en http://localhost:${config.port}/api/v1/health`);
});

module.exports = server;
