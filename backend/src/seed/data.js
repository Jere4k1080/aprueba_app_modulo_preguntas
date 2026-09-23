/**
 * Datos de demostración del seed para la Entrega 1. Todo es inventado por el
 * equipo y no proviene del banco de la empresa: preguntas y habilidades llevan
 * isDemo: true. Los documentos nuevos usan IDs con el segmento `demo` para que
 * volver a correr el seed nunca pise un documento real (ADR-22). Se conservan
 * los IDs del ejemplo original, q_lectora_001 y sk_lectora_comp_lit.
 */

const DEMRE = 'https://demre.cl/';
const KHAN = 'https://es.khanacademy.org';

const demre = (prueba) => ({
  type: 'pdf',
  title: `Temario y modelos de prueba oficiales de ${prueba}`,
  url: DEMRE,
  source: 'DEMRE',
});
const khan = (path, title) => ({ type: 'video', title, url: KHAN + path, source: 'Khan Academy' });

const tests = [
  { id: 'lectora', label: 'Comp. Lectora', color: '#1A365D', hasQuestions: true },
  { id: 'm1', label: 'Matemática M1', color: '#10B981', hasQuestions: true },
  { id: 'm2', label: 'Matemática M2', color: '#6366F1', hasQuestions: true },
  { id: 'cien', label: 'Ciencias', color: '#F5B041', hasQuestions: true },
  { id: 'hist', label: 'Historia y C. Soc.', color: '#EF4444', hasQuestions: true },
];

const skill = (id, testId, domain, name, level, prerequisiteIds, resources) => ({
  id, name, testId, domain, level, maxLevel: 4, prerequisiteIds, status: 'active', resources, isDemo: true,
});

