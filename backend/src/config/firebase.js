const admin = require('firebase-admin');
const config = require('./index');

let initialized = false;

function initFirebase() {
  if (initialized || admin.apps.length > 0) {
    return admin.firestore();
  }

  const options = {
    projectId: config.firebase.projectId,
  };

  // Si existe emulador local de Firestore, lo prioriza
  if (config.firebase.emulatorHost) {
    process.env.FIRESTORE_EMULATOR_HOST = config.firebase.emulatorHost;
    console.log(`[Firebase] Conectando a Firestore Emulator en ${config.firebase.emulatorHost}`);
  }

  admin.initializeApp(options);
  initialized = true;
  return admin.firestore();
}

module.exports = {
  admin,
  initFirebase,
  getDb: () => initFirebase(),
};
