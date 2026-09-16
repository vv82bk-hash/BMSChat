// =====================================================
// 🎯 BMSChat — ОБРАБОТЧИКИ SOCKET.IO (PostgreSQL)
// =====================================================

const { pool } = require('../database/init');
const {
    checkChatAccess,
    checkWriteAccess,
    getChatMemberIds,
} = require('../utils/chatAccess');
const logger = require('../utils/logger');

// Хранилища (в памяти)
const typingUsers = new Map();
const onlineUsers = new Map();

const TYPING_TIMEOUT = 3000;

// =====================================================
// 🚀 РЕГИСТРАЦИЯ ОБРАБОТЧИКОВ
// =====================================================
function registerHandlers(io) {
    io.on('connection', (socket) => {
        const user = socket.data.user;
        const userId = user.id;

        handleUserOnline(io, socket, user);

        socket.on('join_chats', () => {
            handleJoinChats(socket, userId);
        });

        socket.on('typing', (data) => {
            handleTyping(io, socket, user, data);
        });

        socket.on('stop_typing', (data) => {
            handleStopTyping(io, socket, user, data);
        });

        socket.on('send_message', (data) => {
            handleSendMessage(io, socket, user, data);
        });

        socket.on('mark_read', (data) => {
            handleMarkRead(io, socket, user, data);
        });

        socket.on('disconnect', () => {
            handleDisconnect(io, socket, user);
        });
    });
}

// =====================================================
// 👤 ПОЛЬЗОВАТЕЛЬ ОНЛАЙН
// =====================================================
async function handleUserOnline(io, socket, user) {
    const userId = user.id;

    if (!onlineUsers.has(userId)) {
        onlineUsers.set(userId, new Set());
    }
    onlineUsers.get(userId).add(socket.id);

    if (onlineUsers.get(userId).size === 1) {
        try {
            await pool.query(`
                UPDATE users
                SET status = 'online', last_seen = NOW()
                WHERE id = $1
            `, [userId]);

            io.emit('user_online', {
                userId: user.id,
                displayName: user.display_name,
            });

            logger.info('Пользователь онлайн', {
                userId,
                displayName: user.display_name,
            });
        } catch (error) {
            logger.error('Ошибка обновления статуса online', error);
        }
    }

    io.emit('online_count', onlineUsers.size);
}

// =====================================================
// 🚪 ПРИСОЕДИНЕНИЕ К КОМНАТАМ
// =====================================================
async function handleJoinChats(socket, userId) {
    try {
        const result = await pool.query(
            'SELECT chat_id FROM chat_members WHERE user_id = $1',
            [userId]
        );

        result.rows.forEach(({ chat_id }) => {
            socket.join(`chat_${chat_id}`);
        });

        socket.emit('joined_chats', {
            chatIds: result.rows.map((c) => c.chat_id),
        });

        logger.info('Socket присоединился к чатам', {
            userId,
            count: result.rows.length,
        });
    } catch (error) {
        logger.error('Ошибка join_chats', error);
    }
}

// =====================================================
// ⌨️ ПЕЧАТАЕТ
// =====================================================
async function handleTyping(io, socket, user, data) {
    const { chatId } = data;
    if (!chatId) return;

    try {
        const access = await checkChatAccess(chatId, user.id);
        if (!access.allowed) {
            logger.logAccessDenied(user.id, chatId, 'typing');
            return;
        }

        const key = `${user.id}_${chatId}`;

        if (typingUsers.has(key)) {
            clearTimeout(typingUsers.get(key).timeout);
        }

        const timeout = setTimeout(() => {
            typingUsers.delete(key);
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

        socket.to(`chat_${chatId}`).emit('user_typing', {
            chatId,
            userId: user.id,
            displayName: user.display_name,
        });
    } catch (error) {
        logger.error('Ошибка typing', error);
    }
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
async function handleSendMessage(io, socket, user, data) {
    const { chatId, text, replyToId, tempId } = data;

    if (!chatId) return;
    if (!text?.trim() && !replyToId) return;

    try {
        const access = await checkWriteAccess(chatId, user.id);
        if (!access.allowed) {
            socket.emit('error', { message: access.reason });
            logger.logAccessDenied(user.id, chatId, 'send_message');
            return;
        }

        const result = await pool.query(`
            INSERT INTO messages (chat_id, sender_id, text, reply_to_id)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        `, [chatId, user.id, text?.trim() || null, replyToId || null]);

        const messageId = result.rows[0].id;

        const messageResult = await pool.query(`
            SELECT 
                m.id, m.chat_id, m.sender_id, m.text, m.reply_to_id,
                m.is_deleted, m.is_edited, m.created_at, m.updated_at,
                u.username, u.display_name, u.avatar
            FROM messages m
            INNER JOIN users u ON u.id = m.sender_id
            WHERE m.id = $1
        `, [messageId]);

        const message = messageResult.rows[0];

        // Останавливаем «печатает»
        handleStopTyping(io, socket, user, { chatId });

        // Рассылаем всем в комнате
        io.to(`chat_${chatId}`).emit('new_message', {
            ...message,
            reactions: [],
            attachments: [],
            tempId,
        });

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
async function handleMarkRead(io, socket, user, data) {
    const { chatId, messageId } = data;
    if (!chatId || !messageId) return;

    try {
        const access = await checkChatAccess(chatId, user.id);
        if (!access.allowed) return;

        await pool.query(`
            UPDATE chat_members
            SET last_read_message_id = $1
            WHERE chat_id = $2 AND user_id = $3
        `, [messageId, chatId, user.id]);

        socket.to(`chat_${chatId}`).emit('message_read', {
            chatId,
            userId: user.id,
            messageId,
        });
    } catch (error) {
        logger.error('Ошибка mark_read', error);
    }
}

// =====================================================
// 🚪 ОТКЛЮЧЕНИЕ
// =====================================================
async function handleDisconnect(io, socket, user) {
    const userId = user.id;

    if (onlineUsers.has(userId)) {
        onlineUsers.get(userId).delete(socket.id);

        if (onlineUsers.get(userId).size === 0) {
            onlineUsers.delete(userId);

            try {
                await pool.query(`
                    UPDATE users
                    SET status = 'offline', last_seen = NOW()
                    WHERE id = $1
                `, [userId]);

                io.emit('user_offline', {
                    userId: user.id,
                    lastSeen: new Date().toISOString(),
                });

                logger.logSocket(userId, 'disconnect');
            } catch (error) {
                logger.error('Ошибка обновления статуса offline', error);
            }
        }
    }

    // Убираем из «печатающих»
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

    io.emit('online_count', onlineUsers.size);
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================
module.exports = {
    registerHandlers,
    onlineUsers,
};