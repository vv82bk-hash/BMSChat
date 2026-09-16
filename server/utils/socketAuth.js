// =====================================================
// 🔐 BMSChat — АВТОРИЗАЦИЯ SOCKET.IO
// =====================================================
// Проверяет JWT-токен при подключении к WebSocket.
//
// КАК РАБОТАЕТ:
//   Клиент подключается:
//     io("http://localhost:5000", { auth: { token: "..." } })
//
//   Middleware проверяет токен:
//     - Валидный? → загружает user из БД → next()
//     - Невалидный? → next(new Error("..."))
//
// БЕЗ ЭТОГО:
//   Любой мог бы подключиться и читать чужие чаты.
// =====================================================

const { verifyToken } = require('./jwt');
const { db } = require('../database/init');
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
        // Токен может быть в:
        //   • socket.handshake.auth.token (современный способ)
        //   • Authorization: Bearer <token> (заголовок)
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
        // 3. Загружаем пользователя из БД
        // ============================================
        const user = db.prepare(`
            SELECT id, username, display_name, avatar, status, is_approved
            FROM users
            WHERE id = ?
        `).get(payload.userId);

        if (!user) {
            logger.warn('Socket: пользователь не найден', {
                userId: payload.userId,
            });
            return next(new Error('Пользователь не найден'));
        }

        // ============================================
        // 4. Проверяем подтверждение
        // ============================================
        if (!user.is_approved) {
            logger.warn('Socket: аккаунт не подтверждён', {
                userId: user.id,
            });
            return next(new Error('Аккаунт не подтверждён'));
        }

        // ============================================
        // 5. Сохраняем пользователя в socket.data
        // ============================================
        // Доступ через socket.data.user в handlers.js
        socket.data.user = user;

        logger.info('Socket: авторизация успешна', {
            userId: user.id,
            username: user.username,
        });

        next(); // ✅ Пропускаем

    } catch (error) {
        logger.error('Socket: ошибка авторизации', error);
        next(new Error('Ошибка авторизации'));
    }
}

module.exports = socketAuth;