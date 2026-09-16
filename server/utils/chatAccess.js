// =====================================================
// 🔐 BMSChat — ПРОВЕРКА ДОСТУПА К ЧАТАМ
// =====================================================
// Централизованная проверка прав доступа к чатам.
//
// ⚠️⚠️⚠️ ЭТО САМЫЙ ВАЖНЫЙ ФАЙЛ ДЛЯ ПРИВАТНОСТИ ⚠️⚠️⚠️
//
// ГЛАВНЫЕ ПРИНЦИПЫ:
//   1. Командир НЕ видит личные чаты других (если не участник)
//   2. Даже админ НЕ видит личные чаты (кроме тех, где он участник)
//   3. Новобранец пишет ТОЛЬКО командиру/админу в личку
//   4. Новобранец НЕ пишет в общий чат (только читает)
//
// СХЕМА ПРАВ:
//   can_write_general       — писать в общий чат и группы
//   can_write_private       — писать в любые личные чаты
//   can_write_to_commander  — писать лично командиру/админу (для новобранцев)
//   can_create_feed         — писать в каналы
// =====================================================

const { db } = require('../database/init');
const { getMergedPermissions, getUserRoles } = require('../middleware/roles');
const logger = require('./logger');

// =====================================================
// 🔐 ПРОВЕРКА ДОСТУПА К ЧАТУ (чтение)
// =====================================================
/**
 * Проверяет, может ли пользователь ЧИТАТЬ чат.
 * 
 * Логика:
 *   1. Чат существует?
 *   2. Чат активен?
 *   3. Пользователь в chat_members?
 * 
 * @param {number} chatId
 * @param {number} userId
 * @returns {{
 *   allowed: boolean,
 *   reason?: string,
 *   role?: string,
 *   chatType?: string
 * }}
 */
function checkChatAccess(chatId, userId) {
    // Валидация
    if (!chatId || !userId) {
        return { allowed: false, reason: 'Неверные параметры' };
    }

    // 1. Чат существует?
    const chat = db.prepare(`
        SELECT id, type, is_active
        FROM chats
        WHERE id = ?
    `).get(chatId);

    if (!chat) {
        return { allowed: false, reason: 'Чат не найден' };
    }

    if (!chat.is_active) {
        return { allowed: false, reason: 'Чат деактивирован' };
    }

    // 2. Пользователь — участник?
    const membership = db.prepare(`
        SELECT role
        FROM chat_members
        WHERE chat_id = ? AND user_id = ?
    `).get(chatId, userId);

    if (!membership) {
        logger.logAccessDenied(userId, chatId, 'не участник чата');
        return {
            allowed: false,
            reason: 'Вы не участник этого чата',
        };
    }

    // 3. Всё ок
    return {
        allowed: true,
        role: membership.role,
        chatType: chat.type,
    };
}

// =====================================================
// ✍️ ПРОВЕРКА ПРАВА ПИСАТЬ В ЧАТ
// =====================================================
/**
 * Проверяет, может ли пользователь ПИСАТЬ в чат.
 * 
 * Логика по типам:
 *   • general → can_write_general
 *   • private → can_write_to_commander (если собеседник командир)
 *             → или can_write_private
 *   • group   → can_write_general
 *   • channel → can_create_feed
 * 
 * @param {number} chatId
 * @param {number} userId
 * @returns {{allowed: boolean, reason?: string}}
 */
