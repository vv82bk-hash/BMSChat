// =====================================================
// 🔐 BMSChat — ПРОВЕРКА ДОСТУПА К ЧАТАМ (PostgreSQL)
// =====================================================
// ⚠️ Все функции — async (await в роутах обязателен!)
// =====================================================

const { pool } = require('../database/init');
const { getMergedPermissions } = require('../middleware/roles');
const logger = require('./logger');

// =====================================================
// 🔐 ПРОВЕРКА ДОСТУПА К ЧАТУ (чтение)
// =====================================================
async function checkChatAccess(chatId, userId) {
    if (!chatId || !userId) {
        return { allowed: false, reason: 'Неверные параметры' };
    }

    // 1. Чат существует?
    const chatResult = await pool.query(
        'SELECT id, type, is_active FROM chats WHERE id = $1',
        [chatId]
    );

    if (chatResult.rows.length === 0) {
        return { allowed: false, reason: 'Чат не найден' };
    }

    const chat = chatResult.rows[0];

    if (!chat.is_active) {
        return { allowed: false, reason: 'Чат деактивирован' };
    }

    // 2. Пользователь — участник?
    const memberResult = await pool.query(
        'SELECT role FROM chat_members WHERE chat_id = $1 AND user_id = $2',
        [chatId, userId]
    );

    if (memberResult.rows.length === 0) {
        logger.logAccessDenied(userId, chatId, 'не участник чата');
        return { allowed: false, reason: 'Вы не участник этого чата' };
    }

    return {
        allowed: true,
        role: memberResult.rows[0].role,
        chatType: chat.type,
    };
}

// =====================================================
// ✍️ ПРОВЕРКА ПРАВА ПИСАТЬ
// =====================================================
async function checkWriteAccess(chatId, userId) {
    const access = await checkChatAccess(chatId, userId);
    if (!access.allowed) return { allowed: false, reason: access.reason };

    const perms = await getMergedPermissions(userId);

    switch (access.chatType) {
        case 'channel': {
            if (perms.can_create_feed || perms.can_manage_roles) {
                return { allowed: true };
            }
            return { allowed: false, reason: 'В канале могут писать только админы' };
        }

        case 'general': {
            if (perms.can_write_general) return { allowed: true };
            return { allowed: false, reason: 'Только чтение. Дождитесь подтверждения командира.' };
        }

        case 'group': {
            if (perms.can_write_general) return { allowed: true };
            return { allowed: false, reason: 'Нет права писать в группы' };
        }

        case 'private': {
            const otherUserId = await getOtherPrivateMember(chatId, userId);
            if (!otherUserId) {
                return { allowed: false, reason: 'Собеседник не найден' };
            }

            const otherIsCommander = await isCommanderOrHigher(otherUserId);

            if (perms.can_write_to_commander && otherIsCommander) {
                return { allowed: true };
            }

            if (perms.can_write_private) {
                return { allowed: true };
            }

            if (perms.can_write_to_commander && !otherIsCommander) {
                return {
                    allowed: false,
                    reason: 'На испытательном сроке можно писать только командиру',
                };
            }

            return { allowed: false, reason: 'Нет права писать в личные чаты' };
        }

        default:
            return { allowed: false, reason: 'Неизвестный тип чата' };
    }
}

// =====================================================
// 👤 СОБЕСЕДНИК В ЛИЧНОМ ЧАТЕ
// =====================================================
async function getOtherPrivateMember(chatId, userId) {
    const result = await pool.query(
        'SELECT user_id FROM chat_members WHERE chat_id = $1 AND user_id != $2 LIMIT 1',
        [chatId, userId]
    );
    return result.rows.length > 0 ? result.rows[0].user_id : null;
}

// =====================================================
// 👑 КОМАНДИР ИЛИ ВЫШЕ?
// =====================================================
async function isCommanderOrHigher(userId) {
    const result = await pool.query(`
        SELECT 1 FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = $1 AND r.name IN ('Командир', 'Администратор')
        LIMIT 1
    `, [userId]);
    return result.rows.length > 0;
}

