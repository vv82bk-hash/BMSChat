// =====================================================
// 💬 BMSChat — РОУТЫ ЧАТОВ (PostgreSQL)
// =====================================================

const express = require('express');
const router = express.Router();

const { pool } = require('../database/init');
const { authMiddleware } = require('../middleware/auth');
const { checkChatAccess, isChatAdmin, getChatMembers } = require('../utils/chatAccess');
const logger = require('../utils/logger');

// =====================================================
// 📋 GET /api/chats
// =====================================================
// Для личных чатов возвращаем display_name собеседника
// =====================================================
router.get('/', authMiddleware, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                c.id, c.type, c.name, c.description, c.avatar,
                c.created_at, c.updated_at,
                cm.role as my_role,
                (SELECT COUNT(*)::int FROM chat_members WHERE chat_id = c.id) as members_count,
                (SELECT id FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_id,
                (SELECT text FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_text,
                (SELECT created_at FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_at,
                CASE 
                    WHEN c.type = 'private' THEN (
                        SELECT u.display_name 
                        FROM chat_members cm2
                        INNER JOIN users u ON u.id = cm2.user_id
                        WHERE cm2.chat_id = c.id 
                          AND cm2.user_id != $1
                        LIMIT 1
                    )
                    ELSE c.name
                END as display_name
            FROM chats c
            INNER JOIN chat_members cm ON cm.chat_id = c.id
            WHERE cm.user_id = $1 AND c.is_active = TRUE
            ORDER BY 
                COALESCE(
                    (SELECT created_at FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1),
                    c.created_at
                ) DESC
        `, [req.user.id]);

        res.json({ chats: result.rows });
    } catch (error) {
        logger.error('Ошибка /chats', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ➕ POST /api/chats
// =====================================================
router.post('/', authMiddleware, async (req, res) => {
    try {
        const { type, name, description, members } = req.body;

        if (!['group', 'channel'].includes(type)) {
            return res.status(400).json({ error: 'Можно создавать только group или channel' });
        }

        if (!name || name.trim().length < 2) {
            return res.status(400).json({ error: 'Название чата минимум 2 символа' });
        }

        if (type === 'channel') {
            const canCreate = await pool.query(`
                SELECT 1 FROM user_roles ur
                INNER JOIN roles r ON r.id = ur.role_id
                WHERE ur.user_id = $1 AND r.can_create_feed = TRUE
                LIMIT 1
            `, [req.user.id]);

            if (canCreate.rows.length === 0) {
                return res.status(403).json({ error: 'Недостаточно прав для создания канала' });
            }
        }

        const chatResult = await pool.query(`
            INSERT INTO chats (type, name, description, created_by)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        `, [type, name.trim(), description || null, req.user.id]);

        const chatId = chatResult.rows[0].id;

        await pool.query(`
            INSERT INTO chat_members (chat_id, user_id, role)
            VALUES ($1, $2, 'admin')
        `, [chatId, req.user.id]);

        if (Array.isArray(members)) {
            for (const memberId of members) {
                if (memberId === req.user.id) continue;
                try {
                    await pool.query(`
                        INSERT INTO chat_members (chat_id, user_id, role)
                        VALUES ($1, $2, 'member')
                        ON CONFLICT DO NOTHING
                    `, [chatId, memberId]);
                } catch (e) {
                    // Пропускаем
                }
            }
        }

        logger.success('Чат создан', { chatId, type, by: req.user.id });

        res.status(201).json({
            message: 'Чат создан',
            chat: { id: chatId, type, name: name.trim(), description },
        });
    } catch (error) {
        logger.error('Ошибка создания чата', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 💬 POST /api/chats/private/:userId
// =====================================================
router.post('/private/:userId', authMiddleware, async (req, res) => {
    try {
        const otherUserId = parseInt(req.params.userId, 10);

        if (otherUserId === req.user.id) {
            return res.status(400).json({ error: 'Нельзя открыть чат с самим собой' });
        }

        const existing = await pool.query(`
            SELECT c.id FROM chats c
            INNER JOIN chat_members cm1 ON cm1.chat_id = c.id AND cm1.user_id = $1
            INNER JOIN chat_members cm2 ON cm2.chat_id = c.id AND cm2.user_id = $2
            WHERE c.type = 'private'
            LIMIT 1
        `, [req.user.id, otherUserId]);

        if (existing.rows.length > 0) {
            return res.json({ chat_id: existing.rows[0].id, existed: true });
        }

        const result = await pool.query(`
            INSERT INTO chats (type, created_by) VALUES ('private', $1)
            RETURNING id
        `, [req.user.id]);

        const chatId = result.rows[0].id;

        await pool.query(
            `INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, 'member')`,
            [chatId, req.user.id]
        );
        await pool.query(
            `INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, 'member')`,
            [chatId, otherUserId]
        );

        logger.info('Личный чат создан', {
            chatId,
            user1: req.user.id,
            user2: otherUserId,
        });

        res.status(201).json({ chat_id: chatId, existed: false });
    } catch (error) {
        logger.error('Ошибка личного чата', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 👥 GET /api/chats/:id
// =====================================================
router.get('/:id', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);

        const access = await checkChatAccess(chatId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        const chatResult = await pool.query('SELECT * FROM chats WHERE id = $1', [chatId]);
        if (chatResult.rows.length === 0) {
            return res.status(404).json({ error: 'Чат не найден' });
        }

        const members = await getChatMembers(chatId);

        res.json({
            chat: { ...chatResult.rows[0], my_role: access.role },
            members,
        });
    } catch (error) {
        logger.error('Ошибка /chats/:id', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ➕ POST /api/chats/:id/members
// =====================================================
router.post('/:id/members', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        const { userId } = req.body;

        const isAdmin = await isChatAdmin(chatId, req.user.id);
        if (!isAdmin) {
            return res.status(403).json({ error: 'Только админ чата может добавлять' });
        }

        await pool.query(`
            INSERT INTO chat_members (chat_id, user_id, role)
            VALUES ($1, $2, 'member')
            ON CONFLICT DO NOTHING
        `, [chatId, userId]);

        logger.info('Участник добавлен', { chatId, userId, by: req.user.id });

        res.json({ message: 'Участник добавлен' });
    } catch (error) {
        logger.error('Ошибка добавления участника', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🗑️ DELETE /api/chats/:id/members/:userId
// =====================================================
router.delete('/:id/members/:userId', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        const userId = parseInt(req.params.userId, 10);

        const isAdmin = await isChatAdmin(chatId, req.user.id);
        if (!isAdmin) {
            return res.status(403).json({ error: 'Только админ может убирать' });
        }

        await pool.query(
            'DELETE FROM chat_members WHERE chat_id = $1 AND user_id = $2',
            [chatId, userId]
        );

        logger.info('Участник убран', { chatId, userId, by: req.user.id });

        res.json({ message: 'Участник убран' });
    } catch (error) {
        logger.error('Ошибка удаления участника', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;