const assert = require('assert');
const http = require('http');
const path = require('path');
const { spawnSync } = require('child_process');

process.env.NODE_ENV = 'test';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.ALLOWED_ORIGINS = 'https://app.aprueba.test,http://localhost:3000';
process.env.ALLOWED_ORIGIN_PATTERN = '^https://aprueba-pr-[a-z0-9-]+\\.vercel\\.app$';

const app = require('../src/app');
assert.strictEqual(require('..'), app, 'La entrada del paquete debe exportar Express para Vercel');
const { sanitizeQuestion, calculateCohortPercentile } = require('../src/services/questionService');
const { AppError, ErrorCatalog } = require('../src/errors/catalog');
const seedDatabase = require('../src/seed/seed');

function runConfigProbe(script, overrides = {}) {
  return spawnSync(process.execPath, ['-e', script], {
    cwd: path.resolve(__dirname, '..'),
    env: {
      ...process.env,
      FIRESTORE_EMULATOR_HOST: '',
      FIREBASE_SERVICE_ACCOUNT_BASE64: '',
      FIREBASE_PROJECT_ID: '',
      JWT_SECRET: '',
      ...overrides,
    },
    encoding: 'utf8',
  });
}

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

  // 6. CORS: lista exacta, patrón de vistas previas y solicitud previa
  const allowed = await fetch(`http://localhost:${port}/api/v1/health`, {
    headers: { Origin: 'https://app.aprueba.test' },
  });
  assert.strictEqual(allowed.headers.get('access-control-allow-origin'), 'https://app.aprueba.test');
  const preview = await fetch(`http://localhost:${port}/api/v1/health`, {
    headers: { Origin: 'https://aprueba-pr-12.vercel.app' },
  });
  assert.strictEqual(preview.headers.get('access-control-allow-origin'), 'https://aprueba-pr-12.vercel.app');
  const denied = await fetch(`http://localhost:${port}/api/v1/health`, {
    headers: { Origin: 'https://app.aprueba.test.evil.example' },
  });
  assert.strictEqual(denied.headers.get('access-control-allow-origin'), null);
  const preflight = await fetch(`http://localhost:${port}/api/v1/health`, {
    method: 'OPTIONS',
    headers: {
      Origin: 'https://app.aprueba.test',
      'Access-Control-Request-Method': 'GET',
      'Access-Control-Request-Headers': 'Authorization',
    },
  });
  assert.strictEqual(preflight.status, 204);
  assert.strictEqual(preflight.headers.get('access-control-allow-origin'), 'https://app.aprueba.test');
  assert.strictEqual(preflight.headers.get('access-control-allow-credentials'), null);
  console.log('✓ Prueba 6: CORS permite orígenes conocidos y OPTIONS, sin credenciales.');

  // 7. Selección de credenciales con Firebase Admin simulado, sin tocar Firestore
  const firebaseProbe = `
    const Module = require('module');
    const originalLoad = Module._load;
    const admin = {
      apps: [],
      credential: { cert: (data) => ({ project_id: data.project_id }) },
      initializeApp(options) { this.apps.push(options); },
      firestore() { return {}; },
    };
    Module._load = function (name, ...args) {
      return name === 'firebase-admin' ? admin : originalLoad.call(this, name, ...args);
    };
    try {
      const { initFirebase } = require('./src/config/firebase');
      initFirebase();
      initFirebase();
      console.log(JSON.stringify(admin.apps));
    } catch (error) {
      console.error(error.message);
      process.exitCode = 2;
    }
  `;
  const emulator = runConfigProbe(firebaseProbe, {
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
    FIREBASE_SERVICE_ACCOUNT_BASE64: 'invalid',
  });
  assert.strictEqual(emulator.status, 0, emulator.stderr);
  assert.deepStrictEqual(JSON.parse(emulator.stdout.trim()), [{ projectId: 'aprueba-dev' }]);
  const serviceAccount = Buffer.from(JSON.stringify({ project_id: 'aprueba-test' })).toString('base64');
  const remote = runConfigProbe(firebaseProbe, { FIREBASE_SERVICE_ACCOUNT_BASE64: serviceAccount });
  assert.strictEqual(remote.status, 0, remote.stderr);
  assert.deepStrictEqual(JSON.parse(remote.stdout.trim()), [{
    credential: { project_id: 'aprueba-test' },
    projectId: 'aprueba-test',
  }]);
  const missing = runConfigProbe(firebaseProbe);
  assert.strictEqual(missing.status, 2);
  assert.match(missing.stderr, /Configura FIRESTORE_EMULATOR_HOST o FIREBASE_SERVICE_ACCOUNT_BASE64/);
  console.log('✓ Prueba 7: Firebase prioriza emulador, acepta cuenta de servicio e impide inicio sin credenciales.');

  // 8. El secreto JWT no puede caer al valor de desarrollo en producción
  const noJwt = runConfigProbe("require('./src/config')", { NODE_ENV: 'production' });
  assert.notStrictEqual(noJwt.status, 0);
  assert.match(noJwt.stderr, /JWT_SECRET es obligatorio en producción/);
  console.log('✓ Prueba 8: Producción falla sin JWT_SECRET.');

  // 9. Un seed remoto requiere permiso explícito antes de abrir Firestore
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
  const allowRemote = process.env.SEED_ALLOW_REMOTE;
  delete process.env.FIRESTORE_EMULATOR_HOST;
  delete process.env.SEED_ALLOW_REMOTE;
  try {
    await assert.rejects(seedDatabase(), /Seed remoto bloqueado/);
  } finally {
    process.env.FIRESTORE_EMULATOR_HOST = emulatorHost;
    if (allowRemote === undefined) delete process.env.SEED_ALLOW_REMOTE;
    else process.env.SEED_ALLOW_REMOTE = allowRemote;
  }
  console.log('✓ Prueba 9: Seed remoto exige SEED_ALLOW_REMOTE=true.');

  // 10. El banco de demostración del seed es consistente
  const seedData = require('../src/seed/data');
  const testIds = new Set(seedData.tests.map((t) => t.id));
  const skillById = new Map(seedData.skills.map((s) => [s.id, s]));
  const questionIds = new Set(seedData.questions.map((q) => q.id));
  assert.strictEqual(skillById.size, seedData.skills.length, 'Hay IDs de habilidades repetidos');
  assert.strictEqual(questionIds.size, seedData.questions.length, 'Hay IDs de preguntas repetidos');
  for (const s of seedData.skills) {
    assert.ok(s.isDemo && testIds.has(s.testId), `${s.id}: marca de demostración o prueba inválida`);
    for (const p of s.prerequisiteIds) assert.ok(skillById.has(p) && p !== s.id, `${s.id}: prerrequisito inválido ${p}`);
  }
  const celdas = new Set();
  for (const q of seedData.questions) {
    assert.ok(q.isDemo && testIds.has(q.testId) && ['d1', 'd2', 'd3', 'd4'].includes(q.difficulty), `${q.id}: marca, prueba o dificultad inválida`);
    assert.ok(q.options.length >= 4 && q.options.length <= 5, `${q.id}: debe tener 4 o 5 alternativas`);
    assert.strictEqual(new Set(q.options).size, q.options.length, `${q.id}: alternativas repetidas`);
    assert.ok('ABCDE'.slice(0, q.options.length).includes(q.correctAnswer), `${q.id}: correctAnswer fuera de las alternativas`);
    assert.strictEqual(skillById.get(q.skillId)?.testId, q.testId, `${q.id}: skillId inexistente o de otra prueba`);
    const { p25, p50, p75, p90 } = q.cohortSpeedThresholds;
    assert.ok(p25 < p50 && p50 < p75 && p75 < p90, `${q.id}: umbrales de rapidez no crecientes`);
    assert.ok(q.explanation, `${q.id}: falta la explicación`);
    celdas.add(`${q.testId}/${q.difficulty}`);
  }
  assert.strictEqual(celdas.size, 20, 'Faltan preguntas en alguna combinación de prueba y dificultad');
  for (const [uid, state] of Object.entries(seedData.practiceStates)) {
    assert.ok(state.answeredQuestionIds.every((id) => questionIds.has(id)), `${uid}: responde preguntas inexistentes`);
    assert.ok(state.answeredQuestionIds.length < questionIds.size, `${uid}: no le quedan preguntas por responder`);
  }
  assert.deepStrictEqual(seedData.practiceStates.usr_demo_nuevo.answeredQuestionIds, []);
  console.log('✓ Prueba 10: El banco de demostración cubre 5 pruebas y 4 dificultades con referencias válidas.');

  server.close();
  console.log('[Backend Tests] ¡Todas las pruebas de infraestructura pasaron con éxito!\n');
}

runTests().catch((err) => {
  console.error('[Backend Tests Failed]', err);
  process.exit(1);
});