// =====================================================
// 👑 АДМИН ЧАТА?
// =====================================================
async function isChatAdmin(chatId, userId) {
    if (!chatId || !userId) return false;

    const result = await pool.query(
        `SELECT role FROM chat_members 
         WHERE chat_id = $1 AND user_id = $2 AND role = 'admin'`,
        [chatId, userId]
    );
    return result.rows.length > 0;
}

// =====================================================
// ✏️ РЕДАКТИРОВАНИЕ
// =====================================================
async function checkEditAccess(messageId, userId) {
    if (!messageId || !userId) {
        return { allowed: false, reason: 'Неверные параметры' };
    }

    const result = await pool.query(
        'SELECT id, sender_id, chat_id, is_deleted FROM messages WHERE id = $1',
        [messageId]
    );

    if (result.rows.length === 0) {
        return { allowed: false, reason: 'Сообщение не найдено' };
    }

    const message = result.rows[0];

    if (message.is_deleted) {
        return { allowed: false, reason: 'Сообщение удалено' };
    }

    if (message.sender_id !== userId) {
        logger.logAccessDenied(userId, message.chat_id, 'попытка редактировать чужое');
        return { allowed: false, reason: 'Вы можете редактировать только свои сообщения' };
    }

    return { allowed: true, message };
}

// =====================================================
// 🗑️ УДАЛЕНИЕ
// =====================================================
async function checkDeleteAccess(messageId, userId) {
    if (!messageId || !userId) {
        return { allowed: false, reason: 'Неверные параметры' };
    }

    const result = await pool.query(
        'SELECT id, sender_id, chat_id, is_deleted FROM messages WHERE id = $1',
        [messageId]
    );

    if (result.rows.length === 0) {
        return { allowed: false, reason: 'Сообщение не найдено' };
    }

    const message = result.rows[0];

    if (message.is_deleted) {
        return { allowed: false, reason: 'Сообщение уже удалено' };
    }

    if (message.sender_id === userId) {
        return { allowed: true, message, isAdmin: false };
    }

    const isAdmin = await isChatAdmin(message.chat_id, userId);
    if (isAdmin) {
        return { allowed: true, message, isAdmin: true };
    }

    logger.logAccessDenied(userId, message.chat_id, 'попытка удалить чужое');
    return { allowed: false, reason: 'Вы можете удалить только своё сообщение' };
}

// =====================================================
// 👥 УЧАСТНИКИ ЧАТА
// =====================================================
async function getChatMemberIds(chatId) {
    if (!chatId) return [];

    const result = await pool.query(
        'SELECT user_id FROM chat_members WHERE chat_id = $1',
        [chatId]
    );
    return result.rows.map((r) => r.user_id);
}

async function getChatMembers(chatId) {
    if (!chatId) return [];

    const result = await pool.query(`
        SELECT 
            u.id, u.username, u.display_name, u.avatar, u.status, u.last_seen,
            cm.role, cm.joined_at
        FROM users u
        INNER JOIN chat_members cm ON cm.user_id = u.id
        WHERE cm.chat_id = $1
        ORDER BY cm.role DESC, u.display_name ASC
    `, [chatId]);

    return result.rows;
}

// =====================================================
// 🔒 ЛИЧНЫЙ ЧАТ
// =====================================================
async function canReadPrivateChat(chatId, userId) {
    const access = await checkChatAccess(chatId, userId);
    if (!access.allowed || access.chatType !== 'private') return false;

    const countResult = await pool.query(
        'SELECT COUNT(*) as cnt FROM chat_members WHERE chat_id = $1',
        [chatId]
    );
    return parseInt(countResult.rows[0].cnt, 10) === 2;
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================
module.exports = {
    checkChatAccess,
    checkWriteAccess,
    checkEditAccess,
    checkDeleteAccess,
    isChatAdmin,
    isCommanderOrHigher,
    getChatMemberIds,
    getChatMembers,
    getOtherPrivateMember,
    canReadPrivateChat,
};