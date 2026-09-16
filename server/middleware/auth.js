// =====================================================
// 🛡️ BMSChat — MIDDLEWARE АВТОРИЗАЦИИ (PostgreSQL)
// =====================================================
// Проверяет JWT-токен и загружает пользователя из БД.
//
// Использование:
//   router.get('/profile', authMiddleware, (req, res) => {
//       // req.user доступен
//   });
// =====================================================

const { verifyToken, extractToken } = require('../utils/jwt');
const { pool } = require('../database/init');
const logger = require('../utils/logger');

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
        const result = await pool.query(`
            SELECT id, username, display_name, avatar, status, is_approved
            FROM users
            WHERE id = $1
        `, [payload.userId]);

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
// Загружает пользователя, если токен есть.
// Не блокирует, если токена нет.
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

        const result = await pool.query(`
            SELECT id, username, display_name, avatar, status, is_approved
            FROM users WHERE id = $1
        `, [payload.userId]);

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