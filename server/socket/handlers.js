// =====================================================
// 🎯 BMSChat — ОБРАБОТЧИКИ SOCKET.IO (PostgreSQL)
// =====================================================
// 🎯 2026-09-21: queryWithRetry — защита от сбоев Supavisor
// 🎯 2026-10-09: FCM — push офлайн-участникам
// 🎯 2026-10-09 (Mute): push не отправляется для замьюченных чатов
// =====================================================

const { pool } = require('../database/init');
const {
    checkChatAccess,
    checkWriteAccess,
    getChatMemberIds,
} = require('../utils/chatAccess');
const fcm = require('../utils/fcm');
const logger = require('../utils/logger');

// Хранилища (в памяти)
const typingUsers = new Map();
const onlineUsers = new Map();

const TYPING_TIMEOUT = 3000;

// =====================================================
// 🔄 RETRY-ЛОГИКА
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

        socket.on('join_admins', () => {
            handleJoinAdmins(socket, user);
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
// 👑 ПОДПИСКА НА КАНАЛ ЗАЯВОК
// =====================================================
async function handleJoinAdmins(socket, user) {
    try {
        const result = await queryWithRetry(`
            SELECT 1
            FROM user_roles ur
            INNER JOIN roles r ON r.id = ur.role_id
            WHERE ur.user_id = $1 AND r.can_approve_users = TRUE
            LIMIT 1
        `, [user.id], 'handleJoinAdmins');

        if (result.rows.length === 0) {
            logger.warn('Нет права на канал заявок', { userId: user.id });
            return;
        }

        socket.join('admins');
        logger.info('Подписан на канал заявок', {
            userId: user.id,
            displayName: user.display_name,
        });

        const pending = await queryWithRetry(
            'SELECT COUNT(*) as cnt FROM users WHERE is_approved = FALSE',
            [],
            'handleJoinAdmins:pending'
        );
        socket.emit('pending_count', {
            count: parseInt(pending.rows[0].cnt, 10),
        });
    } catch (error) {
        logger.error('Ошибка join_admins', error);
    }
}

// =====================================================
// 🔔 УВЕДОМЛЕНИЕ О НОВОМ НОВОБРАНЦЕ
// =====================================================
async function notifyAdminsNewRecruit(io, newUser) {
    try {
        const pending = await queryWithRetry(
            'SELECT COUNT(*) as cnt FROM users WHERE is_approved = FALSE',
            [],
            'notifyAdminsNewRecruit'
        );
        const count = parseInt(pending.rows[0].cnt, 10);

        io.to('admins').emit('new_recruit', {
            user: {
                id: newUser.id,
                username: newUser.username,
                display_name: newUser.display_name,
                created_at: newUser.created_at,
            },
            pendingCount: count,
        });

        io.to('admins').emit('pending_count', { count });

        logger.info('Уведомление о новом новобранце отправлено', {
            newUserId: newUser.id,
            pendingCount: count,
        });
    } catch (error) {
        logger.error('Ошибка notifyAdminsNewRecruit', error);
    }
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
            await queryWithRetry(`
                UPDATE users
                SET status = 'online', last_seen = NOW()
                WHERE id = $1
            `, [userId], 'handleUserOnline');

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
        const result = await queryWithRetry(
            'SELECT chat_id FROM chat_members WHERE user_id = $1',
            [userId],
            'handleJoinChats'
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

        const result = await queryWithRetry(`
            INSERT INTO messages (chat_id, sender_id, text, reply_to_id)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        `, [chatId, user.id, text?.trim() || null, replyToId || null], 'handleSendMessage:insert');

        const messageId = result.rows[0].id;

        const messageResult = await queryWithRetry(`
            SELECT 
                m.id, m.chat_id, m.sender_id, m.text, m.reply_to_id,
                m.is_deleted, m.is_edited, m.created_at, m.updated_at,
                u.username, u.display_name, u.avatar
            FROM messages m
            INNER JOIN users u ON u.id = m.sender_id
            WHERE m.id = $1
        `, [messageId], 'handleSendMessage:select');

        const message = messageResult.rows[0];

        handleStopTyping(io, socket, user, { chatId });

        io.to(`chat_${chatId}`).emit('new_message', {
            ...message,
            reactions: [],
            attachments: [],
            tempId,
        });

        // 🎯 FCM: push офлайн-участникам (fire-and-forget)
        sendPushToOfflineMembers(io, chatId, user, message)
            .catch((err) => logger.error('Ошибка sendPushToOfflineMembers', err));

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
// 🔔 FCM: PUSH ОФЛАЙН-УЧАСТНИКАМ
// =====================================================
// 1. Берём участников чата с fcm_token (кроме отправителя),
//    у которых НЕТ записи в chat_mutes.
// 2. Фильтруем: только те, кто НЕ в onlineUsers.
// 3. Отправляем push через fcm.sendToTokens.
// =====================================================
async function sendPushToOfflineMembers(io, chatId, sender, message) {
    try {
        // 1. Участники чата с fcm_token, кроме отправителя,
        //    и БЕЗ mute этого чата
        const result = await queryWithRetry(`
            SELECT u.id, u.fcm_token
            FROM chat_members cm
            INNER JOIN users u ON u.id = cm.user_id
            WHERE cm.chat_id = $1
              AND cm.user_id != $2
              AND u.fcm_token IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM chat_mutes cm_mutes
                  WHERE cm_mutes.user_id = u.id
                    AND cm_mutes.chat_id = $1
              )
        `, [chatId, sender.id], 'sendPushToOfflineMembers:members');

        if (result.rows.length === 0) return;

        // 2. Фильтруем офлайн
        const offlineTokens = result.rows
            .filter((row) => !onlineUsers.has(row.id))
            .map((row) => row.fcm_token)
            .filter((token) => token && token.length > 0);

        if (offlineTokens.length === 0) return;

        // 3. Формируем текст уведомления
        const senderName = sender.display_name || sender.username || 'Кто-то';
        const bodyText = message.text || 'Новое сообщение';

        // 4. Отправляем
        await fcm.sendToTokens(offlineTokens, {
            title: senderName,
            body: bodyText.length > 100
                ? `${bodyText.substring(0, 100)}...`
                : bodyText,
            chatId,
            senderName,
            type: 'message',
        });

        logger.info('FCM push офлайн-участникам', {
            chatId,
            senderId: sender.id,
            offlineCount: offlineTokens.length,
        });
    } catch (error) {
        logger.error('Ошибка sendPushToOfflineMembers', error, {
            chatId,
            senderId: sender.id,
        });
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

        await queryWithRetry(`
            UPDATE chat_members
            SET last_read_message_id = $1
            WHERE chat_id = $2 AND user_id = $3
        `, [messageId, chatId, user.id], 'handleMarkRead');

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
                await queryWithRetry(`
                    UPDATE users
                    SET status = 'offline', last_seen = NOW()
                    WHERE id = $1
                `, [userId], 'handleDisconnect');

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
    notifyAdminsNewRecruit,
    onlineUsers,
};