const skills = [
  skill('sk_demo_lectora_localizar', 'lectora', 'Localizar', 'Localizar información explícita', 1, [],
    [demre('Competencia Lectora')]),
  skill('sk_lectora_comp_lit', 'lectora', 'Comprensión lectora', 'Comprensión de textos literarios', 2,
    ['sk_demo_lectora_localizar'], [demre('Competencia Lectora')]),
  skill('sk_demo_lectora_interpretar', 'lectora', 'Interpretar', 'Inferir información implícita', 2,
    ['sk_demo_lectora_localizar'], [demre('Competencia Lectora')]),
  skill('sk_demo_lectora_evaluar', 'lectora', 'Evaluar', 'Evaluar el propósito de un texto', 3,
    ['sk_demo_lectora_interpretar'], [demre('Competencia Lectora')]),

  skill('sk_demo_m1_operatoria', 'm1', 'Números', 'Operatoria con números enteros', 1, [],
    [khan('/math/arithmetic', 'Aritmética'), demre('Matemática M1')]),
  skill('sk_demo_m1_pitagoras', 'm1', 'Geometría', 'Teorema de Pitágoras', 2, ['sk_demo_m1_operatoria'],
    [khan('/math/geometry', 'Geometría'), demre('Matemática M1')]),
  skill('sk_demo_m1_ecuaciones', 'm1', 'Álgebra y funciones', 'Ecuaciones de primer grado', 2, ['sk_demo_m1_operatoria'],
    [khan('/math/algebra', 'Álgebra 1'), demre('Matemática M1')]),
  skill('sk_demo_m1_probabilidad', 'm1', 'Probabilidad y estadística', 'Probabilidad con la regla de Laplace', 2,
    ['sk_demo_m1_operatoria'], [khan('/math/statistics-probability', 'Estadística y probabilidad'), demre('Matemática M1')]),

  skill('sk_demo_m2_logaritmos', 'm2', 'Números', 'Logaritmos', 2, ['sk_demo_m1_operatoria'],
    [khan('/math/algebra2', 'Álgebra 2'), demre('Matemática M2')]),
  skill('sk_demo_m2_cuadratica', 'm2', 'Álgebra y funciones', 'Ecuación de segundo grado', 3, ['sk_demo_m1_ecuaciones'],
    [khan('/math/algebra', 'Álgebra 1'), demre('Matemática M2')]),
  skill('sk_demo_m2_trigonometria', 'm2', 'Geometría', 'Razones trigonométricas en el triángulo rectángulo', 3,
    ['sk_demo_m1_pitagoras'], [khan('/math/trigonometry', 'Trigonometría'), demre('Matemática M2')]),
  skill('sk_demo_m2_prob_dependientes', 'm2', 'Probabilidad y estadística', 'Probabilidad de eventos dependientes', 3,
    ['sk_demo_m1_probabilidad'], [khan('/math/statistics-probability', 'Estadística y probabilidad'), demre('Matemática M2')]),

  skill('sk_demo_cien_celula', 'cien', 'Biología', 'Estructura y función de la célula', 1, [],
    [khan('/science/biology', 'Biología'), demre('Ciencias')]),
  skill('sk_demo_cien_rapidez', 'cien', 'Física', 'Rapidez media', 1, [],
    [khan('/science/physics', 'Física'), demre('Ciencias')]),
  skill('sk_demo_cien_mrua', 'cien', 'Física', 'Movimiento rectilíneo uniformemente acelerado', 2, ['sk_demo_cien_rapidez'],
    [khan('/science/physics', 'Física'), demre('Ciencias')]),
  skill('sk_demo_cien_masa_molar', 'cien', 'Química', 'Masa molar de compuestos', 2, [],
    [khan('/science/chemistry', 'Química'), demre('Ciencias')]),

  skill('sk_demo_hist_independencia', 'hist', 'Historia', 'Proceso de independencia de Chile', 1, [],
    [{ type: 'pdf', title: 'Fuentes digitalizadas de historia de Chile', url: 'https://www.memoriachilena.gob.cl/', source: 'Memoria Chilena' },
      demre('Historia y Ciencias Sociales')]),
  skill('sk_demo_hist_oferta_demanda', 'hist', 'Sistema económico', 'Oferta, demanda y precios', 1, [],
    [khan('/economics-finance-domain/microeconomics', 'Microeconomía'), demre('Historia y Ciencias Sociales')]),
  skill('sk_demo_hist_estado', 'hist', 'Formación ciudadana', 'Organización del Estado de Chile', 2, ['sk_demo_hist_independencia'],
    [{ type: 'pdf', title: 'Constitución Política de la República', url: 'https://www.bcn.cl/leychile/navegar?idNorma=242302', source: 'Biblioteca del Congreso Nacional' },
      demre('Historia y Ciencias Sociales')]),
  skill('sk_demo_hist_poblacion', 'hist', 'Geografía', 'Dinámica de la población', 2, [],
    [{ type: 'pdf', title: 'Estadísticas demográficas', url: 'https://www.ine.gob.cl/', source: 'INE' },
      demre('Historia y Ciencias Sociales')]),
];

// Umbrales de rapidez en ms (ADR-10), inventados para la demo y crecientes con la dificultad.
const UMBRALES = {
  d1: { p25: 10000, p50: 20000, p75: 35000, p90: 50000 },
  d2: { p25: 15000, p50: 30000, p75: 50000, p90: 70000 },
  d3: { p25: 25000, p50: 45000, p75: 70000, p90: 100000 },
  d4: { p25: 35000, p50: 60000, p75: 90000, p90: 130000 },
};
// En Competencia Lectora leer el texto suma tiempo.
const UMBRALES_LECTORA = {
  d1: { p25: 20000, p50: 35000, p75: 55000, p90: 80000 },
  d3: { p25: 30000, p50: 50000, p75: 75000, p90: 105000 },
  d4: { p25: 35000, p50: 60000, p75: 90000, p90: 120000 },
};

