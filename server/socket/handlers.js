// =====================================================
// 🎯 BMSChat — ОБРАБОТЧИКИ SOCKET.IO
// =====================================================
// Реальное время: "печатает...", онлайн-статусы,
// мгновенная доставка сообщений.
//
// ГЛАВНЫЙ ПРИНЦИП "ПЕЧАТАЕТ...":
//   • Клиент отправляет событие "typing" пока печатает
//   • Отправляет НЕ на каждую букву, а раз в 2 сек (throttling)
//   • Сервер рассылает всем в чате КРОМЕ отправителя
//   • Клиент-получатель показывает "печатает..."
//   • Если 3 сек нет событий — скрывает
//
// БЕЗОПАСНОСТЬ:
//   • Проверяем chat_members ПЕРЕД рассылкой
//   • Командир НЕ получает события из личных чатов
//   • Все попытки доступа логируются
// =====================================================

const { db } = require('../database/init');
const {
    checkChatAccess,
    checkWriteAccess,
    getChatMemberIds,
} = require('../utils/chatAccess');
const logger = require('../utils/logger');

// =====================================================
// 🗂️ ХРАНИЛИЩА (в памяти)
// =====================================================

// Кто сейчас печатает: Map<`${userId}_${chatId}`, { chatId, userId, displayName, timeout }>
const typingUsers = new Map();

// Кто онлайн: Map<userId, Set<socketId>>
// Один пользователь может иметь несколько устройств
const onlineUsers = new Map();

// Таймауты "печатает" — через сколько мс сбрасывать
const TYPING_TIMEOUT = 3000;

// =====================================================
// 🚀 РЕГИСТРАЦИЯ ОБРАБОТЧИКОВ
// =====================================================
function registerHandlers(io) {
    io.on('connection', (socket) => {
        const user = socket.data.user;
        const userId = user.id;

        // -------------------------------------------------
        // 1. ПРИ ПОДКЛЮЧЕНИИ: обновляем онлайн-статус
        // -------------------------------------------------
        handleUserOnline(io, socket, user);

        // -------------------------------------------------
        // 2. ПОДКЛЮЧЕНИЕ К КОМНАТАМ ЧАТОВ
        // -------------------------------------------------
        socket.on('join_chats', () => {
            handleJoinChats(socket, userId);
        });

        // -------------------------------------------------
        // 3. "ПЕЧАТАЕТ..." — основная логика
        // -------------------------------------------------
        socket.on('typing', (data) => {
            handleTyping(io, socket, user, data);
        });

        // -------------------------------------------------
        // 4. ОСТАНОВКА ПЕЧАТИ
        // -------------------------------------------------
        socket.on('stop_typing', (data) => {
            handleStopTyping(io, socket, user, data);
        });

        // -------------------------------------------------
        // 5. ОТПРАВКА СООБЩЕНИЯ
        // -------------------------------------------------
        socket.on('send_message', (data) => {
            handleSendMessage(io, socket, user, data);
        });

        // -------------------------------------------------
        // 6. ПРОЧИТАНО
        // -------------------------------------------------
        socket.on('mark_read', (data) => {
            handleMarkRead(io, socket, user, data);
        });

        // -------------------------------------------------
        // 7. ОТКЛЮЧЕНИЕ
        // -------------------------------------------------
        socket.on('disconnect', () => {
            handleDisconnect(io, socket, user);
        });
    });
}

// =====================================================
// 👤 ПОЛЬЗОВАТЕЛЬ ОНЛАЙН
// =====================================================
function handleUserOnline(io, socket, user) {
    const userId = user.id;

    // Добавляем socketId в Set (мультиустройство)
    if (!onlineUsers.has(userId)) {
        onlineUsers.set(userId, new Set());
    }
    onlineUsers.get(userId).add(socket.id);

    // Первое устройство → обновляем статус в БД
    if (onlineUsers.get(userId).size === 1) {
        db.prepare(`
            UPDATE users
            SET status = 'online', last_seen = CURRENT_TIMESTAMP
            WHERE id = ?
        `).run(userId);

        // Уведомляем всех
        io.emit('user_online', {
            userId: user.id,
            displayName: user.display_name,
        });

        logger.info('Пользователь онлайн', {
            userId,
            displayName: user.display_name,
        });
    }

    // Отправляем счётчик онлайн всем
    io.emit('online_count', onlineUsers.size);
}

