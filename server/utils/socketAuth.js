// =====================================================
// 🔐 BMSChat — АВТОРИЗАЦИЯ SOCKET.IO (PostgreSQL)
// =====================================================
// Проверяет JWT-токен при подключении к WebSocket.
// Загружает пользователя из PostgreSQL.
//
// ⚠️ Все запросы к БД — async (await pool.query)
// ⚠️ is_approved — BOOLEAN (true/false), не 0/1
// =====================================================

const { verifyToken } = require('./jwt');
const { pool } = require('../database/init');
const logger = require('./logger');

/**
 * Middleware для Socket.IO: проверяет токен.
 * 
 * @param {Socket} socket - объект сокета
 * @param {Function} next - колбэк (вызывается при успехе)
 */
async function socketAuth(socket, next) {
    try {
        // ============================================
        // 1. Извлекаем токен
        // ============================================
        const token =
            socket.handshake.auth?.token ||
            socket.handshake.headers?.authorization?.replace('Bearer ', '');

        if (!token) {
            logger.warn('Socket: токен не предоставлен', {
                socketId: socket.id,
                ip: socket.handshake.address,
            });
            return next(new Error('Токен не предоставлен'));
        }

        // ============================================
        // 2. Проверяем токен
        // ============================================
        const payload = verifyToken(token);

        if (!payload || !payload.userId) {
            logger.warn('Socket: недействительный токен', {
                socketId: socket.id,
            });
            return next(new Error('Недействительный токен'));
        }

        // ============================================
        // 3. Загружаем пользователя из PostgreSQL
        // ============================================
        const result = await pool.query(`
            SELECT id, username, display_name, avatar, status, is_approved
            FROM users
            WHERE id = $1
        `, [payload.userId]);

        if (result.rows.length === 0) {
            logger.warn('Socket: пользователь не найден', {
                userId: payload.userId,
            });
            return next(new Error('Пользователь не найден'));
        }

        const user = result.rows[0];

        // ============================================
        // 4. Проверяем подтверждение
        // ============================================
        // ⚠️ PostgreSQL: is_approved — BOOLEAN (true/false)
        if (!user.is_approved) {
            logger.warn('Socket: аккаунт не подтверждён', {
                userId: user.id,
            });
            return next(new Error('Аккаунт не подтверждён'));
        }

        // ============================================
        // 5. Сохраняем пользователя в socket.data
        // ============================================
        socket.data.user = user;

        logger.info('Socket: авторизация успешна', {
            userId: user.id,
            username: user.username,
        });

        next();

    } catch (error) {
        logger.error('Socket: ошибка авторизации', error);
        next(new Error('Ошибка авторизации'));
    }
}

module.exports = socketAuth;