function checkWriteAccess(chatId, userId) {
    // 1. Сначала — может ли читать чат
    const access = checkChatAccess(chatId, userId);
    if (!access.allowed) {
        return { allowed: false, reason: access.reason };
    }

    // 2. Загружаем права пользователя
    const perms = getMergedPermissions(userId);

    // 3. Логика по типам чатов
    switch (access.chatType) {
        // ─────────────────────────────────────────
        // 📢 КАНАЛ — только can_create_feed
        // ─────────────────────────────────────────
        case 'channel': {
            if (perms.can_create_feed || perms.can_manage_roles) {
                return { allowed: true };
            }
            return {
                allowed: false,
                reason: 'В канале могут писать только админы',
            };
        }

        // ─────────────────────────────────────────
        // 💬 ОБЩИЙ ЧАТ — только can_write_general
        // ─────────────────────────────────────────
        case 'general': {
            if (perms.can_write_general) {
                return { allowed: true };
            }
            return {
                allowed: false,
                reason: 'Только чтение. Дождитесь подтверждения командира.',
            };
        }

        // ─────────────────────────────────────────
        // 👥 ГРУППА — can_write_general
        // ─────────────────────────────────────────
        case 'group': {
            if (perms.can_write_general) {
                return { allowed: true };
            }
            return {
                allowed: false,
                reason: 'У вас нет права писать в группы',
            };
        }

        // ─────────────────────────────────────────
        // 👤 ЛИЧНЫЙ ЧАТ — особая логика
        // ─────────────────────────────────────────
        case 'private': {
            // Находим собеседника
            const otherUserId = getOtherPrivateMember(chatId, userId);

            if (!otherUserId) {
                return { allowed: false, reason: 'Собеседник не найден' };
            }

            // Собеседник — командир или админ?
            const otherIsCommander = isCommanderOrHigher(otherUserId);

            // 1. Новобранец пишет командиру/админу
            if (perms.can_write_to_commander && otherIsCommander) {
                return { allowed: true };
            }

            // 2. Полные права на личные чаты
            if (perms.can_write_private) {
                return { allowed: true };
            }

            // 3. Новобранец пытается писать не командиру
            if (perms.can_write_to_commander && !otherIsCommander) {
                return {
                    allowed: false,
                    reason: 'На испытательном сроке можно писать только командиру',
                };
            }

            // 4. Вообще нет прав
            return {
                allowed: false,
                reason: 'У вас нет права писать в личные чаты',
            };
        }

        default:
            return { allowed: false, reason: 'Неизвестный тип чата' };
    }
}

// =====================================================
// 👤 ПОЛУЧЕНИЕ СОБЕСЕДНИКА В ЛИЧНОМ ЧАТЕ
// =====================================================
/**
 * Возвращает ID собеседника в личном чате.
 * 
 * @param {number} chatId
 * @param {number} userId - ID текущего пользователя
 * @returns {number|null}
 */
function getOtherPrivateMember(chatId, userId) {
    const row = db.prepare(`
        SELECT user_id
        FROM chat_members
        WHERE chat_id = ? AND user_id != ?
        LIMIT 1
    `).get(chatId, userId);

    return row ? row.user_id : null;
}

// =====================================================
// 👑 ПРОВЕРКА: ЯВЛЯЕТСЯ ЛИ ПОЛЬЗОВАТЕЛЬ КОМАНДИРОМ ИЛИ ВЫШЕ
// =====================================================
/**
 * Проверяет, является ли пользователь командиром или админом.
 * 
 * @param {number} userId
 * @returns {boolean}
 */
function isCommanderOrHigher(userId) {
    const role = db.prepare(`
        SELECT 1 FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = ? AND r.name IN ('Командир', 'Администратор')
        LIMIT 1
    `).get(userId);

    return !!role;
}

// =====================================================
// 👑 ПРОВЕРКА, ЯВЛЯЕТСЯ ЛИ ПОЛЬЗОВАТЕЛЬ АДМИНОМ ЧАТА
// =====================================================
/**
 * Проверяет, является ли пользователь админом чата
 * (в контексте конкретного чата, не глобально).
 * 
 * @param {number} chatId
 * @param {number} userId
 * @returns {boolean}
 */
function isChatAdmin(chatId, userId) {
    if (!chatId || !userId) return false;

    const row = db.prepare(`
        SELECT role
        FROM chat_members
        WHERE chat_id = ? AND user_id = ? AND role = 'admin'
    `).get(chatId, userId);

    return !!row;
}

// =====================================================
// ✏️ ПРОВЕРКА ПРАВА РЕДАКТИРОВАТЬ СООБЩЕНИЕ
// =====================================================
/**
 * Проверяет, может ли пользователь редактировать сообщение.
 * Правило: только автор может редактировать своё сообщение.
 * 
 * @param {number} messageId
 * @param {number} userId
 * @returns {{allowed: boolean, reason?: string, message?: Object}}
 */
