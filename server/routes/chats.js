// =====================================================
// 💬 BMSChat — РОУТЫ ЧАТОВ (PostgreSQL)
// =====================================================
// История патчей:
//   🎯 2026-09-19 (Шаг 4): GET /api/chats — is_member, is_private, emoji
//   🎯 2026-09-19 (Шаг 5): POST /api/chats — isPrivate, emoji, фильтр
//   🎯 2026-09-19 (Шаг 6): PUT/DELETE/:id, join, members/bulk
//   🎯 2026-09-19: console.log для диагностики в stdout (Onreza показывает)
//                  + валидация chatId во всех :id роутах
// =====================================================

const express = require('express');
const router = express.Router();

const { pool } = require('../database/init');
const { authMiddleware } = require('../middleware/auth');
const {
    checkChatAccess,
    isChatAdmin,
    getChatMembers,
    canManageChannel,
    canManageChannelMembers,
} = require('../utils/chatAccess');
const logger = require('../utils/logger');

// =====================================================
// 📋 GET /api/chats
// =====================================================
router.get('/', authMiddleware, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                c.id, c.type, c.name, c.description, c.avatar, c.emoji,
                c.is_private,
                c.created_at, c.updated_at,
                c.created_by,
                cm.role as my_role,
                (cm.user_id IS NOT NULL) AS is_member,
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
            LEFT JOIN chat_members cm ON cm.chat_id = c.id AND cm.user_id = $1
            WHERE c.is_active = TRUE
              AND (
                  cm.user_id IS NOT NULL
                  OR
                  (
                      c.type = 'channel'
                      AND c.is_private = FALSE
                      AND EXISTS (
                          SELECT 1 FROM user_roles ur
                          INNER JOIN roles r ON r.id = ur.role_id
                          WHERE ur.user_id = $1
                            AND r.name IN ('Боец', 'Командир', 'Администратор')
                      )
                  )
                  OR
                  (
                      c.type = 'channel'
                      AND c.is_private = TRUE
                      AND EXISTS (
                          SELECT 1 FROM user_roles ur
                          INNER JOIN roles r ON r.id = ur.role_id
                          WHERE ur.user_id = $1
                            AND r.name = 'Администратор'
                      )
                  )
              )
            ORDER BY 
                COALESCE(
                    (SELECT created_at FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1),
                    c.created_at
                ) DESC
        `, [req.user.id]);

        res.json({ chats: result.rows });
    } catch (error) {
        console.log('🔴 GET /api/chats ERROR:', error.message);
        console.log('STACK:', error.stack);
        logger.error('Ошибка /chats', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ➕ POST /api/chats
// =====================================================
router.post('/', authMiddleware, async (req, res) => {
    try {
        const {
            type,
            name,
            description,
            isPrivate = false,
            emoji = null,
            members = [],
        } = req.body;

        if (!['group', 'channel'].includes(type)) {
            return res.status(400).json({ error: 'Можно создавать только group или channel' });
        }

        if (!name || name.trim().length < 2) {
            return res.status(400).json({ error: 'Название чата минимум 2 символа' });
        }

        if (name.trim().length > 100) {
            return res.status(400).json({ error: 'Название чата максимум 100 символов' });
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
            INSERT INTO chats (type, name, description, created_by, is_private, emoji)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING id
        `, [
            type,
            name.trim(),
            description || null,
            req.user.id,
            type === 'channel' ? Boolean(isPrivate) : false,
            type === 'channel' ? emoji : null,
        ]);

        const chatId = chatResult.rows[0].id;

        await pool.query(`
            INSERT INTO chat_members (chat_id, user_id, role)
            VALUES ($1, $2, 'admin')
        `, [chatId, req.user.id]);

        if (Array.isArray(members) && members.length > 0) {
            const validMembersResult = await pool.query(`
                SELECT DISTINCT u.id
                FROM users u
                INNER JOIN user_roles ur ON ur.user_id = u.id
                INNER JOIN roles r ON r.id = ur.role_id
                WHERE u.id = ANY($1::int[])
                  AND u.is_approved = TRUE
                  AND r.name IN ('Боец', 'Командир', 'Администратор')
            `, [members]);

            const validMemberIds = validMembersResult.rows
                .map((r) => r.id)
                .filter((id) => id !== req.user.id);

            for (const memberId of validMemberIds) {
                try {
                    await pool.query(`
                        INSERT INTO chat_members (chat_id, user_id, role)
                        VALUES ($1, $2, 'member')
                        ON CONFLICT DO NOTHING
                    `, [chatId, memberId]);
                } catch (e) {
                    logger.warn('Не удалось добавить участника', {
                        chatId,
                        memberId,
                        error: e.message,
                    });
                }
            }
        }

        logger.success('Чат создан', {
            chatId,
            type,
            isPrivate: type === 'channel' ? Boolean(isPrivate) : false,
            emoji: type === 'channel' ? emoji : null,
            by: req.user.id,
        });

        res.status(201).json({
            message: 'Чат создан',
            chat: {
                id: chatId,
                type,
                name: name.trim(),
                description: description || null,
                is_private: type === 'channel' ? Boolean(isPrivate) : false,
                emoji: type === 'channel' ? emoji : null,
            },
        });
    } catch (error) {
        console.log('🔴 POST /api/chats ERROR:', error.message);
        console.log('STACK:', error.stack);
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
        if (!Number.isInteger(otherUserId) || otherUserId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID пользователя' });
        }

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
        console.log('🔴 POST /api/chats/private ERROR:', error.message);
        console.log('STACK:', error.stack);
        logger.error('Ошибка личного чата', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🚪 POST /api/chats/:id/join
// =====================================================
router.post('/:id/join', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        if (!Number.isInteger(chatId) || chatId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID чата' });
        }

        const chatResult = await pool.query(`
            SELECT id, type, is_private, is_active 
            FROM chats WHERE id = $1
        `, [chatId]);

        if (chatResult.rows.length === 0) {
            return res.status(404).json({ error: 'Чат не найден' });
        }

        const chat = chatResult.rows[0];

        if (!chat.is_active) {
            return res.status(400).json({ error: 'Чат деактивирован' });
        }

        if (chat.type !== 'channel') {
            return res.status(400).json({ error: 'Вступить можно только в канал' });
        }

        if (chat.is_private === true) {
            return res.status(403).json({
                error: 'Это приватный канал — вступить нельзя, только по приглашению',
            });
        }

        const roleCheck = await pool.query(`
            SELECT 1 FROM user_roles ur
            INNER JOIN roles r ON r.id = ur.role_id
            WHERE ur.user_id = $1
              AND r.name IN ('Боец', 'Командир', 'Администратор')
            LIMIT 1
        `, [req.user.id]);

        if (roleCheck.rows.length === 0) {
            return res.status(403).json({
                error: 'Только бойцы могут вступать в каналы',
            });
        }

        const memberCheck = await pool.query(`
            SELECT 1 FROM chat_members 
            WHERE chat_id = $1 AND user_id = $2
        `, [chatId, req.user.id]);

        if (memberCheck.rows.length > 0) {
            return res.status(400).json({ error: 'Вы уже участник канала' });
        }

        await pool.query(`
            INSERT INTO chat_members (chat_id, user_id, role)
            VALUES ($1, $2, 'member')
        `, [chatId, req.user.id]);

        logger.success('Пользователь вступил в канал', {
            chatId,
            userId: req.user.id,
        });

        res.json({ message: 'Вы вступили в канал' });
    } catch (error) {
        console.log('🔴 POST /api/chats/:id/join ERROR:', error.message);
        console.log('STACK:', error.stack);
        logger.error('Ошибка вступления в канал', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 👥 POST /api/chats/:id/members/bulk
// =====================================================
router.post('/:id/members/bulk', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        if (!Number.isInteger(chatId) || chatId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID чата' });
        }

        const { userIds } = req.body;

        if (!Array.isArray(userIds)) {
            return res.status(400).json({ error: 'userIds должен быть массивом' });
        }

        const canManage = await canManageChannelMembers(chatId, req.user.id);
        if (!canManage) {
            return res.status(403).json({
                error: 'Только создатель канала (или админ/командир в публичном) может управлять участниками',
            });
        }

        const chatCheck = await pool.query(
            'SELECT type FROM chats WHERE id = $1',
            [chatId]
        );

        if (chatCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Чат не найден' });
        }

        if (chatCheck.rows[0].type !== 'channel') {
            return res.status(400).json({ error: 'Массовое управление — только для каналов' });
        }

        const validMembersResult = await pool.query(`
            SELECT DISTINCT u.id
            FROM users u
            INNER JOIN user_roles ur ON ur.user_id = u.id
            INNER JOIN roles r ON r.id = ur.role_id
            WHERE u.id = ANY($1::int[])
              AND u.is_approved = TRUE
              AND r.name IN ('Боец', 'Командир', 'Администратор')
        `, [userIds]);

        const validMemberIds = validMembersResult.rows.map((r) => r.id);

        let added = 0;
        for (const memberId of validMemberIds) {
            try {
                const r = await pool.query(`
                    INSERT INTO chat_members (chat_id, user_id, role)
                    VALUES ($1, $2, 'member')
                    ON CONFLICT DO NOTHING
                `, [chatId, memberId]);
                if (r.rowCount > 0) added++;
            } catch (e) {
                logger.warn('Не удалось добавить', {
                    chatId, memberId, error: e.message,
                });
            }
        }

        logger.success('Массовое добавление участников', {
            chatId, by: req.user.id,
            requested: userIds.length,
            valid: validMemberIds.length,
            added,
        });

        res.json({
            message: 'Участники добавлены',
            added,
            filtered: userIds.length - validMemberIds.length,
        });
    } catch (error) {
        console.log('🔴 POST /api/chats/:id/members/bulk ERROR:', error.message);
        console.log('STACK:', error.stack);
        logger.error('Ошибка массового добавления', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ✏️ PUT /api/chats/:id — редактирование канала
// =====================================================
// 🎯 ДИАГНОСТИКА: console.log в stdout (Onreza показывает)
router.put('/:id', authMiddleware, async (req, res) => {
    try {
        // 🎯 Валидация chatId
        const chatId = parseInt(req.params.id, 10);
        if (!Number.isInteger(chatId) || chatId <= 0) {
            console.log('⚠️ PUT /api/chats: некорректный chatId:', req.params.id);
            return res.status(400).json({ error: 'Некорректный ID чата' });
        }

        console.log('🔵 PUT /api/chats/' + chatId);
        console.log('  userId:', req.user?.id);
        console.log('  body:', JSON.stringify(req.body));

        const { name, description, emoji, isPrivate } = req.body;

        // 1. Проверка прав
        const canManage = await canManageChannel(chatId, req.user.id);
        console.log('  canManage:', canManage);

        if (!canManage) {
            return res.status(403).json({
                error: 'Только создатель, админ или командир может редактировать канал',
            });
        }

        // 2. Проверка типа
        const chatCheck = await pool.query(
            'SELECT type FROM chats WHERE id = $1',
            [chatId]
        );
        if (chatCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Чат не найден' });
        }
        if (chatCheck.rows[0].type !== 'channel') {
            return res.status(400).json({ error: 'Редактирование доступно только для каналов' });
        }

        // 3. Валидация
        if (name !== undefined) {
            if (!name || name.trim().length < 2) {
                return res.status(400).json({ error: 'Название минимум 2 символа' });
            }
            if (name.trim().length > 100) {
                return res.status(400).json({ error: 'Название максимум 100 символов' });
            }
        }

        // 4. Собираем UPDATE динамически
        const updates = [];
        const values = [];
        let idx = 1;

        if (name !== undefined) {
            updates.push(`name = $${idx++}`);
            values.push(name.trim());
        }
        if (description !== undefined) {
            updates.push(`description = $${idx++}`);
            values.push(description || null);
        }
        if (emoji !== undefined) {
            updates.push(`emoji = $${idx++}`);
            values.push(emoji);
        }
        if (isPrivate !== undefined) {
            updates.push(`is_private = $${idx++}`);
            values.push(Boolean(isPrivate));
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'Нет полей для обновления' });
        }

        updates.push(`updated_at = NOW()`);
        values.push(chatId);

        console.log('  SQL:', `UPDATE chats SET ${updates.join(', ')} WHERE id = $${idx}`);
        console.log('  values:', JSON.stringify(values));

        await pool.query(`
            UPDATE chats SET ${updates.join(', ')}
            WHERE id = $${idx}
        `, values);

        logger.success('Канал отредактирован', {
            chatId,
            fields: Object.keys({ name, description, emoji, isPrivate })
                .filter((k) => req.body[k] !== undefined),
            by: req.user.id,
        });

        res.json({ message: 'Канал обновлён' });
    } catch (error) {
        // 🎯 ДИАГНОСТИКА в stdout — Onreza покажет в runtime-логах
        console.log('🔴 PUT /api/chats ERROR');
        console.log('  chatId:', req.params.id);
        console.log('  userId:', req.user?.id);
        console.log('  body:', JSON.stringify(req.body));
        console.log('  message:', error.message);
        console.log('  code:', error.code);
        console.log('  detail:', error.detail);
        console.log('  stack:', error.stack);

        logger.error('Ошибка редактирования канала', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🗑️ DELETE /api/chats/:id — удаление канала (soft)
// =====================================================
// 🎯 ДИАГНОСТИКА: console.log в stdout
router.delete('/:id', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        if (!Number.isInteger(chatId) || chatId <= 0) {
            console.log('⚠️ DELETE /api/chats: некорректный chatId:', req.params.id);
            return res.status(400).json({ error: 'Некорректный ID чата' });
        }

        console.log('🔵 DELETE /api/chats/' + chatId);
        console.log('  userId:', req.user?.id);

        const canManage = await canManageChannel(chatId, req.user.id);
        console.log('  canManage:', canManage);

        if (!canManage) {
            return res.status(403).json({
                error: 'Только создатель, админ или командир может удалить канал',
            });
        }

        const chatCheck = await pool.query(
            'SELECT type FROM chats WHERE id = $1 AND is_active = TRUE',
            [chatId]
        );
        if (chatCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Чат не найден или уже удалён' });
        }
        if (chatCheck.rows[0].type !== 'channel') {
            return res.status(400).json({ error: 'Удаление доступно только для каналов' });
        }

        await pool.query(
            'UPDATE chats SET is_active = FALSE, updated_at = NOW() WHERE id = $1',
            [chatId]
        );

        logger.success('Канал удалён', {
            chatId,
            by: req.user.id,
        });

        res.json({ message: 'Канал удалён' });
    } catch (error) {
        // 🎯 ДИАГНОСТИКА в stdout
        console.log('🔴 DELETE /api/chats ERROR');
        console.log('  chatId:', req.params.id);
        console.log('  userId:', req.user?.id);
        console.log('  message:', error.message);
        console.log('  code:', error.code);
        console.log('  detail:', error.detail);
        console.log('  stack:', error.stack);

        logger.error('Ошибка удаления канала', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 👥 GET /api/chats/:id
// =====================================================
router.get('/:id', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        if (!Number.isInteger(chatId) || chatId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID чата' });
        }

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
        console.log('🔴 GET /api/chats/:id ERROR:', error.message);
        console.log('STACK:', error.stack);
        logger.error('Ошибка /chats/:id', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ➕ POST /api/chats/:id/members — одиночное добавление
// =====================================================
router.post('/:id/members', authMiddleware, async (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        if (!Number.isInteger(chatId) || chatId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID чата' });
        }

        const { userId } = req.body;

        if (!userId) {
            return res.status(400).json({ error: 'userId обязателен' });
        }

        const canManage = await canManageChannelMembers(chatId, req.user.id);
        if (!canManage) {
            return res.status(403).json({
                error: 'Недостаточно прав для добавления участника',
            });
        }

        const validCheck = await pool.query(`
            SELECT 1 FROM users u
            INNER JOIN user_roles ur ON ur.user_id = u.id
            INNER JOIN roles r ON r.id = ur.role_id
            WHERE u.id = $1
              AND u.is_approved = TRUE
              AND r.name IN ('Боец', 'Командир', 'Администратор')
            LIMIT 1
        `, [userId]);

        if (validCheck.rows.length === 0) {
            return res.status(400).json({
                error: 'Добавлять можно только подтверждённых Бойцов+',
            });
        }

        await pool.query(`
            INSERT INTO chat_members (chat_id, user_id, role)
            VALUES ($1, $2, 'member')
            ON CONFLICT DO NOTHING
        `, [chatId, userId]);

        logger.info('Участник добавлен', { chatId, userId, by: req.user.id });

        res.json({ message: 'Участник добавлен' });
    } catch (error) {
        console.log('🔴 POST /api/chats/:id/members ERROR:', error.message);
        console.log('STACK:', error.stack);
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
        if (!Number.isInteger(chatId) || chatId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID чата' });
        }

        const userId = parseInt(req.params.userId, 10);
        if (!Number.isInteger(userId) || userId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID пользователя' });
        }

        const canManage = await canManageChannelMembers(chatId, req.user.id);
        if (!canManage) {
            return res.status(403).json({
                error: 'Недостаточно прав для удаления участника',
            });
        }

        const chatResult = await pool.query(
            'SELECT created_by FROM chats WHERE id = $1',
            [chatId]
        );
        if (chatResult.rows.length > 0 && chatResult.rows[0].created_by === userId) {
            return res.status(400).json({
                error: 'Нельзя удалить создателя канала',
            });
        }

        await pool.query(
            'DELETE FROM chat_members WHERE chat_id = $1 AND user_id = $2',
            [chatId, userId]
        );

        logger.info('Участник убран', { chatId, userId, by: req.user.id });

        res.json({ message: 'Участник убран' });
    } catch (error) {
        console.log('🔴 DELETE /api/chats/:id/members/:userId ERROR:', error.message);
        console.log('STACK:', error.stack);
        logger.error('Ошибка удаления участника', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;