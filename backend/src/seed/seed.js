const { getDb, admin } = require('../config/firebase');
const { tests, skills, questions, practiceStates } = require('./data');

/**
 * Script de carga de datos semilla (Seed) en Firestore.
 * Pobla las colecciones con los datos de demostración de ./data.js, descritos en seed/README.md.
 * Las fechas usan la hora del servidor de Firestore, no el reloj local (ADR-14).
 */
async function seedDatabase() {
  if (!process.env.FIRESTORE_EMULATOR_HOST && process.env.SEED_ALLOW_REMOTE !== 'true') {
    throw new Error('Seed remoto bloqueado. Define SEED_ALLOW_REMOTE=true para permitirlo.');
  }
  console.log('[Seed] Iniciando siembra de datos en Firestore...');
  const db = getDb();
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();

  // 1. Colección tests (5 pruebas PAES)
  for (const t of tests) {
    await db.collection('tests').doc(t.id).set(t);
  }
  console.log(`[Seed] ${tests.length} pruebas PAES insertadas en /tests`);

  // 2. Colección skills
  for (const s of skills) {
    await db.collection('skills').doc(s.id).set(s);
  }
  console.log(`[Seed] ${skills.length} habilidades insertadas en /skills`);

  // 3. Colección questions (con correctAnswer y cohortSpeedThresholds)
  for (const q of questions) {
    await db.collection('questions').doc(q.id).set(q);
  }
  console.log(`[Seed] ${questions.length} preguntas insertadas en /questions`);

  // 4. Colección answers (colección raíz con userId)
  const answers = [
    {
      id: 'ans_001',
      userId: 'usr_demo',
      questionId: 'q_lectora_001',
      selected: 'B',
      correct: true,
      elapsedMs: 24000,
      cohortPercentile: 78,
      answeredAt: serverTimestamp(),
    },
  ];

  for (const a of answers) {
    await db.collection('answers').doc(a.id).set(a);
  }
  console.log(`[Seed] ${answers.length} respuestas insertadas en /answers`);

  // 5. Colección corrections (colección raíz con userId)
  const corrections = [
    {
      id: 'cor_001',
      userId: 'usr_demo',
      questionId: 'q_lectora_001',
      reason: 'wrong_answer',
      comment: 'La alternativa correcta debería ser C.',
      status: 'pending',
      potentialReward: { amount: 250 },
      createdAt: serverTimestamp(),
      reviewedAt: null,
      reviewedBy: null,
    },
  ];

  for (const c of corrections) {
    await db.collection('corrections').doc(c.id).set(c);
  }
  console.log(`[Seed] ${corrections.length} recorrecciones insertadas en /corrections`);

  // 6. Subcolección users/{uid}/medalLedger
  await db
    .collection('users')
    .doc('usr_demo')
    .collection('medalLedger')
    .doc('ml_001')
    .set({
      id: 'ml_001',
      type: 'answer_correct',
      tier: 'bronze',
      amount: 1,
      referenceId: 'q_lectora_001',
      createdAt: serverTimestamp(),
    });
  console.log('[Seed] 1 movimiento de medalla insertado en users/usr_demo/medalLedger');

  // 7. Documento de estado users/{uid}/state/practice (ADR-09)
  for (const [uid, state] of Object.entries(practiceStates)) {
    const doc = state.answeredQuestionIds.length > 0 ? { ...state, lastAnsweredAt: serverTimestamp() } : state;
    await db.collection('users').doc(uid).collection('state').doc('practice').set(doc);
  }
  console.log(`[Seed] Estado de práctica insertado para ${Object.keys(practiceStates).join(' y ')}`);

  console.log('[Seed] ¡Siembra de datos finalizada con éxito!');
}

if (require.main === module) {
  seedDatabase()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('[Seed Error]', err);
      process.exit(1);
    });
}

module.exports = seedDatabase;
