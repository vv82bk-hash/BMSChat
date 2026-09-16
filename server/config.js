// =====================================================
// 🎯 BMSChat — КОНФИГУРАЦИЯ СЕРВЕРА
// =====================================================
// Читает переменные из .env, проверяет обязательные,
// экспортирует всё в удобном виде.
//
// PostgreSQL:
//   • DATABASE_URL — строка подключения (обязательна)
// =====================================================

require('dotenv').config();

// =====================================================
// ⚠️ ПРОВЕРКА ОБЯЗАТЕЛЬНЫХ ПЕРЕМЕННЫХ
// =====================================================
const requiredEnvVars = [
    'JWT_SECRET',
    'PASSWORD_PEPPER',
    'DATABASE_URL',       // ← обязательно для PostgreSQL
];

const missingVars = requiredEnvVars.filter(
    (varName) => !process.env[varName]
);

if (missingVars.length > 0) {
    console.error('');
    console.error('❌ КРИТИЧЕСКАЯ ОШИБКА КОНФИГУРАЦИИ');
    console.error('═══════════════════════════════════════');
    console.error('Отсутствуют обязательные переменные в .env:');
    missingVars.forEach((v) => console.error(`   • ${v}`));
    console.error('');
    console.error('💡 Что делать:');
    console.error('   1. Откройте server/.env');
    console.error('   2. Добавьте отсутствующие переменные');
    console.error('   3. Перезапустите сервер');
    console.error('═══════════════════════════════════════');
    process.exit(1);
}

// =====================================================
// ⚠️ ПРЕДУПРЕЖДЕНИЯ О СТАНДАРТНЫХ ЗНАЧЕНИЯХ
// =====================================================
const DEFAULT_JWT_SECRET = 'boba_marley_rasta_secret_2024_change_me_in_production';
const DEFAULT_PEPPER = 'boba_marley_pepper_change_me_in_production_2024_rasta_love';

if (process.env.JWT_SECRET === DEFAULT_JWT_SECRET) {
    console.warn('');
    console.warn('⚠️  ВНИМАНИЕ: Используется стандартный JWT_SECRET!');
    console.warn('⚠️  В продакшене ОБЯЗАТЕЛЬНО замените его в .env');
    console.warn('');
}

if (process.env.PASSWORD_PEPPER === DEFAULT_PEPPER) {
    console.warn('');
    console.warn('⚠️  ВНИМАНИЕ: Используется стандартный PASSWORD_PEPPER!');
    console.warn('⚠️  В продакшене ОБЯЗАТЕЛЬНО замените его в .env');
    console.warn('');
}

// =====================================================
// 📦 ЭКСПОРТ КОНФИГУРАЦИИ
// =====================================================
module.exports = {
    // -----------------------------------------------------
    // 🌐 СЕРВЕР
    // -----------------------------------------------------
    PORT: parseInt(process.env.PORT, 10) || 5000,
    HOST: process.env.HOST || '0.0.0.0',
    NODE_ENV: process.env.NODE_ENV || 'development',

    IS_PRODUCTION: process.env.NODE_ENV === 'production',
    IS_DEVELOPMENT: process.env.NODE_ENV !== 'production',

    // -----------------------------------------------------
    // 🔐 БЕЗОПАСНОСТЬ
    // -----------------------------------------------------
    JWT_SECRET: process.env.JWT_SECRET,
    JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
    BCRYPT_ROUNDS: parseInt(process.env.BCRYPT_ROUNDS, 10) || 10,
    PASSWORD_PEPPER: process.env.PASSWORD_PEPPER,

    MAX_LOGIN_ATTEMPTS: parseInt(process.env.MAX_LOGIN_ATTEMPTS, 10) || 5,
    LOCKOUT_DURATION_MINUTES: parseInt(process.env.LOCKOUT_DURATION_MINUTES, 10) || 30,

    LOGIN_RATE_LIMIT: parseInt(process.env.LOGIN_RATE_LIMIT, 10) || 5,
    LOGIN_RATE_WINDOW_MINUTES: parseInt(process.env.LOGIN_RATE_WINDOW_MINUTES, 10) || 15,

    // -----------------------------------------------------
    // 💾 БАЗА ДАННЫХ (PostgreSQL)
    // -----------------------------------------------------
    DATABASE_URL: process.env.DATABASE_URL,

    // Настройки пула
    DB_POOL_MAX: parseInt(process.env.DB_POOL_MAX, 10) || 10,
    DB_POOL_IDLE_TIMEOUT: parseInt(process.env.DB_POOL_IDLE_TIMEOUT, 10) || 30000,
    DB_POOL_CONNECTION_TIMEOUT: parseInt(process.env.DB_POOL_CONNECTION_TIMEOUT, 10) || 5000,

    // SSL для PostgreSQL (ONREZA требует require)
    DB_SSL: process.env.DB_SSL !== 'false',

    // -----------------------------------------------------
    // 📸 ФАЙЛЫ
    // -----------------------------------------------------
    UPLOAD_DIR: process.env.UPLOAD_DIR || './uploads',
    MAX_FILE_SIZE: parseInt(process.env.MAX_FILE_SIZE, 10) || 10 * 1024 * 1024,

    // -----------------------------------------------------
    // 🌍 CORS
    // -----------------------------------------------------
    CORS_ORIGIN: process.env.CORS_ORIGIN || '*',

    // -----------------------------------------------------
    // 📋 ПО УМОЛЧАНИЮ
    // -----------------------------------------------------
    DEFAULT_COMMANDER: {
        username: 'admin',
        password: 'admin_secret_2024',
        displayName: 'Администратор',
    },

    MAX_USERS: 100,
    MESSAGE_PAGE_SIZE: 50,
    TYPING_TIMEOUT: 3000,
    ONLINE_TIMEOUT: 60000,
};