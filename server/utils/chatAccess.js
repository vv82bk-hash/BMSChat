// =====================================================
// 🔐 BMSChat — ПРОВЕРКА ДОСТУПА К ЧАТАМ (PostgreSQL)
// =====================================================
// ⚠️ Все функции — async (await в роутах обязателен!)
//
// История патчей:
//   🎯 2026-09-19 (Шаг 2):
//      • checkWriteAccess → канал: пишут все Бойцы+ (участники)
//   🎯 2026-09-19 (Шаг 3):
//      • canManageChannel — Админ/Командир системы + Создатель
//      • canManageChannelMembers — учитывает is_private
//   🎯 2026-09-21 (Оптимизация):
//      • checkChatAccess — 1 запрос вместо 2 (LEFT JOIN)
//      • isCommanderOrHigher — 1 запрос вместо 2
//   🎯 2026-09-21 (Retry + кэш):
//      • queryWithRetry — maxRetries=2 (быстрее)
//      • Кэш checkChatAccess на 30 сек (меньше запросов к БД)
//   🎯 2026-10-09 (Группы):
//      • checkWriteAccess → group: пишет ЛЮБОЙ участник
// =====================================================

const { pool } = require('../database/init');
const { getMergedPermissions } = require('../middleware/roles');
const logger = require('./logger');

