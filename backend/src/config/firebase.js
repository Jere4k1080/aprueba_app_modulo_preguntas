const admin = require('firebase-admin');
const config = require('./index');

function initFirebase() {
  if (admin.apps.length > 0) {
    return admin.firestore();
  }

  if (config.firebase.emulatorHost) {
    admin.initializeApp({ projectId: config.firebase.projectId || 'aprueba-dev' });
  } else if (config.firebase.serviceAccountBase64) {
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(Buffer.from(config.firebase.serviceAccountBase64, 'base64').toString('utf8'));
    } catch (_) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_BASE64 no contiene un JSON válido.');
    }
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: config.firebase.projectId || serviceAccount.project_id,
    });
  } else {
    throw new Error('Configura FIRESTORE_EMULATOR_HOST o FIREBASE_SERVICE_ACCOUNT_BASE64.');
  }

  return admin.firestore();
}

module.exports = {
  admin,
  initFirebase,
  getDb: () => initFirebase(),
};
