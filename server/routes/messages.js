// =====================================================
// 📝 BMSChat — РОУТЫ СООБЩЕНИЙ (PostgreSQL)
// =====================================================

const express = require('express');
const router = express.Router();

const { pool } = require('../database/init');
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
// 📜 GET /api/messages/:chatId
// =====================================================
// ОПТИМИЗИРОВАНО: вместо N+1 запросов — 3 запроса.
//   1. Сообщения
//   2. Все реакции для этих сообщений
//   3. Все вложения для этих сообщений
// =====================================================
router.get('/:chatId', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.chatId, 10);
        const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);
        const before = req.query.before ? parseInt(req.query.before, 10) : null;

        const access = await checkChatAccess(chatId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // ─────────────────────────────────────────
        // 1️⃣ Сообщения
        // ─────────────────────────────────────────
        let query = `
            SELECT 
                m.id, m.chat_id, m.sender_id, m.text, m.reply_to_id,
                m.is_deleted, m.is_edited, m.created_at, m.updated_at,
                u.username, u.display_name, u.avatar
            FROM messages m
            INNER JOIN users u ON u.id = m.sender_id
            WHERE m.chat_id = $1
        `;
        const params = [chatId];

        if (before) {
            query += ` AND m.id < $${params.length + 1}`;
            params.push(before);
        }

        query += ` ORDER BY m.created_at DESC LIMIT $${params.length + 1}`;
        params.push(limit);

        const result = await pool.query(query, params);

        if (result.rows.length === 0) {
            return res.json({ messages: [], hasMore: false });
        }

        // Получаем ID всех сообщений
        const messageIds = result.rows.map((m) => m.id);

        // ─────────────────────────────────────────
        // 2️⃣ Все реакции — ОДНИМ запросом
        // ─────────────────────────────────────────
        const reactionsResult = await pool.query(`
            SELECT r.message_id, r.emoji, r.user_id, u.display_name
            FROM reactions r
            INNER JOIN users u ON u.id = r.user_id
            WHERE r.message_id = ANY($1::int[])
        `, [messageIds]);

        // Группируем реакции по message_id
        const reactionsByMessage = {};
        for (const r of reactionsResult.rows) {
            if (!reactionsByMessage[r.message_id]) {
                reactionsByMessage[r.message_id] = [];
            }
            reactionsByMessage[r.message_id].push({
                emoji: r.emoji,
                user_id: r.user_id,
                display_name: r.display_name,
            });
        }

        // ─────────────────────────────────────────
        // 3️⃣ Все вложения — ОДНИМ запросом
        // ─────────────────────────────────────────
        const attachmentsResult = await pool.query(`
            SELECT id, message_id, file_type, file_path, file_name,
                   file_size, mime_type, duration, width, height
            FROM attachments
            WHERE message_id = ANY($1::int[])
        `, [messageIds]);

        // Группируем вложения по message_id
        const attachmentsByMessage = {};
        for (const a of attachmentsResult.rows) {
            if (!attachmentsByMessage[a.message_id]) {
                attachmentsByMessage[a.message_id] = [];
            }
            attachmentsByMessage[a.message_id].push({
                id: a.id,
                file_type: a.file_type,
                file_path: a.file_path,
                file_name: a.file_name,
                file_size: a.file_size,
                mime_type: a.mime_type,
                duration: a.duration,
                width: a.width,
                height: a.height,
            });
        }

        // ─────────────────────────────────────────
        // 4️⃣ Собираем всё вместе
        // ─────────────────────────────────────────
        const messages = result.rows.map((m) => ({
            ...m,
            text: m.is_deleted ? null : m.text,
            reactions: reactionsByMessage[m.id] || [],
            attachments: attachmentsByMessage[m.id] || [],
        }));

        // Разворачиваем (от старых к новым)
        messages.reverse();

        res.json({
            messages,
            hasMore: result.rows.length === limit,
        });
    } catch (error) {
        logger.error('Ошибка /messages/:chatId', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 📤 POST /api/messages/:chatId
// =====================================================
router.post('/:chatId', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.chatId, 10);
        const { text, reply_to_id } = req.body;

        const access = await checkWriteAccess(chatId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        const trimmedText = (text || '').trim();

        if (!trimmedText) {
            return res.status(400).json({ error: 'Сообщение не может быть пустым' });
        }

        if (trimmedText.length > 4000) {
            return res.status(400).json({ error: 'Сообщение слишком длинное (макс 4000 символов)' });
        }

        // Проверка reply_to_id
        if (reply_to_id) {
            const replyTo = await pool.query(`
                SELECT id, chat_id FROM messages WHERE id = $1 AND is_deleted = FALSE
            `, [reply_to_id]);

            if (replyTo.rows.length === 0 || replyTo.rows[0].chat_id !== chatId) {
                return res.status(400).json({ error: 'Сообщение для ответа не найдено' });
            }
        }

        const result = await pool.query(`
            INSERT INTO messages (chat_id, sender_id, text, reply_to_id)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        `, [chatId, req.user.id, trimmedText, reply_to_id || null]);

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

        // Socket.IO рассылка
        const io = req.app.get('io');
        if (io) {
            io.to(`chat_${chatId}`).emit('new_message', {
                ...message,
                reactions: [],
                attachments: [],
            });
        }

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
// ✏️ PUT /api/messages/:id
// =====================================================
router.put('/:id', authMiddleware, async (req, res) => {
    try {
        const messageId = parseInt(req.params.id, 10);
        const { text } = req.body;

        const access = await checkEditAccess(messageId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        const trimmedText = (text || '').trim();
        if (!trimmedText) {
            return res.status(400).json({ error: 'Текст не может быть пустым' });
        }
        if (trimmedText.length > 4000) {
            return res.status(400).json({ error: 'Текст слишком длинный' });
        }

        await pool.query(`
            UPDATE messages
            SET text = $1, is_edited = TRUE, updated_at = NOW()
            WHERE id = $2
        `, [trimmedText, messageId]);

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
// 🗑️ DELETE /api/messages/:id
// =====================================================
router.delete('/:id', authMiddleware, async (req, res) => {
    try {
        const messageId = parseInt(req.params.id, 10);

        const access = await checkDeleteAccess(messageId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        await pool.query(`
            UPDATE messages
            SET is_deleted = TRUE, text = NULL, updated_at = NOW()
            WHERE id = $1
        `, [messageId]);

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
// 😀 POST /api/messages/:id/reactions
// =====================================================
router.post('/:id/reactions', authMiddleware, async (req, res) => {
    try {
        const messageId = parseInt(req.params.id, 10);
        const { emoji } = req.body;

        if (!emoji || typeof emoji !== 'string') {
            return res.status(400).json({ error: 'Emoji обязателен' });
        }

        if (emoji.length > 10) {
            return res.status(400).json({ error: 'Emoji слишком длинный' });
        }

        const messageResult = await pool.query(`
            SELECT id, chat_id, is_deleted FROM messages WHERE id = $1
        `, [messageId]);

        if (messageResult.rows.length === 0) {
            return res.status(404).json({ error: 'Сообщение не найдено' });
        }

        const message = messageResult.rows[0];

        if (message.is_deleted) {
            return res.status(400).json({ error: 'Нельзя реагировать на удалённое сообщение' });
        }

        const access = await checkChatAccess(message.chat_id, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        try {
            await pool.query(`
                INSERT INTO reactions (message_id, user_id, emoji)
                VALUES ($1, $2, $3)
            `, [messageId, req.user.id, emoji]);
        } catch (e) {
            if (e.message.includes('duplicate')) {
                return res.status(400).json({ error: 'Вы уже поставили эту реакцию' });
            }
            throw e;
        }

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
// 🗑️ DELETE /api/messages/:id/reactions/:emoji
// =====================================================
router.delete('/:id/reactions/:emoji', authMiddleware, async (req, res) => {
    try {
        const messageId = parseInt(req.params.id, 10);
        const emoji = decodeURIComponent(req.params.emoji);

        const messageResult = await pool.query(`
            SELECT id, chat_id FROM messages WHERE id = $1
        `, [messageId]);

        if (messageResult.rows.length === 0) {
            return res.status(404).json({ error: 'Сообщение не найдено' });
        }

        const message = messageResult.rows[0];

        const access = await checkChatAccess(message.chat_id, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        const result = await pool.query(`
            DELETE FROM reactions
            WHERE message_id = $1 AND user_id = $2 AND emoji = $3
        `, [messageId, req.user.id, emoji]);

        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Реакция не найдена' });
        }

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
// ✓✓ POST /api/messages/:chatId/read
// =====================================================
router.post('/:chatId/read', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.chatId, 10);
        const { messageId } = req.body;

        if (!messageId) {
            return res.status(400).json({ error: 'messageId обязателен' });
        }

        const access = await checkChatAccess(chatId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        await pool.query(`
            UPDATE chat_members
            SET last_read_message_id = $1
            WHERE chat_id = $2 AND user_id = $3
        `, [messageId, chatId, req.user.id]);

        const io = req.app.get('io');
        if (io) {
            const members = await getChatMemberIds(chatId);
            members.forEach((memberId) => {
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