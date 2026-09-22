const dotenv = require('dotenv');

dotenv.config();

module.exports = {
  port: parseInt(process.env.PORT || '4000', 10),
  env: process.env.NODE_ENV || 'development',
  jwt: {
    secret: process.env.JWT_SECRET || 'dev_jwt_secret_change_in_production_min_32_chars',
    expiresIn: process.env.JWT_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.REFRESH_TOKEN_EXPIRES_IN || '30d',
  },
  quota: {
    // Configurable, no quemado en el código (Decisión ADR-11)
    resetHourLocal: parseInt(process.env.QUOTA_RESET_HOUR_LOCAL || '0', 10),
    resetTimezone: process.env.QUOTA_RESET_TIMEZONE || 'America/Santiago',
    baseQuota: 10,
    schoolBonus: 5,
    addressBonus: 5,
  },
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID || 'aprueba-dev',
    emulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
  },
};
