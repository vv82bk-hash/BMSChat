// =====================================================
// 🎯 BMSChat — КОНФИГУРАЦИЯ СЕРВЕРА
// =====================================================
// Этот файл:
//   1. Читает переменные из .env
//   2. Проверяет обязательные переменные
//   3. Предупреждает о стандартных значениях
//   4. Экспортирует всё в удобном виде
//
// Использование:
//   const config = require('./config');
//   console.log(config.PORT);              // 5000
//   console.log(config.PASSWORD_PEPPER);   // '...'
// =====================================================

// Загружаем переменные из .env
require('dotenv').config();

// =====================================================
// ⚠️ ПРОВЕРКА ОБЯЗАТЕЛЬНЫХ ПЕРЕМЕННЫХ
// =====================================================
// Если чего-то не хватает — сервер не запустится.
// Это лучше, чем молча работать с дефолтными значениями.

const requiredEnvVars = [
    'JWT_SECRET',
    'PASSWORD_PEPPER',
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
// Не блокируем запуск, но громко предупреждаем.

const DEFAULT_JWT_SECRET = 'boba_marley_rasta_secret_2024_change_me_in_production';
const DEFAULT_PEPPER = 'boba_marley_pepper_change_me_in_production_2024_rasta_love';

if (process.env.JWT_SECRET === DEFAULT_JWT_SECRET) {
    console.warn('');
    console.warn('⚠️  ВНИМАНИЕ: Используется стандартный JWT_SECRET!');
    console.warn('⚠️  В продакшене ОБЯЗАТЕЛЬНО замените его в .env');
    console.warn('⚠️  Сгенерировать: openssl rand -hex 32');
    console.warn('');
}

if (process.env.PASSWORD_PEPPER === DEFAULT_PEPPER) {
    console.warn('');
    console.warn('⚠️  ВНИМАНИЕ: Используется стандартный PASSWORD_PEPPER!');
    console.warn('⚠️  В продакшене ОБЯЗАТЕЛЬНО замените его в .env');
    console.warn('⚠️  Сгенерировать: openssl rand -hex 32');
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

    // Флаги окружения (удобно для проверок)
    IS_PRODUCTION: process.env.NODE_ENV === 'production',
    IS_DEVELOPMENT: process.env.NODE_ENV !== 'production',

    // -----------------------------------------------------
    // 🔐 БЕЗОПАСНОСТЬ
    // -----------------------------------------------------
    JWT_SECRET: process.env.JWT_SECRET,
    JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
    BCRYPT_ROUNDS: parseInt(process.env.BCRYPT_ROUNDS, 10) || 10,

    // Pepper (перец) — дополнительный секрет для паролей
    // Используется в utils/password.js
    PASSWORD_PEPPER: process.env.PASSWORD_PEPPER,

    // Блокировка аккаунта после неудачных попыток
    MAX_LOGIN_ATTEMPTS: parseInt(process.env.MAX_LOGIN_ATTEMPTS, 10) || 5,
    LOCKOUT_DURATION_MINUTES: parseInt(process.env.LOCKOUT_DURATION_MINUTES, 10) || 30,

    // Rate Limiting (ограничение частоты запросов)
    LOGIN_RATE_LIMIT: parseInt(process.env.LOGIN_RATE_LIMIT, 10) || 5,
    LOGIN_RATE_WINDOW_MINUTES: parseInt(process.env.LOGIN_RATE_WINDOW_MINUTES, 10) || 15,

    // -----------------------------------------------------
    // 💾 БАЗА ДАННЫХ
    // -----------------------------------------------------
    DB_TYPE: process.env.DB_TYPE || 'sqlite',
    DB_PATH: process.env.DB_PATH || './database/chat.db',

    // Ключ шифрования БД (SQLCipher) — добавим позже
    // Если null — БД не шифруется
    DB_ENCRYPTION_KEY: process.env.DB_ENCRYPTION_KEY || null,

    // -----------------------------------------------------
    // 📸 ФАЙЛЫ
    // -----------------------------------------------------
    UPLOAD_DIR: process.env.UPLOAD_DIR || './uploads',
    MAX_FILE_SIZE: parseInt(process.env.MAX_FILE_SIZE, 10) || 10 * 1024 * 1024, // 10 МБ

    // -----------------------------------------------------
    // 🌍 CORS
    // -----------------------------------------------------
    // Локально: '*'
    // Продакшен: 'https://your-domain.ru'
    CORS_ORIGIN: process.env.CORS_ORIGIN || '*',

    // -----------------------------------------------------
    // 📋 ПО УМОЛЧАНИЮ (для первого запуска)
    // -----------------------------------------------------
    // При первой инициализации БД создаётся командир.
    // ⚠️ Пароль сменить после первого входа!
    DEFAULT_COMMANDER: {
        username: 'commander',
        password: 'boba_marley_2024',
        displayName: 'Командир Боб',
    },

    // -----------------------------------------------------
    // ⏱️ ЛИМИТЫ И ТАЙМАУТЫ
    // -----------------------------------------------------
    MAX_USERS: 100,                    // Максимум пользователей
    MESSAGE_PAGE_SIZE: 50,             // Сколько сообщений за раз
    TYPING_TIMEOUT: 3000,              // Через сколько мс сбрасывать "печатает"
    ONLINE_TIMEOUT: 60000,             // Через сколько мс считать офлайн
};