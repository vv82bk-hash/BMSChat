// =====================================================
// 🔐 BMSChat — УТИЛИТЫ ДЛЯ ПАРОЛЕЙ
// =====================================================
// Хеширование паролей: bcrypt + pepper (перец).
//
// СХЕМА РАБОТЫ:
//
//   При регистрации:
//     1. password + PEPPER → pepperPassword
//     2. bcrypt(pepperPassword, rounds) → хеш
//     3. Хеш сохраняется в БД (пароль и перец — НЕ сохраняются)
//
//   При входе:
//     1. password + PEPPER → pepperPassword
//     2. bcrypt.compare(pepperPassword, хеш_из_БД)
//     3. Если совпало — пароль верный
//
// ⚠️ КРИТИЧНО ВАЖНО:
//   • PEPPER хранится ТОЛЬКО в .env, НЕ в БД!
//   • Если потерять перец — НИКТО не сможет войти!
//   • Если утечёт перец + БД — все пароли скомпрометированы
//   • Резервная копия .env обязательна!
//
// ЗАЧЕМ НУЖЕН ПЕРЕЦ:
//   Представьте, что злоумышленник украл файл БД (chat.db).
//   Без перца он может попытаться подобрать пароли через bcrypt.
//   С перцем — он не сможет этого сделать, потому что не знает
//   секретную строку, которая складывается с паролем перед хешированием.
// =====================================================

const bcrypt = require('bcryptjs');
const config = require('../config');

// Загружаем параметры из конфигурации
const ROUNDS = config.BCRYPT_ROUNDS;
const PEPPER = config.PASSWORD_PEPPER;

// -----------------------------------------------------
// 🧂 ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: ДОБАВЛЕНИЕ ПЕРЦА
// -----------------------------------------------------
/**
 * Добавляет перец к паролю.
 * 
 * Пример:
 *   password = "mypassword123"
 *   PEPPER   = "boba_marley_secret"
 *   результат = "mypassword123boba_marley_secret"
 * 
 * @param {string} password - пароль в открытом виде
 * @returns {string} - пароль с перцем
 */
function addPepper(password) {
    return password + PEPPER;
}

// -----------------------------------------------------
// 🔐 ХЕШИРОВАНИЕ ПАРОЛЯ
// -----------------------------------------------------

/**
 * Хеширует пароль (асинхронно).
 * 
 * @param {string} password - пароль в открытом виде
 * @returns {Promise<string>} - хеш пароля
 * 
 * @example
 *   const hash = await hashPassword('secret123');
 *   // hash = "$2a$10$abc123..."
 */
async function hashPassword(password) {
    if (!password || typeof password !== 'string') {
        throw new Error('Пароль должен быть непустой строкой');
    }
    
    // Добавляем перец ПЕРЕД хешированием
    const peppered = addPepper(password);
    
    // Хешируем через bcrypt
    return await bcrypt.hash(peppered, ROUNDS);
}

/**
 * Хеширует пароль (синхронно).
 * 
 * Используется в database/init.js — для создания командира.
 * 
 * @param {string} password - пароль в открытом виде
 * @returns {string} - хеш пароля
 * 
 * @example
 *   const hash = hashPasswordSync('secret123');
 *   // hash = "$2a$10$abc123..."
 */
function hashPasswordSync(password) {
    if (!password || typeof password !== 'string') {
        throw new Error('Пароль должен быть непустой строкой');
    }
    
    const peppered = addPepper(password);
    return bcrypt.hashSync(peppered, ROUNDS);
}

// -----------------------------------------------------
// ✓ ПРОВЕРКА ПАРОЛЯ
// -----------------------------------------------------

/**
 * Проверяет пароль против хеша (асинхронно).
 * 
 * @param {string} password - пароль в открытом виде (введённый пользователем)
 * @param {string} hash - хеш из базы данных
 * @returns {Promise<boolean>} - true, если пароль верный
 * 
 * @example
 *   const valid = await verifyPassword('secret123', user.password);
 *   if (valid) { ... }
 */
async function verifyPassword(password, hash) {
    // Защита от невалидных входных данных
    if (!password || !hash) return false;
    if (typeof password !== 'string') return false;
    if (typeof hash !== 'string') return false;
    
    try {
        const peppered = addPepper(password);
        return await bcrypt.compare(peppered, hash);
    } catch (error) {
        // bcrypt может выбросить ошибку при невалидном хеше
        return false;
    }
}

/**
 * Проверяет пароль (синхронно).
 */
function verifyPasswordSync(password, hash) {
    if (!password || !hash) return false;
    if (typeof password !== 'string') return false;
    if (typeof hash !== 'string') return false;
    
    try {
        const peppered = addPepper(password);
        return bcrypt.compareSync(peppered, hash);
    } catch (error) {
        return false;
    }
}

// -----------------------------------------------------
// 📏 ПРОВЕРКА СИЛЫ ПАРОЛЯ
// -----------------------------------------------------

/**
 * Проверяет, соответствует ли пароль требованиям безопасности.
 * 
 * Требования:
 *   • Минимум 6 символов
 *   • Максимум 100 символов (защита от DoS через длинный пароль)
 * 
 * @param {string} password - пароль для проверки
 * @returns {{valid: boolean, message: string}}
 * 
 * @example
 *   const result = validatePasswordStrength('123');
 *   // result = { valid: false, message: 'Пароль должен содержать минимум 6 символов' }
 */
function validatePasswordStrength(password) {
    if (!password || typeof password !== 'string') {
        return {
            valid: false,
            message: 'Пароль обязателен',
        };
    }
    
    if (password.length < 6) {
        return {
            valid: false,
            message: 'Пароль должен содержать минимум 6 символов',
        };
    }
    
    if (password.length > 100) {
        return {
            valid: false,
            message: 'Пароль слишком длинный (максимум 100 символов)',
        };
    }
    
    return {
        valid: true,
        message: 'OK',
    };
}

// -----------------------------------------------------
// 📤 ЭКСПОРТ
// -----------------------------------------------------

module.exports = {
    // Основные функции
    hashPassword,          // async — для регистрации
    hashPasswordSync,      // sync  — для init-db
    verifyPassword,        // async — для входа
    verifyPasswordSync,    // sync  — для тестов
    
    // Дополнительно
    validatePasswordStrength, // проверка силы пароля
};