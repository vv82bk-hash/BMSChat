// =====================================================
// 🔑 BMSChat — УТИЛИТЫ ДЛЯ JWT-ТОКЕНОВ
// =====================================================
// JWT (JSON Web Token) — это способ передать данные
// о пользователе без хранения сессий на сервере.
//
// Токен содержит:
//   - userId
//   - username
//   - время создания
//   - время истечения
//
// Токен подписан секретным ключом (JWT_SECRET).
// Если кто-то попытается подделать токен —
// подпись не совпадёт, и сервер отклонит токен.
//
// ⚠️ JWT_SECRET должен быть длинным и случайным!
// =====================================================

const jwt = require('jsonwebtoken');
const config = require('../config');

/**
 * Создаёт JWT-токен для пользователя
 * @param {Object} user - объект пользователя
 * @param {number} user.id - ID пользователя
 * @param {string} user.username - логин
 * @returns {string} - JWT-токен
 */
function generateToken(user) {
    const payload = {
        userId: user.id,
        username: user.username,
        // Можно добавить другие поля, но не секретные!
    };

    return jwt.sign(payload, config.JWT_SECRET, {
        expiresIn: config.JWT_EXPIRES_IN || '7d',
    });
}

/**
 * Проверяет JWT-токен
 * @param {string} token - токен из заголовка Authorization
 * @returns {Object|null} - payload или null, если токен невалиден
 */
function verifyToken(token) {
    if (!token) return null;

    try {
        return jwt.verify(token, config.JWT_SECRET);
    } catch (error) {
        // Токен невалиден, истёк, или подпись не совпадает
        return null;
    }
}

/**
 * Извлекает токен из заголовка "Authorization: Bearer <token>"
 * @param {string} authHeader - значение заголовка Authorization
 * @returns {string|null} - токен или null
 */
function extractToken(authHeader) {
    if (!authHeader || typeof authHeader !== 'string') return null;

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') return null;

    return parts[1];
}

/**
 * Декодирует токен без проверки подписи (для отладки)
 * @param {string} token
 * @returns {Object|null}
 */
function decodeToken(token) {
    try {
        return jwt.decode(token);
    } catch (error) {
        return null;
    }
}

module.exports = {
    generateToken,
    verifyToken,
    extractToken,
    decodeToken,
};