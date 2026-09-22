const assert = require('assert');
const http = require('http');
const app = require('../src/app');
const { sanitizeQuestion, calculateCohortPercentile } = require('../src/services/questionService');
const { AppError, ErrorCatalog } = require('../src/errors/catalog');

async function runTests() {
  console.log('[Backend Tests] Iniciando pruebas de verificación...');

  // 1. Prueba de sanitizeQuestion
  const rawQuestion = {
    id: 'q_test_01',
    statement: '¿Cuál es la capital de Chile?',
    options: ['Santiago', 'Lima', 'Bogotá', 'Buenos Aires'],
    correctAnswer: 'A',
    explanation: 'Santiago fue fundada en 1541...',
  };

  const sanitized = sanitizeQuestion(rawQuestion);
  assert.strictEqual(sanitized.id, 'q_test_01');
  assert.strictEqual(sanitized.correctAnswer, undefined, 'ERROR: correctAnswer debe ser eliminado por sanitizeQuestion');
  assert.strictEqual(sanitized.explanation, undefined, 'ERROR: explanation debe ser eliminado por sanitizeQuestion');
  assert.strictEqual(rawQuestion.correctAnswer, 'A', 'ERROR: el objeto original no debe ser mutado');
  console.log('✓ Prueba 1: sanitizeQuestion elimina correctAnswer y explanation incondicionalmente.');

  // 2. Prueba de calculateCohortPercentile
  const thresholds = { p25: 15000, p50: 25000, p75: 45000, p90: 60000 };
  assert.strictEqual(calculateCohortPercentile(thresholds, 10000), 90);
  assert.strictEqual(calculateCohortPercentile(thresholds, 20000), 75);
  assert.strictEqual(calculateCohortPercentile(thresholds, 40000), 50);
  assert.strictEqual(calculateCohortPercentile(thresholds, 55000), 25);
  assert.strictEqual(calculateCohortPercentile(thresholds, 70000), 10);
  console.log('✓ Prueba 2: calculateCohortPercentile asigna percentiles O(1) correctamente.');

  // 3. Prueba de ErrorCatalog y AppError
  const err = new AppError('QUOTA_BASE_REACHED', 'Alcanzaste el límite');
  assert.strictEqual(err.statusCode, 422);
  assert.strictEqual(err.code, 'QUOTA_BASE_REACHED');
  assert.strictEqual(ErrorCatalog.QUOTA_DAILY_LIMIT.status, 422);
  assert.strictEqual(ErrorCatalog.NOT_FOUND.status, 404);
  console.log('✓ Prueba 3: Catálogo centralizado de errores configurado correctamente.');

  // 4. Prueba del endpoint HTTP /api/v1/health y envelope
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;

  const res = await fetch(`http://localhost:${port}/api/v1/health`);
  assert.strictEqual(res.status, 200);

  const json = await res.json();
  assert.strictEqual(json.error, null);
  assert.ok(json.meta, 'meta debe existir');
  assert.ok(json.meta.requestId.startsWith('req_'));
  assert.ok(json.meta.timestamp);
  assert.strictEqual(json.data.status, 'ok');
  assert.strictEqual(json.data.service, 'aprueba-questions-backend');
  console.log('✓ Prueba 4: Endpoint /api/v1/health responde envelope { data, error, meta } con requestId.');

  // 5. Prueba de ruta 404 y envelope de error
  const notFoundRes = await fetch(`http://localhost:${port}/api/v1/unknown-endpoint`);
  assert.strictEqual(notFoundRes.status, 404);
  const notFoundJson = await notFoundRes.json();
  assert.strictEqual(notFoundJson.data, null);
  assert.strictEqual(notFoundJson.error.code, 'NOT_FOUND');
  assert.ok(notFoundJson.meta.requestId);
  console.log('✓ Prueba 5: Ruta 404 produce envelope estándar con código NOT_FOUND.');

  server.close();
  console.log('[Backend Tests] ¡Todas las pruebas de infraestructura pasaron con éxito!\n');
}

runTests().catch((err) => {
  console.error('[Backend Tests Failed]', err);
  process.exit(1);
});