// =====================================================
// 🔄 RETRY-ЛОГИКА (maxRetries=2 — быстрее)
// =====================================================
async function queryWithRetry(sql, params, context = 'query', maxRetries = 2) {
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

            const delay = 500;
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
// 🎯 КЭШ ДОСТУПА К ЧАТАМ (TTL 30 секунд)
// =====================================================
const _accessCache = new Map();
const ACCESS_TTL = 30 * 1000; // 30 секунд

/**
 * Сброс кэша доступа.
 * @param {number|null} chatId — если указан, сбросить только для этого чата
 * @param {number|null} userId — если указан, сбросить только для этого пользователя
 */
function clearAccessCache(chatId = null, userId = null) {
    if (!chatId && !userId) {
        _accessCache.clear();
        logger.info('🗑️ Весь кэш доступа сброшен');
        return;
    }

    const keysToDelete = [];
    for (const key of _accessCache.keys()) {
        const [cId, uId] = key.split('_').map(Number);
        if (chatId && uId && cId === chatId) keysToDelete.push(key);
        else if (userId && cId && uId === userId) keysToDelete.push(key);
        else if (chatId && userId && cId === chatId && uId === userId) {
            keysToDelete.push(key);
        }
    }

    for (const key of keysToDelete) {
        _accessCache.delete(key);
    }

    if (keysToDelete.length > 0) {
        logger.info(`🗑️ Сброшено ${keysToDelete.length} записей кэша доступа`);
    }
}

// =====================================================
// 🔐 ПРОВЕРКА ДОСТУПА К ЧАТУ (чтение)
// =====================================================
async function checkChatAccess(chatId, userId) {
    if (!chatId || !userId) {
        return { allowed: false, reason: 'Неверные параметры' };
    }

    // 🎯 Проверяем кэш
    const cacheKey = `${chatId}_${userId}`;
    const cached = _accessCache.get(cacheKey);
    if (cached && Date.now() - cached.cachedAt < ACCESS_TTL) {
        return cached.result;
    }

    // 🎯 ОДИН запрос: чат + роль участника
    const result = await queryWithRetry(`
        SELECT c.id, c.type, c.is_active, cm.role AS member_role
        FROM chats c
        LEFT JOIN chat_members cm ON cm.chat_id = c.id AND cm.user_id = $2
        WHERE c.id = $1
    `, [chatId, userId], 'checkChatAccess');

    let accessResult;

    if (result.rows.length === 0) {
        accessResult = { allowed: false, reason: 'Чат не найден' };
    } else {
        const chat = result.rows[0];

        if (!chat.is_active) {
            accessResult = { allowed: false, reason: 'Чат деактивирован' };
        } else if (!chat.member_role) {
            logger.logAccessDenied(userId, chatId, 'не участник чата');
            accessResult = { allowed: false, reason: 'Вы не участник этого чата' };
        } else {
            accessResult = {
                allowed: true,
                role: chat.member_role,
                chatType: chat.type,
            };
        }
    }

    // 🎯 Сохраняем в кэш
    _accessCache.set(cacheKey, {
        result: accessResult,
        cachedAt: Date.now(),
    });

    return accessResult;
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
            if (perms.can_write_general) return { allowed: true };
            return { allowed: false, reason: 'В канале могут писать только бойцы' };
        }

        case 'general': {
            if (perms.can_write_general) return { allowed: true };
            return { allowed: false, reason: 'Только чтение. Дождитесь подтверждения командира.' };
        }

        case 'group': {
            // 🎯 В группе пишет ЛЮБОЙ участник (member или admin).
            // Членство важнее глобальных прав: если пригласили — доверяем.
            if (access.role === 'admin' || access.role === 'member') {
                return { allowed: true };
            }
            return { allowed: false, reason: 'Вы не участник группы' };
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
    const result = await queryWithRetry(
        'SELECT user_id FROM chat_members WHERE chat_id = $1 AND user_id != $2 LIMIT 1',
        [chatId, userId],
        'getOtherPrivateMember'
    );
    return result.rows.length > 0 ? result.rows[0].user_id : null;
}

// =====================================================
// 👑 КОМАНДИР ИЛИ ВЫШЕ?
// =====================================================
async function isCommanderOrHigher(userId) {
    const result = await queryWithRetry(`
        SELECT 1 FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = $1 AND r.name IN ('Командир', 'Администратор')
        LIMIT 1
    `, [userId], 'isCommanderOrHigher');
    return result.rows.length > 0;
}

// =====================================================
// 🎯 ШАГ 3: УПРАВЛЕНИЕ КАНАЛОМ
// =====================================================
async function canManageChannel(chatId, userId) {
    if (!chatId || !userId) return false;

    const chatResult = await queryWithRetry(
        'SELECT created_by, type FROM chats WHERE id = $1',
        [chatId],
        'canManageChannel'
    );

    if (chatResult.rows.length === 0) return false;
    if (chatResult.rows[0].type !== 'channel') return false;

    if (chatResult.rows[0].created_by === userId) return true;

    return await isCommanderOrHigher(userId);
}

async function canManageChannelMembers(chatId, userId) {
    if (!chatId || !userId) return false;

    const chatResult = await queryWithRetry(
        'SELECT created_by, type, is_private FROM chats WHERE id = $1',
        [chatId],
        'canManageChannelMembers'
    );

    if (chatResult.rows.length === 0) return false;

    const chat = chatResult.rows[0];
    if (chat.type !== 'channel') return false;

    if (chat.created_by === userId) return true;

    if (chat.is_private === true) return false;

    return await isCommanderOrHigher(userId);
}

// =====================================================
// 👑 АДМИН ЧАТА?
// =====================================================
async function isChatAdmin(chatId, userId) {
    if (!chatId || !userId) return false;

    const result = await queryWithRetry(
        `SELECT role FROM chat_members
         WHERE chat_id = $1 AND user_id = $2 AND role = 'admin'`,
        [chatId, userId],
        'isChatAdmin'
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

    const result = await queryWithRetry(
        'SELECT id, sender_id, chat_id, is_deleted FROM messages WHERE id = $1',
        [messageId],
        'checkEditAccess'
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

    const result = await queryWithRetry(
        'SELECT id, sender_id, chat_id, is_deleted FROM messages WHERE id = $1',
        [messageId],
        'checkDeleteAccess'
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

    const result = await queryWithRetry(
        'SELECT user_id FROM chat_members WHERE chat_id = $1',
        [chatId],
        'getChatMemberIds'
    );
    return result.rows.map((r) => r.user_id);
}

async function getChatMembers(chatId) {
    if (!chatId) return [];

    const result = await queryWithRetry(`
        SELECT
            u.id, u.username, u.display_name, u.avatar, u.status, u.last_seen,
            cm.role, cm.joined_at
        FROM users u
        INNER JOIN chat_members cm ON cm.user_id = u.id
        WHERE cm.chat_id = $1
        ORDER BY cm.role DESC, u.display_name ASC
    `, [chatId], 'getChatMembers');

    return result.rows;
}

// =====================================================
// 🔒 ЛИЧНЫЙ ЧАТ
// =====================================================
async function canReadPrivateChat(chatId, userId) {
    const access = await checkChatAccess(chatId, userId);
    if (!access.allowed || access.chatType !== 'private') return false;

    const countResult = await queryWithRetry(
        'SELECT COUNT(*) as cnt FROM chat_members WHERE chat_id = $1',
        [chatId],
        'canReadPrivateChat'
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
    canManageChannel,
    canManageChannelMembers,
    getChatMemberIds,
    getChatMembers,
    getOtherPrivateMember,
    canReadPrivateChat,
    clearAccessCache,
};