const question = (id, testId, axis, skillId, difficulty, statement, options, correctAnswer, explanation, cohortSpeedThresholds) => ({
  id, testId, axis, skillId, difficulty, statement, options, correctAnswer, explanation, cohortSpeedThresholds,
  status: 'active',
  isDemo: true,
});

const questions = [
  // Competencia Lectora
  question('q_demo_lectora_d1', 'lectora', 'Localizar', 'sk_demo_lectora_localizar', 'd1',
    'Lee el texto y responde.\n\n'
    + '> La biblioteca municipal amplió su horario desde marzo. De lunes a viernes abre de 9:00 a 20:00 y los '
    + 'sábados de 10:00 a 14:00. Los domingos permanece cerrada. Para pedir libros a domicilio basta presentar la '
    + 'cédula de identidad; no se cobra inscripción.\n\n'
    + 'Según el texto, ¿qué se necesita para pedir libros a domicilio?',
    ['Pagar una inscripción anual.', 'Ir a la biblioteca un día sábado.', 'Presentar la cédula de identidad.',
      'Tener una cuenta en el sitio web de la biblioteca.'],
    'C',
    '1. La pregunta pide un dato que el texto dice de forma explícita: el requisito para pedir libros a domicilio.\n'
    + '2. El texto dice: "Para pedir libros a domicilio basta presentar la cédula de identidad".\n'
    + '3. La alternativa A contradice el texto, que aclara que no se cobra inscripción. B y D no aparecen como requisitos.\n'
    + 'Verificación: C es la única alternativa que repite lo que el texto afirma.',
    UMBRALES_LECTORA.d1),
  question('q_lectora_001', 'lectora', 'Comprensión lectora', 'sk_lectora_comp_lit', 'd2',
    'Lee el fragmento y responde.\n\n'
    + '> Cuando llegó la fábrica de cemento, todo el pueblo salió a la plaza a celebrarla. Hubo trabajo para hombres '
    + 'y mujeres, y por primera vez las casas tuvieron luz eléctrica toda la noche. Veinte años después, don Anselmo '
    + 'llevó a su nieto al río donde él había aprendido a pescar. El agua bajaba gris y espesa, y en la orilla no '
    + 'quedaba ni un sauce. "Aquí antes se veía el fondo", le dijo al niño, pero el niño solo miraba el humo que '
    + 'cubría los cerros.\n\n'
    + '¿Cuál es la idea principal del fragmento?',
    ['La modernización de la industria', 'El impacto ambiental del progreso', 'La vida cotidiana en el campo',
      'Los avances tecnológicos del siglo XX'],
    'B',
    '1. El fragmento parte con la llegada de la fábrica y lo que trajo: trabajo y luz eléctrica.\n'
    + '2. Veinte años después muestra las consecuencias: el río contaminado, los sauces desaparecidos y el humo sobre los cerros.\n'
    + '3. Lo que une ambas partes es que ese progreso tuvo un costo para el ambiente.\n'
    + 'Verificación: A y D describen solo la primera parte del texto, y C es parte del escenario, no lo que el texto quiere mostrar.',
    { p25: 15000, p50: 25000, p75: 45000, p90: 60000 }),
  question('q_demo_lectora_d3', 'lectora', 'Interpretar', 'sk_demo_lectora_interpretar', 'd3',
    'Lee el texto y responde.\n\n'
    + '> Camila revisó por tercera vez el pronóstico en su teléfono. Guardó el paraguas en la mochila, se puso las '
    + 'botas de goma y, antes de salir, le pidió a su hermano que entrara la ropa que estaba colgada en el patio.\n\n'
    + '¿Qué se puede inferir del texto?',
    ['El pronóstico anunciaba un día soleado.', 'Camila llegará tarde a clases.',
      'El hermano de Camila olvidó su paraguas.', 'Camila espera que llueva.'],
    'D',
    '1. El texto no dice que va a llover: hay que deducirlo de lo que hace Camila.\n'
    + '2. Guarda el paraguas, se pone botas de goma y pide entrar la ropa colgada. Todas son precauciones ante la lluvia.\n'
    + '3. La alternativa A contradice esas precauciones, y B y C no tienen apoyo en el texto.\n'
    + 'Verificación: si el pronóstico anunciara sol, ninguna de esas acciones tendría sentido.',
    UMBRALES_LECTORA.d3),
  question('q_demo_lectora_d4', 'lectora', 'Evaluar', 'sk_demo_lectora_evaluar', 'd4',
    'Lee el texto y responde.\n\n'
    + '> Cada año se botan en Chile toneladas de alimentos que todavía se pueden comer. Mientras tanto, muchas '
    + 'familias no alcanzan a cubrir su canasta básica. Por eso los supermercados deberían estar obligados a donar '
    + 'los productos que no venden antes de su fecha de vencimiento, en lugar de desecharlos.\n\n'
    + '¿Cuál es el propósito principal del texto?',
    ['Convencer al lector de que los supermercados donen los alimentos que no venden.',
      'Informar sobre las fechas de vencimiento de los alimentos.',
      'Describir cómo funcionan los supermercados.',
      'Narrar la experiencia de una familia con pocos recursos.'],
    'A',
    '1. El texto presenta un problema: se botan alimentos que todavía se pueden comer.\n'
    + '2. Lo contrasta con las familias que no cubren su canasta básica.\n'
    + '3. Cierra con una propuesta introducida por "deberían", que busca que el lector la acepte.\n'
    + 'Verificación: un texto que plantea un problema y defiende una solución busca convencer, no informar, describir ni narrar.',
    UMBRALES_LECTORA.d4),

  // Matemática M1
  question('q_demo_m1_d1', 'm1', 'Números', 'sk_demo_m1_operatoria', 'd1',
    '¿Cuál es el valor de 3 + 4 · 2 − 6 ÷ 3?',
    ['5', '9', '12', '14'],
    'B',
    '1. Primero se resuelven la multiplicación y la división: 4 · 2 = 8 y 6 ÷ 3 = 2.\n'
    + '2. La expresión queda 3 + 8 − 2.\n'
    + '3. Luego se suma y se resta de izquierda a derecha: 3 + 8 = 11 y 11 − 2 = 9.\n'
    + 'Verificación: sumar antes de multiplicar da (3 + 4) · 2 − 2 = 12, que es el error de la alternativa C.',
    UMBRALES.d1),
  question('q_demo_m1_d2', 'm1', 'Geometría', 'sk_demo_m1_pitagoras', 'd2',
    'Un triángulo rectángulo tiene catetos de 6 cm y 8 cm. ¿Cuánto mide su hipotenusa?',
    ['10 cm', '14 cm', '2√7 cm', '48 cm'],
    'A',
    '1. En un triángulo rectángulo se cumple hipotenusa² = cateto² + cateto².\n'
    + '2. 6² + 8² = 36 + 64 = 100.\n'
    + '3. La hipotenusa mide √100 = 10 cm.\n'
    + 'Verificación: 10² = 100 = 36 + 64, y la hipotenusa resulta mayor que cada cateto, como debe ser.',
    UMBRALES.d2),
  question('q_demo_m1_d3', 'm1', 'Álgebra y funciones', 'sk_demo_m1_ecuaciones', 'd3',
    'Si 3x − 5 = 16, ¿cuál es el valor de x?',
    ['11/3', '21', '7', '63'],
    'C',
    '1. Se suma 5 a ambos lados: 3x = 16 + 5 = 21.\n'
    + '2. Se dividen ambos lados por 3: x = 21 ÷ 3 = 7.\n'
    + 'Verificación: 3 · 7 − 5 = 21 − 5 = 16.',
    UMBRALES.d3),
  question('q_demo_m1_d4', 'm1', 'Probabilidad y estadística', 'sk_demo_m1_probabilidad', 'd4',
    'Se lanzan dos dados comunes de seis caras. ¿Cuál es la probabilidad de que la suma de los puntos sea 7?',
    ['1/12', '1/11', '7/36', '1/6'],
    'D',
    '1. Cada dado tiene 6 resultados, así que hay 6 · 6 = 36 resultados posibles, todos igual de probables.\n'
    + '2. Los pares que suman 7 son (1, 6), (2, 5), (3, 4), (4, 3), (5, 2) y (6, 1): 6 casos favorables.\n'
    + '3. La probabilidad es 6/36 = 1/6.\n'
    + 'Verificación: contar solo 3 pares, sin distinguir qué dado da cada número, lleva a 3/36 = 1/12, el error de la alternativa A.',
    UMBRALES.d4),

  // Matemática M2
  question('q_demo_m2_d1', 'm2', 'Números', 'sk_demo_m2_logaritmos', 'd1',
    '¿Cuál es el valor de log₂ 32?',
    ['16', '4', '5', '64'],
    'C',
    '1. log₂ 32 es el exponente al que hay que elevar 2 para obtener 32.\n'
    + '2. 2¹ = 2, 2² = 4, 2³ = 8, 2⁴ = 16 y 2⁵ = 32.\n'
    + '3. Por lo tanto, log₂ 32 = 5.\n'
    + 'Verificación: 2⁵ = 32. La alternativa A (16) resulta de dividir 32 por 2, que no es lo que pide el logaritmo.',
    UMBRALES.d1),
  question('q_demo_m2_d2', 'm2', 'Álgebra y funciones', 'sk_demo_m2_cuadratica', 'd2',
    '¿Cuáles son las soluciones de la ecuación x² − 5x + 6 = 0?',
    ['x = 2 y x = 3', 'x = −2 y x = −3', 'x = 1 y x = 6', 'x = −1 y x = −6'],
    'A',
    '1. Se buscan dos números cuyo producto sea 6 y cuya suma sea 5: son 2 y 3.\n'
    + '2. La ecuación se factoriza como (x − 2)(x − 3) = 0.\n'
    + '3. Un producto vale cero cuando uno de sus factores vale cero: x = 2 o x = 3.\n'
    + 'Verificación: 2² − 5 · 2 + 6 = 4 − 10 + 6 = 0 y 3² − 5 · 3 + 6 = 9 − 15 + 6 = 0.',
    UMBRALES.d2),
  question('q_demo_m2_d3', 'm2', 'Geometría', 'sk_demo_m2_trigonometria', 'd3',
    'En un triángulo rectángulo, uno de los ángulos agudos mide 30° y la hipotenusa mide 10 cm. '
    + '¿Cuánto mide el cateto opuesto a ese ángulo?',
    ['5√3 cm', '20 cm', '10√3 cm', '5 cm'],
    'D',
    '1. El seno de un ángulo agudo es el cateto opuesto dividido por la hipotenusa: sen 30° = cateto opuesto / 10.\n'
    + '2. Como sen 30° = 1/2, el cateto opuesto mide 10 · 1/2 = 5 cm.\n'
    + 'Verificación: el otro cateto mide 10 · cos 30° = 5√3 cm, y 5² + (5√3)² = 25 + 75 = 100 = 10².',
    UMBRALES.d3),
  question('q_demo_m2_d4', 'm2', 'Probabilidad y estadística', 'sk_demo_m2_prob_dependientes', 'd4',
    'Una urna contiene 3 bolitas rojas y 2 azules. Se sacan dos bolitas al azar, una tras otra y sin devolver la '
    + 'primera. ¿Cuál es la probabilidad de que ambas sean rojas?',
    ['9/25', '3/10', '6/25', '3/5'],
    'B',
    '1. En la primera extracción hay 3 rojas entre 5 bolitas: la probabilidad es 3/5.\n'
    + '2. Sin devolver la primera, quedan 2 rojas entre 4 bolitas: la probabilidad es 2/4.\n'
    + '3. Se multiplican: 3/5 · 2/4 = 6/20 = 3/10.\n'
    + 'Verificación: hay 10 pares posibles de bolitas y 3 de ellos son de dos rojas, así que la probabilidad es 3/10. '
    + 'Si se devolviera la primera bolita se obtendría 3/5 · 3/5 = 9/25, el error de la alternativa A.',
    UMBRALES.d4),

  // Ciencias
  question('q_demo_cien_d1', 'cien', 'Biología', 'sk_demo_cien_celula', 'd1',
    '¿En qué organelo de las células vegetales ocurre la fotosíntesis?',
    ['Mitocondria', 'Cloroplasto', 'Ribosoma', 'Vacuola'],
    'B',
    '1. La fotosíntesis transforma energía luminosa en energía química y necesita clorofila.\n'
    + '2. La clorofila se encuentra en los cloroplastos, organelos de las células vegetales y de las algas.\n'
    + '3. La mitocondria realiza la respiración celular, el ribosoma sintetiza proteínas y la vacuola almacena agua y otras sustancias.\n'
    + 'Verificación: el único organelo de la lista que contiene clorofila es el cloroplasto.',
    UMBRALES.d1),
  question('q_demo_cien_d2', 'cien', 'Física', 'sk_demo_cien_rapidez', 'd2',
    'Un bus recorre 150 km en 2 horas. ¿Cuál es su rapidez media?',
    ['300 km/h', '152 km/h', '75 km/h', '37,5 km/h'],
    'C',
    '1. La rapidez media es la distancia recorrida dividida por el tiempo empleado.\n'
    + '2. v = 150 km ÷ 2 h = 75 km/h.\n'
    + 'Verificación: a 75 km/h, en 2 horas se recorren 75 · 2 = 150 km.',
    UMBRALES.d2),
  question('q_demo_cien_d3', 'cien', 'Química', 'sk_demo_cien_masa_molar', 'd3',
    'Considerando las masas atómicas C = 12 g/mol y O = 16 g/mol, ¿cuál es la masa molar del dióxido de carbono (CO₂)?',
    ['28 g/mol', '32 g/mol', '60 g/mol', '44 g/mol'],
    'D',
    '1. La fórmula CO₂ indica 1 átomo de carbono y 2 de oxígeno.\n'
    + '2. Masa molar = 1 · 12 + 2 · 16 = 12 + 32 = 44 g/mol.\n'
    + 'Verificación: 28 g/mol correspondería al CO, con un solo oxígeno, y 32 g/mol al O₂.',
    UMBRALES.d3),
  question('q_demo_cien_d4', 'cien', 'Física', 'sk_demo_cien_mrua', 'd4',
    'Un carro de 2 kg parte del reposo y acelera de manera uniforme a 3 m/s² durante 4 s. '
    + '¿Qué rapidez alcanza al final de ese tiempo?',
    ['12 m/s', '24 m/s', '6 m/s', '1,5 m/s'],
    'A',
    '1. En un movimiento uniformemente acelerado que parte del reposo, v = v₀ + a · t, con v₀ = 0.\n'
    + '2. v = 0 + 3 m/s² · 4 s = 12 m/s.\n'
    + '3. La masa del carro no interviene: haría falta para calcular la fuerza, no la rapidez.\n'
    + 'Verificación: la aceleración suma 3 m/s de rapidez cada segundo: 3, 6, 9 y 12 m/s al cabo de 4 s.',
    UMBRALES.d4),

  // Historia y Ciencias Sociales
  question('q_demo_hist_d1', 'hist', 'Historia', 'sk_demo_hist_independencia', 'd1',
    '¿En qué año se proclamó la independencia de Chile?',
    ['1810', '1818', '1833', '1879'],
    'B',
    '1. El 18 de septiembre de 1810 se formó la Primera Junta Nacional de Gobierno, que todavía gobernaba en nombre del rey Fernando VII.\n'
    + '2. La independencia se proclamó con el Acta de Independencia, que se juró el 12 de febrero de 1818.\n'
    + '3. 1833 es el año de la Constitución de 1833, y 1879, el del inicio de la Guerra del Pacífico.\n'
    + 'Verificación: lo que se celebra cada 18 de septiembre es la Junta de 1810, no la independencia; por eso 1810 es el error más frecuente.',
    UMBRALES.d1),
  question('q_demo_hist_d2', 'hist', 'Sistema económico', 'sk_demo_hist_oferta_demanda', 'd2',
    'Según la ley de la demanda, si el precio de un bien sube y los demás factores se mantienen constantes, '
    + '¿qué ocurre con la cantidad demandada de ese bien?',
    ['Disminuye.', 'Aumenta.', 'Se mantiene igual.', 'Se duplica.'],
    'A',
    '1. La ley de la demanda establece una relación inversa entre el precio de un bien y la cantidad que los consumidores quieren comprar.\n'
    + '2. Si el precio sube y nada más cambia, los consumidores compran menos de ese bien.\n'
    + 'Verificación: en un gráfico, la curva de demanda baja de izquierda a derecha: a mayor precio, menor cantidad demandada.',
    UMBRALES.d2),
  question('q_demo_hist_d3', 'hist', 'Formación ciudadana', 'sk_demo_hist_estado', 'd3',
    'Según la Constitución Política de la República de Chile, ¿qué órgano tiene como atribución exclusiva '
    + 'fiscalizar los actos del Gobierno?',
    ['El Senado', 'El Tribunal Constitucional', 'La Corte Suprema', 'La Cámara de Diputadas y Diputados'],
    'D',
    '1. El artículo 52 de la Constitución entrega a la Cámara de Diputadas y Diputados la atribución exclusiva de fiscalizar los actos del Gobierno.\n'
    + '2. Para eso puede adoptar acuerdos, citar a ministros y crear comisiones especiales investigadoras.\n'
    + '3. El artículo 53 prohíbe expresamente al Senado fiscalizar los actos del Gobierno.\n'
    + 'Verificación: el Tribunal Constitucional controla que las leyes se ajusten a la Constitución y la Corte Suprema encabeza el Poder Judicial; ninguno fiscaliza al Gobierno en el sentido del artículo 52.',
    UMBRALES.d3),
  question('q_demo_hist_d4', 'hist', 'Geografía', 'sk_demo_hist_poblacion', 'd4',
    'Un país de 10.000.000 de habitantes registró 150.000 nacimientos en un año. ¿Cuál fue su tasa bruta de natalidad?',
    ['1,5 por cada 1.000 habitantes', '0,015 por cada 1.000 habitantes', '15 por cada 1.000 habitantes',
      '150 por cada 1.000 habitantes'],
    'C',
    '1. La tasa bruta de natalidad es el número de nacimientos de un año por cada 1.000 habitantes.\n'
    + '2. Tasa = (150.000 ÷ 10.000.000) · 1.000.\n'
    + '3. 150.000 ÷ 10.000.000 = 0,015, y 0,015 · 1.000 = 15.\n'
    + 'Verificación: 15 nacimientos por cada 1.000 habitantes, en 10.000 grupos de 1.000, dan 15 · 10.000 = 150.000 nacimientos. '
    + 'Olvidar multiplicar por 1.000 deja 0,015, el error de la alternativa B.',
    UMBRALES.d4),
];

// Estado de práctica de los usuarios de demostración (ADR-09). El seed agrega
// lastAnsweredAt cuando hay preguntas respondidas.
const practiceStates = {
  usr_demo: { answeredQuestionIds: ['q_lectora_001'], lastQuestionId: 'q_lectora_001', activeSessionId: 'sess_demo_01' },
  // Estudiante nuevo para mostrar el flujo desde cero: sin preguntas respondidas.
  usr_demo_nuevo: { answeredQuestionIds: [] },
};

module.exports = { tests, skills, questions, practiceStates };
