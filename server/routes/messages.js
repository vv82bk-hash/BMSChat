// =====================================================
// 📝 BMSChat — РОУТЫ СООБЩЕНИЙ
// =====================================================
// История, отправка, редактирование, удаление, реакции.
//
// БЕЗОПАСНОСТЬ:
//   • Все роуты требуют JWT
//   • Проверка chat_members через checkChatAccess()
//   • Редактирование — только автор
//   • Удаление — автор ИЛИ админ чата
//   • Командир НЕ видит личные чаты (не участник)
//
// ПАГИНАЦИЯ:
//   GET /:chatId?limit=50&before=<messageId>
// =====================================================

const express = require('express');
const router = express.Router();

const { db } = require('../database/init');
const { authMiddleware } = require('../middleware/auth');
const {
    checkChatAccess,
    checkWriteAccess,
    checkEditAccess,
    checkDeleteAccess,
    getChatMemberIds,
} = require('../utils/chatAccess');
const logger = require('../utils/logger');

// =====================================================
// 📜 GET /api/messages/:chatId — История сообщений
// =====================================================
// Query-параметры:
//   • limit  — количество (по умолчанию 50, макс 100)
//   • before — ID сообщения (для пагинации вверх)
//
// Возвращает сообщения в порядке от старых к новым.
// =====================================================
router.get('/:chatId', authMiddleware, (req, res) => {
    try {
        const chatId = parseInt(req.params.chatId, 10);
        const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);
        const before = req.query.before ? parseInt(req.query.before, 10) : null;

        // ============================================
        // 1. ПРОВЕРКА ДОСТУПА К ЧАТУ
        // ============================================
        const access = checkChatAccess(chatId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // ============================================
        // 2. ЗАГРУЖАЕМ СООБЩЕНИЯ
        // ============================================
        let query = `
            SELECT 
                m.id, m.chat_id, m.sender_id, m.text, m.reply_to_id,
                m.is_deleted, m.is_edited, m.created_at, m.updated_at,
                u.username, u.display_name, u.avatar
            FROM messages m
            INNER JOIN users u ON u.id = m.sender_id
            WHERE m.chat_id = ?
        `;
        const params = [chatId];

        // Пагинация: загружаем сообщения до указанного ID
        if (before) {
            query += ` AND m.id < ?`;
            params.push(before);
        }

        query += ` ORDER BY m.created_at DESC LIMIT ?`;
        params.push(limit);

        const messages = db.prepare(query).all(...params);

        // ============================================
        // 3. ЗАГРУЖАЕМ РЕАКЦИИ И ВЛОЖЕНИЯ
        // ============================================
        const result = messages.map(m => {
            // Реакции на сообщение
            const reactions = db.prepare(`
                SELECT r.emoji, r.user_id, u.display_name
                FROM reactions r
                INNER JOIN users u ON u.id = r.user_id
                WHERE r.message_id = ?
            `).all(m.id);

            // Вложения (фото, голосовые)
            const attachments = db.prepare(`
                SELECT id, file_type, file_path, file_name, file_size,
                       mime_type, duration, width, height
                FROM attachments
                WHERE message_id = ?
            `).all(m.id);

            return {
                ...m,
                is_deleted: !!m.is_deleted,
                is_edited: !!m.is_edited,
                // Скрываем текст, если удалено
                text: m.is_deleted ? null : m.text,
                reactions,
                attachments,
            };
        });

        // Разворачиваем — чтобы было от старых к новым
        result.reverse();

        res.json({
            messages: result,
            hasMore: messages.length === limit,
        });

    } catch (error) {
        logger.error('Ошибка /messages/:chatId', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 📤 POST /api/messages/:chatId — Отправить (REST fallback)
// =====================================================
// Используется как fallback, если WebSocket недоступен.
// Основной путь отправки — Socket.IO (`send_message`).
// =====================================================
router.post('/:chatId', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.chatId, 10);
        const { text, reply_to_id } = req.body;

        // ============================================
        // 1. ПРОВЕРКА ПРАВА ПИСАТЬ
        // ============================================
        const access = checkWriteAccess(chatId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // ============================================
        // 2. ВАЛИДАЦИЯ ТЕКСТА
        // ============================================
        const trimmedText = (text || '').trim();

        if (!trimmedText) {
            return res.status(400).json({ error: 'Сообщение не может быть пустым' });
        }

        if (trimmedText.length > 4000) {
            return res.status(400).json({ error: 'Сообщение слишком длинное (макс 4000 символов)' });
        }

        // ============================================
        // 3. ПРОВЕРКА reply_to_id
        // ============================================
        if (reply_to_id) {
            const replyTo = db.prepare(`
                SELECT id, chat_id FROM messages WHERE id = ? AND is_deleted = 0
            `).get(reply_to_id);

            if (!replyTo || replyTo.chat_id !== chatId) {
                return res.status(400).json({ error: 'Сообщение для ответа не найдено' });
            }
        }

        // ============================================
        // 4. СОХРАНЯЕМ СООБЩЕНИЕ
        // ============================================
        const result = db.prepare(`
            INSERT INTO messages (chat_id, sender_id, text, reply_to_id)
            VALUES (?, ?, ?, ?)
        `).run(chatId, req.user.id, trimmedText, reply_to_id || null);

        const messageId = result.lastInsertRowid;

        // ============================================
        // 5. ЗАГРУЖАЕМ ПОЛНОЕ СООБЩЕНИЕ
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
        // 6. РАССЫЛАЕМ ЧЕРЕЗ SOCKET.IO
        // ============================================
        const io = req.app.get('io');
        if (io) {
            io.to(`chat_${chatId}`).emit('new_message', {
                ...message,
                is_deleted: false,
                is_edited: false,
                reactions: [],
                attachments: [],
            });
        }

        // Безопасное логирование (без текста)
        logger.logMessage(req.user.id, chatId, trimmedText.length);

        res.status(201).json({
            message: 'Сообщение отправлено',
            data: message,
        });

    } catch (error) {
        logger.error('Ошибка отправки', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ✏️ PUT /api/messages/:id — Редактировать
// =====================================================
router.put('/:id', authMiddleware, (req, res) => {
    try {
        const messageId = parseInt(req.params.id, 10);
        const { text } = req.body;

        // ============================================
        // 1. ПРОВЕРКА ПРАВА РЕДАКТИРОВАТЬ
        // ============================================
        // Только автор может редактировать своё сообщение.
        const access = checkEditAccess(messageId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // ============================================
        // 2. ВАЛИДАЦИЯ
        // ============================================
        const trimmedText = (text || '').trim();
        if (!trimmedText) {
            return res.status(400).json({ error: 'Текст не может быть пустым' });
        }
        if (trimmedText.length > 4000) {
            return res.status(400).json({ error: 'Текст слишком длинный' });
        }

        // ============================================
        // 3. ОБНОВЛЯЕМ
        // ============================================
        db.prepare(`
            UPDATE messages
            SET text = ?, is_edited = 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        `).run(trimmedText, messageId);

        // ============================================
        // 4. РАССЫЛАЕМ ЧЕРЕЗ SOCKET.IO
        // ============================================
        const io = req.app.get('io');
        const chatId = access.message.chat_id;
        if (io) {
            io.to(`chat_${chatId}`).emit('message_edited', {
                messageId,
                chatId,
                text: trimmedText,
                is_edited: true,
                updated_at: new Date().toISOString(),
            });
        }

        logger.info('Сообщение отредактировано', {
            messageId,
            userId: req.user.id,
            chatId,
        });

        res.json({ message: 'Сообщение обновлено' });

    } catch (error) {
        logger.error('Ошибка редактирования', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🗑️ DELETE /api/messages/:id — Удалить (мягко)
// =====================================================
// Мягкое удаление — текст заменяется на NULL,
// но запись остаётся (для истории и аудита).
// =====================================================
router.delete('/:id', authMiddleware, (req, res) => {
    try {
        const messageId = parseInt(req.params.id, 10);

        // ============================================
        // 1. ПРОВЕРКА ПРАВА УДАЛИТЬ
        // ============================================
        // Автор ИЛИ админ чата (в групповых).
        // Командир НЕ имеет доп. прав в личных чатах.
        const access = checkDeleteAccess(messageId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // ============================================
        // 2. МЯГКОЕ УДАЛЕНИЕ
        // ============================================
        db.prepare(`
            UPDATE messages
            SET is_deleted = 1, text = NULL, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        `).run(messageId);

        // ============================================
        // 3. РАССЫЛАЕМ ЧЕРЕЗ SOCKET.IO
        // ============================================
        const io = req.app.get('io');
        const chatId = access.message.chat_id;
        if (io) {
            io.to(`chat_${chatId}`).emit('message_deleted', {
                messageId,
                chatId,
                deletedBy: req.user.id,
                isAdmin: access.isAdmin,
            });
        }

        logger.info('Сообщение удалено', {
            messageId,
            userId: req.user.id,
            chatId,
            asAdmin: access.isAdmin,
        });

        res.json({ message: 'Сообщение удалено' });

    } catch (error) {
        logger.error('Ошибка удаления', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 😀 POST /api/messages/:id/reactions — Поставить реакцию
// =====================================================
router.post('/:id/reactions', authMiddleware, (req, res) => {
    try {
        const messageId = parseInt(req.params.id, 10);
        const { emoji } = req.body;

        // ============================================
        // 1. ВАЛИДАЦИЯ EMOJI
        // ============================================
        if (!emoji || typeof emoji !== 'string') {
            return res.status(400).json({ error: 'Emoji обязателен' });
        }

        if (emoji.length > 10) {
            return res.status(400).json({ error: 'Emoji слишком длинный' });
        }

        // ============================================
        // 2. ЗАГРУЖАЕМ СООБЩЕНИЕ
        // ============================================
        const message = db.prepare(`
            SELECT id, chat_id, is_deleted FROM messages WHERE id = ?
        `).get(messageId);

        if (!message) {
            return res.status(404).json({ error: 'Сообщение не найдено' });
        }

        if (message.is_deleted) {
            return res.status(400).json({ error: 'Нельзя реагировать на удалённое сообщение' });
        }

        // ============================================
        // 3. ПРОВЕРКА ДОСТУПА К ЧАТУ
        // ============================================
        const access = checkChatAccess(message.chat_id, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // ============================================
        // 4. ДОБАВЛЯЕМ РЕАКЦИЮ
        // ============================================
        try {
            db.prepare(`
                INSERT INTO reactions (message_id, user_id, emoji)
                VALUES (?, ?, ?)
            `).run(messageId, req.user.id, emoji);
        } catch (e) {
            // Если UNIQUE constraint — реакция уже стоит
            if (e.message.includes('UNIQUE')) {
                return res.status(400).json({ error: 'Вы уже поставили эту реакцию' });
            }
            throw e;
        }

        // ============================================
        // 5. РАССЫЛАЕМ ЧЕРЕЗ SOCKET.IO
        // ============================================
        const io = req.app.get('io');
        if (io) {
            io.to(`chat_${message.chat_id}`).emit('reaction_added', {
                messageId,
                chatId: message.chat_id,
                userId: req.user.id,
                displayName: req.user.display_name,
                emoji,
            });
        }

        logger.info('Реакция добавлена', {
            messageId,
            userId: req.user.id,
            emoji,
        });

        res.status(201).json({ message: 'Реакция добавлена' });

    } catch (error) {
        logger.error('Ошибка добавления реакции', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🗑️ DELETE /api/messages/:id/reactions/:emoji — Убрать
// =====================================================
router.delete('/:id/reactions/:emoji', authMiddleware, (req, res) => {
    try {
        const messageId = parseInt(req.params.id, 10);
        const emoji = decodeURIComponent(req.params.emoji); // декодируем URL

        // ============================================
        // 1. ЗАГРУЖАЕМ СООБЩЕНИЕ
        // ============================================
        const message = db.prepare(`
            SELECT id, chat_id FROM messages WHERE id = ?
        `).get(messageId);

        if (!message) {
            return res.status(404).json({ error: 'Сообщение не найдено' });
        }

        // ============================================
        // 2. ПРОВЕРКА ДОСТУПА
        // ============================================
        const access = checkChatAccess(message.chat_id, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // ============================================
        // 3. УДАЛЯЕМ ТОЛЬКО СВОЮ РЕАКЦИЮ
        // ============================================
        const result = db.prepare(`
            DELETE FROM reactions
            WHERE message_id = ? AND user_id = ? AND emoji = ?
        `).run(messageId, req.user.id, emoji);

        if (result.changes === 0) {
            return res.status(404).json({ error: 'Реакция не найдена' });
        }

        // ============================================
        // 4. РАССЫЛАЕМ ЧЕРЕЗ SOCKET.IO
        // ============================================
        const io = req.app.get('io');
        if (io) {
            io.to(`chat_${message.chat_id}`).emit('reaction_removed', {
                messageId,
                chatId: message.chat_id,
                userId: req.user.id,
                emoji,
            });
        }

        logger.info('Реакция убрана', {
            messageId,
            userId: req.user.id,
            emoji,
        });

        res.json({ message: 'Реакция убрана' });

    } catch (error) {
        logger.error('Ошибка удаления реакции', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ✓✓ POST /api/messages/:chatId/read — Прочитано
// =====================================================
router.post('/:chatId/read', authMiddleware, (req, res) => {
    try {
        const chatId = parseInt(req.params.chatId, 10);
        const { messageId } = req.body;

        if (!messageId) {
            return res.status(400).json({ error: 'messageId обязателен' });
        }

        // ============================================
        // 1. ПРОВЕРКА ДОСТУПА
        // ============================================
        const access = checkChatAccess(chatId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // ============================================
        // 2. ОБНОВЛЯЕМ last_read_message_id
        // ============================================
        db.prepare(`
            UPDATE chat_members
            SET last_read_message_id = ?
            WHERE chat_id = ? AND user_id = ?
        `).run(messageId, chatId, req.user.id);

        // ============================================
        // 3. УВЕДОМЛЯЕМ ОСТАЛЬНЫХ
        // ============================================
        const io = req.app.get('io');
        if (io) {
            // Всем участникам, кроме читателя
            const members = getChatMemberIds(chatId);
            members.forEach(memberId => {
                if (memberId !== req.user.id) {
                    io.to(`user_${memberId}`).emit('message_read', {
                        chatId,
                        userId: req.user.id,
                        messageId,
                    });
                }
            });
        }

        res.json({ message: 'Отмечено прочитанным' });

    } catch (error) {
        logger.error('Ошибка mark_read', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;