// =====================================================
// 🚪 ПОДКЛЮЧЕНИЕ К КОМНАТАМ ЧАТОВ
// =====================================================
function handleJoinChats(socket, userId) {
    // Находим все чаты, где пользователь — участник
    const chats = db.prepare(`
        SELECT chat_id FROM chat_members WHERE user_id = ?
    `).all(userId);

    // Подключаем сокет к каждой комнате
    chats.forEach(({ chat_id }) => {
        socket.join(`chat_${chat_id}`);
    });

    socket.emit('joined_chats', {
        chatIds: chats.map(c => c.chat_id),
    });

    logger.info('Socket присоединился к чатам', {
        userId,
        count: chats.length,
    });
}

// =====================================================
// ⌨️ "ПЕЧАТАЕТ..." — ГЛАВНАЯ ЛОГИКА
// =====================================================
function handleTyping(io, socket, user, data) {
    const { chatId } = data;

    if (!chatId) return;

    // ============================================
    // 1. ПРОВЕРКА: пользователь — участник чата?
    // ============================================
    const access = checkChatAccess(chatId, user.id);
    if (!access.allowed) {
        // Молча игнорируем (не выдаём ошибку, чтобы не спамить)
        logger.logAccessDenied(user.id, chatId, 'typing');
        return;
    }

    const key = `${user.id}_${chatId}`;

    // Сбрасываем старый таймер
    if (typingUsers.has(key)) {
        clearTimeout(typingUsers.get(key).timeout);
    }

    // Новый таймер: если 3 сек нет событий — считаем, что перестал печатать
    const timeout = setTimeout(() => {
        typingUsers.delete(key);
        // Уведомляем остальных, что печать прекращена
        socket.to(`chat_${chatId}`).emit('user_stopped_typing', {
            chatId,
            userId: user.id,
        });
    }, TYPING_TIMEOUT);

    typingUsers.set(key, {
        chatId,
        userId: user.id,
        displayName: user.display_name,
        timeout,
    });

    // ============================================
    // 2. ОТПРАВЛЯЕМ СОБЫТИЕ ВСЕМ В ЧАТЕ, КРОМЕ ОТПРАВИТЕЛЯ
    // ============================================
    // socket.to(room) — всем в комнате, КРОМЕ этого сокета
    socket.to(`chat_${chatId}`).emit('user_typing', {
        chatId,
        userId: user.id,
        displayName: user.display_name,
    });
}

// =====================================================
// ⏹️ ОСТАНОВКА ПЕЧАТИ
// =====================================================
function handleStopTyping(io, socket, user, data) {
    const { chatId } = data;
    if (!chatId) return;

    const key = `${user.id}_${chatId}`;

    if (typingUsers.has(key)) {
        clearTimeout(typingUsers.get(key).timeout);
        typingUsers.delete(key);
    }

    socket.to(`chat_${chatId}`).emit('user_stopped_typing', {
        chatId,
        userId: user.id,
    });
}

