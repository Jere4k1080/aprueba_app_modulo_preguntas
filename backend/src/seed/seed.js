const { getDb } = require('../config/firebase');

/**
 * Script de carga de datos semilla (Seed) en Firestore.
 * Pobla las colecciones con los datos canónicos definidos en seed/README.md.
 */
async function seedDatabase() {
  console.log('[Seed] Iniciando siembra de datos en Firestore...');
  const db = getDb();

  // 1. Colección tests (5 pruebas PAES)
  const tests = [
    { id: 'lectora', label: 'Comp. Lectora', color: '#1A365D', hasQuestions: true },
    { id: 'm1', label: 'Matemática M1', color: '#10B981', hasQuestions: true },
    { id: 'm2', label: 'Matemática M2', color: '#6366F1', hasQuestions: true },
    { id: 'cien', label: 'Ciencias', color: '#F5B041', hasQuestions: true },
    { id: 'hist', label: 'Historia y C. Soc.', color: '#EF4444', hasQuestions: true },
  ];

  for (const t of tests) {
    await db.collection('tests').doc(t.id).set(t);
  }
  console.log(`[Seed] ${tests.length} pruebas PAES insertadas en /tests`);

  // 2. Colección skills
  const skills = [
    {
      id: 'sk_lectora_comp_lit',
      name: 'Comprensión de textos literarios',
      testId: 'lectora',
      domain: 'Comprensión lectora',
      level: 1,
      maxLevel: 4,
      prerequisiteIds: [],
      status: 'active',
      resources: [
        {
          type: 'video',
          title: 'Análisis de textos narrativos',
          url: 'https://youtube.com/watch?v=sample',
          duration: '12 min',
          source: 'YouTube',
        },
      ],
    },
  ];

  for (const s of skills) {
    await db.collection('skills').doc(s.id).set(s);
  }
  console.log(`[Seed] ${skills.length} habilidades insertadas en /skills`);

  // 3. Colección questions (con correctAnswer y cohortSpeedThresholds)
  const questions = [
    {
      id: 'q_lectora_001',
      testId: 'lectora',
      axis: 'Comprensión lectora',
      skillId: 'sk_lectora_comp_lit',
      difficulty: 'd2',
      statement: '¿Cuál es la idea principal del fragmento presentado?',
      options: [
        'La modernización de la industria',
        'El impacto ambiental del progreso',
        'La vida cotidiana en el campo',
        'Los avances tecnológicos del siglo XX',
      ],
      correctAnswer: 'B',
      explanation: 'El fragmento describe las consecuencias ambientales del desarrollo fabril.',
      cohortSpeedThresholds: {
        p25: 15000,
        p50: 25000,
        p75: 45000,
        p90: 60000,
      },
      status: 'active',
    },
  ];

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
      answeredAt: new Date().toISOString(),
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
      createdAt: new Date().toISOString(),
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
      createdAt: new Date().toISOString(),
    });
  console.log('[Seed] 1 movimiento de medalla insertado en users/usr_demo/medalLedger');

  // 7. Documento de estado users/{uid}/state/practice
  await db
    .collection('users')
    .doc('usr_demo')
    .collection('state')
    .doc('practice')
    .set({
      answeredQuestionIds: ['q_lectora_001'],
      lastQuestionId: 'q_lectora_001',
      lastAnsweredAt: new Date().toISOString(),
      activeSessionId: 'sess_demo_01',
    });
  console.log('[Seed] Estado de práctica insertado en users/usr_demo/state/practice');

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