function checkEditAccess(messageId, userId) {
    if (!messageId || !userId) {
        return { allowed: false, reason: 'Неверные параметры' };
    }

    const message = db.prepare(`
        SELECT id, sender_id, chat_id, is_deleted
        FROM messages
        WHERE id = ?
    `).get(messageId);

    if (!message) {
        return { allowed: false, reason: 'Сообщение не найдено' };
    }

    if (message.is_deleted) {
        return { allowed: false, reason: 'Сообщение удалено' };
    }

    // Только автор
    if (message.sender_id !== userId) {
        logger.logAccessDenied(userId, message.chat_id, 'попытка редактировать чужое');
        return {
            allowed: false,
            reason: 'Вы можете редактировать только свои сообщения',
        };
    }

    return { allowed: true, message };
}

// =====================================================
// 🗑️ ПРОВЕРКА ПРАВА УДАЛИТЬ СООБЩЕНИЕ
// =====================================================
/**
 * Проверяет, может ли пользователь удалить сообщение.
 * 
 * Правила:
 *   • Автор — всегда
 *   • Админ чата — любое сообщение в своём чате
 *   • Командир/Админ в личных чатах — НЕТ особых прав
 * 
 * @param {number} messageId
 * @param {number} userId
 * @returns {{allowed: boolean, reason?: string, message?: Object, isAdmin?: boolean}}
 */
function checkDeleteAccess(messageId, userId) {
    if (!messageId || !userId) {
        return { allowed: false, reason: 'Неверные параметры' };
    }

    const message = db.prepare(`
        SELECT id, sender_id, chat_id, is_deleted
        FROM messages
        WHERE id = ?
    `).get(messageId);

    if (!message) {
        return { allowed: false, reason: 'Сообщение не найдено' };
    }

    if (message.is_deleted) {
        return { allowed: false, reason: 'Сообщение уже удалено' };
    }

    // 1. Автор
    if (message.sender_id === userId) {
        return { allowed: true, message, isAdmin: false };
    }

    // 2. Админ чата
    const isAdmin = isChatAdmin(message.chat_id, userId);
    if (isAdmin) {
        return { allowed: true, message, isAdmin: true };
    }

    // 3. Отказ
    logger.logAccessDenied(userId, message.chat_id, 'попытка удалить чужое');
    return {
        allowed: false,
        reason: 'Вы можете удалить только своё сообщение',
    };
}

// =====================================================
// 👥 ПОЛУЧЕНИЕ УЧАСТНИКОВ ЧАТА
// =====================================================
/**
 * Возвращает массив ID всех участников чата.
 * 
 * @param {number} chatId
 * @returns {number[]}
 */
function getChatMemberIds(chatId) {
    if (!chatId) return [];

    return db.prepare(`
        SELECT user_id FROM chat_members WHERE chat_id = ?
    `).all(chatId).map(r => r.user_id);
}

/**
 * Возвращает массив участников чата с данными.
 * 
 * @param {number} chatId
 * @returns {Array}
 */
function getChatMembers(chatId) {
    if (!chatId) return [];

    return db.prepare(`
        SELECT 
            u.id, u.username, u.display_name, u.avatar, u.status, u.last_seen,
            cm.role, cm.joined_at
        FROM users u
        INNER JOIN chat_members cm ON cm.user_id = u.id
        WHERE cm.chat_id = ?
        ORDER BY cm.role DESC, u.display_name ASC
    `).all(chatId);
}

// =====================================================
// 🔒 ПРОВЕРКА ЧТЕНИЯ ЛИЧНОГО ЧАТА
// =====================================================
/**
 * Специальная проверка для личных чатов.
 * Только участники личного чата могут его читать.
 * 
 * @param {number} chatId
 * @param {number} userId
 * @returns {boolean}
 */
function canReadPrivateChat(chatId, userId) {
    const access = checkChatAccess(chatId, userId);

    if (!access.allowed || access.chatType !== 'private') {
        return false;
    }

    // В личном чате ровно 2 участника
    const membersCount = db.prepare(`
        SELECT COUNT(*) as cnt FROM chat_members WHERE chat_id = ?
    `).get(chatId).cnt;

    return membersCount === 2;
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================
module.exports = {
    // Основные проверки
    checkChatAccess,        // можно ли читать чат
    checkWriteAccess,       // можно ли писать в чат

    // Для редактирования/удаления
    checkEditAccess,
    checkDeleteAccess,

    // Админство
    isChatAdmin,
    isCommanderOrHigher,

    // Участники
    getChatMemberIds,
    getChatMembers,
    getOtherPrivateMember,

    // Специальное
    canReadPrivateChat,
};