// =====================================================
// 💬 ОТПРАВКА СООБЩЕНИЯ
// =====================================================
function handleSendMessage(io, socket, user, data) {
    const { chatId, text, replyToId, tempId } = data;

    if (!chatId) return;
    if (!text?.trim() && !replyToId) return;

    // ============================================
    // 1. ПРОВЕРКА ПРАВА ПИСАТЬ
    // ============================================
    const access = checkWriteAccess(chatId, user.id);
    if (!access.allowed) {
        socket.emit('error', { message: access.reason });
        logger.logAccessDenied(user.id, chatId, 'send_message');
        return;
    }

    try {
        // ============================================
        // 2. СОХРАНЯЕМ В БД
        // ============================================
        const result = db.prepare(`
            INSERT INTO messages (chat_id, sender_id, text, reply_to_id)
            VALUES (?, ?, ?, ?)
        `).run(chatId, user.id, text?.trim() || null, replyToId || null);

        const messageId = result.lastInsertRowid;

        // ============================================
        // 3. ЗАГРУЖАЕМ ПОЛНОЕ СООБЩЕНИЕ
        // ============================================
        const message = db.prepare(`
            SELECT 
                m.id, m.chat_id, m.sender_id, m.text, m.reply_to_id,
                m.is_deleted, m.is_edited, m.created_at, m.updated_at,
                u.username, u.display_name, u.avatar
            FROM messages m
            INNER JOIN users u ON u.id = m.sender_id
            WHERE m.id = ?
        `).get(messageId);

        // ============================================
        // 4. ОСТАНАВЛИВАЕМ "ПЕЧАТАЕТ..."
        // ============================================
        handleStopTyping(io, socket, user, { chatId });

        // ============================================
        // 5. РАССЫЛАЕМ ВСЕМ В КОМНАТЕ (включая отправителя)
        // ============================================
        // io.to(room) — всем в комнате, включая отправителя
        io.to(`chat_${chatId}`).emit('new_message', {
            ...message,
            tempId, // чтобы клиент сопоставил с временным сообщением
        });

        // Безопасное логирование (без текста!)
        logger.logMessage(user.id, chatId, text?.length || 0);

    } catch (error) {
        logger.error('Ошибка отправки сообщения', error, {
            userId: user.id,
            chatId,
        });
        socket.emit('error', { message: 'Ошибка отправки' });
    }
}

// =====================================================
// ✓✓ ПРОЧИТАНО
// =====================================================
function handleMarkRead(io, socket, user, data) {
    const { chatId, messageId } = data;
    if (!chatId || !messageId) return;

    // Проверка доступа
    const access = checkChatAccess(chatId, user.id);
    if (!access.allowed) return;

    // Обновляем last_read_message_id
    db.prepare(`
        UPDATE chat_members
        SET last_read_message_id = ?
        WHERE chat_id = ? AND user_id = ?
    `).run(messageId, chatId, user.id);

    // Уведомляем остальных (для галочек "прочитано")
    socket.to(`chat_${chatId}`).emit('message_read', {
        chatId,
        userId: user.id,
        messageId,
    });
}

// =====================================================
// 🚪 ОТКЛЮЧЕНИЕ
// =====================================================
function handleDisconnect(io, socket, user) {
    const userId = user.id;

    // Удаляем socketId из Set
    if (onlineUsers.has(userId)) {
        onlineUsers.get(userId).delete(socket.id);

        // Если это было последнее устройство → офлайн
        if (onlineUsers.get(userId).size === 0) {
            onlineUsers.delete(userId);

            db.prepare(`
                UPDATE users
                SET status = 'offline', last_seen = CURRENT_TIMESTAMP
                WHERE id = ?
            `).run(userId);

            io.emit('user_offline', {
                userId: user.id,
                lastSeen: new Date().toISOString(),
            });

            logger.logSocket(userId, 'disconnect');
        }
    }

    // Убираем из "печатающих"
    for (const [key, val] of typingUsers.entries()) {
        if (val.userId === userId) {
            clearTimeout(val.timeout);
            typingUsers.delete(key);
            io.to(`chat_${val.chatId}`).emit('user_stopped_typing', {
                chatId: val.chatId,
                userId,
            });
        }
    }

    // Обновляем счётчик онлайн
    io.emit('online_count', onlineUsers.size);
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================
module.exports = {
    registerHandlers,
    onlineUsers, // экспортируем для использования в REST API
};