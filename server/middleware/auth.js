// =====================================================
// 🛡️ BMSChat — MIDDLEWARE АВТОРИЗАЦИИ (PostgreSQL)
// =====================================================
// Проверяет JWT-токен и загружает пользователя из БД.
//
// 🎯 2026-09-21: queryWithRetry — защита от сбоев Supavisor
// =====================================================

const { verifyToken, extractToken } = require('../utils/jwt');
const { pool } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 🔄 RETRY-ЛОГИКА ДЛЯ НЕСТАБИЛЬНОГО SUPAVISOR
// =====================================================
async function queryWithRetry(sql, params, context = 'query', maxRetries = 3) {
    let lastError;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            return await pool.query(sql, params);
        } catch (err) {
            lastError = err;

            const isRetryable =
                err.message.includes('Query read timeout') ||
                err.message.includes('timeout exceeded') ||
                err.message.includes('Connection terminated') ||
                ['ETIMEDOUT', 'ECONNRESET', 'EPIPE'].includes(err.code);

            if (!isRetryable || attempt === maxRetries) {
                throw err;
            }

            const delay = Math.min(500 * Math.pow(2, attempt - 1), 2000);
            logger.warn(
                `[${context}] retry ${attempt}/${maxRetries} ` +
                `(${err.message}), ждём ${delay}ms`
            );
            await new Promise((r) => setTimeout(r, delay));
        }
    }

    throw lastError;
}

// =====================================================
// 🛡️ ОСНОВНОЙ MIDDLEWARE
// =====================================================
async function authMiddleware(req, res, next) {
    try {
        // 1. Извлекаем токен
        const token = extractToken(req.headers.authorization);

        if (!token) {
            return res.status(401).json({
                error: 'Не авторизован',
                message: 'Требуется заголовок Authorization: Bearer <token>',
            });
        }

        // 2. Проверяем токен
        const payload = verifyToken(token);

        if (!payload || !payload.userId) {
            return res.status(401).json({
                error: 'Недействительный токен',
                message: 'Токен истёк или невалиден',
            });
        }

        // 3. Загружаем пользователя из БД
        const result = await queryWithRetry(`
            SELECT id, username, display_name, avatar, status, is_approved
            FROM users
            WHERE id = $1
        `, [payload.userId], 'authMiddleware');

        if (result.rows.length === 0) {
            return res.status(401).json({
                error: 'Пользователь не найден',
            });
        }

        const user = result.rows[0];

        // 4. Проверяем, подтверждён ли пользователь
        if (!user.is_approved) {
            return res.status(403).json({
                error: 'Аккаунт не подтверждён',
                message: 'Дождитесь подтверждения командира',
            });
        }

        // 5. Кладём пользователя в req.user
        req.user = user;

        // 6. Идём дальше
        next();
    } catch (error) {
        logger.error('Ошибка auth middleware', error);
        return res.status(500).json({ error: 'Ошибка сервера' });
    }
}

// =====================================================
// 🛡️ ОПЦИОНАЛЬНЫЙ MIDDLEWARE
// =====================================================
async function optionalAuthMiddleware(req, res, next) {
    try {
        const token = extractToken(req.headers.authorization);
        if (!token) {
            req.user = null;
            return next();
        }

        const payload = verifyToken(token);
        if (!payload || !payload.userId) {
            req.user = null;
            return next();
        }

        const result = await queryWithRetry(`
            SELECT id, username, display_name, avatar, status, is_approved
            FROM users WHERE id = $1
        `, [payload.userId], 'optionalAuthMiddleware');

        req.user = result.rows.length > 0 ? result.rows[0] : null;
        next();
    } catch (error) {
        req.user = null;
        next();
    }
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================
module.exports = {
    authMiddleware,
    optionalAuthMiddleware,
};