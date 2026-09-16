// =====================================================
// 🛡️ BMSChat — MIDDLEWARE АВТОРИЗАЦИИ
// =====================================================
// Проверяет, что пользователь авторизован.
//
// Как это работает:
//   1. Клиент отправляет заголовок: Authorization: Bearer <token>
//   2. Middleware извлекает токен
//   3. Проверяет токен через jwt.verifyToken()
//   4. Загружает пользователя из БД
//   5. Кладёт его в req.user
//   6. Передаёт управление дальше (next())
//
// Если токен невалиден — возвращает 401 Unauthorized.
// =====================================================

const { verifyToken, extractToken } = require('../utils/jwt');
const { db } = require('../database/init');

/**
 * Основной middleware: требует авторизации
 */
async function authMiddleware(req, res, next) {
    try {
        // 1. Извлекаем токен из заголовка
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
        const user = db.prepare(`
            SELECT id, username, display_name, avatar, status, is_approved
            FROM users
            WHERE id = ?
        `).get(payload.userId);

        if (!user) {
            return res.status(401).json({
                error: 'Пользователь не найден',
            });
        }

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
        console.error('❌ Ошибка auth middleware:', error);
        return res.status(500).json({ error: 'Ошибка сервера' });
    }
}

/**
 * Опциональный middleware: загружает пользователя, если токен есть,
 * но не блокирует запрос, если его нет.
 */
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

        const user = db.prepare(`
            SELECT id, username, display_name, avatar, status, is_approved
            FROM users WHERE id = ?
        `).get(payload.userId);

        req.user = user || null;
        next();

    } catch (error) {
        req.user = null;
        next();
    }
}

module.exports = {
    authMiddleware,
    optionalAuthMiddleware,
};