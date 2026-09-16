// =====================================================
// 💬 BMSChat — РОУТЫ ЧАТОВ
// =====================================================
// 4 типа чатов: private, general, group, channel
// =====================================================

const express = require('express');
const router = express.Router();

const { db } = require('../database/init');
const { authMiddleware } = require('../middleware/auth');
const { checkChatAccess, isChatAdmin, getChatMembers } = require('../utils/chatAccess');
const logger = require('../utils/logger');

// -----------------------------------------------------
// 📋 GET /api/chats — Мои чаты
// -----------------------------------------------------
router.get('/', authMiddleware, (req, res) => {
    try {
        const chats = db.prepare(`
            SELECT 
                c.id, c.type, c.name, c.description, c.avatar,
                c.created_at, c.updated_at,
                cm.role as my_role,
                (SELECT COUNT(*) FROM chat_members WHERE chat_id = c.id) as members_count,
                (SELECT id FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_id,
                (SELECT text FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_text,
                (SELECT created_at FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_at
            FROM chats c
            INNER JOIN chat_members cm ON cm.chat_id = c.id
            WHERE cm.user_id = ? AND c.is_active = 1
            ORDER BY 
                COALESCE(last_message_at, c.created_at) DESC
        `).all(req.user.id);

        res.json({ chats });
    } catch (error) {
        logger.error('Ошибка /chats', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// -----------------------------------------------------
// ➕ POST /api/chats — Создать чат
// -----------------------------------------------------
router.post('/', authMiddleware, (req, res) => {
    try {
        const { type, name, description, members } = req.body;

        if (!['group', 'channel'].includes(type)) {
            return res.status(400).json({ error: 'Можно создавать только group или channel' });
        }

        if (!name || name.trim().length < 2) {
            return res.status(400).json({ error: 'Название чата минимум 2 символа' });
        }

        // Для каналов — проверка права
        if (type === 'channel') {
            const canCreate = db.prepare(`
                SELECT 1 FROM user_roles ur
                INNER JOIN roles r ON r.id = ur.role_id
                WHERE ur.user_id = ? AND r.can_create_feed = 1
                LIMIT 1
            `).get(req.user.id);
            if (!canCreate) {
                return res.status(403).json({ error: 'Недостаточно прав для создания канала' });
            }
        }

        const chatResult = db.prepare(`
            INSERT INTO chats (type, name, description, created_by)
            VALUES (?, ?, ?, ?)
        `).run(type, name.trim(), description || null, req.user.id);

        const chatId = chatResult.lastInsertRowid;

        db.prepare(`
            INSERT INTO chat_members (chat_id, user_id, role)
            VALUES (?, ?, 'admin')
        `).run(chatId, req.user.id);

        // Добавляем остальных
        if (Array.isArray(members)) {
            for (const memberId of members) {
                if (memberId === req.user.id) continue;
                try {
                    db.prepare(`
                        INSERT OR IGNORE INTO chat_members (chat_id, user_id, role)
                        VALUES (?, ?, 'member')
                    `).run(chatId, memberId);
                } catch (e) {}
            }
        }

        logger.success('Чат создан', {
            chatId, type, by: req.user.id,
        });

        res.status(201).json({
            message: 'Чат создан',
            chat: { id: chatId, type, name: name.trim(), description },
        });
    } catch (error) {
        logger.error('Ошибка создания чата', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// -----------------------------------------------------
// 💬 POST /api/chats/private/:userId — Личный чат
// -----------------------------------------------------
router.post('/private/:userId', authMiddleware, (req, res) => {
    try {
        const otherUserId = parseInt(req.params.userId, 10);

        if (otherUserId === req.user.id) {
            return res.status(400).json({ error: 'Нельзя открыть чат с самим собой' });
        }

        // Ищем существующий личный чат
        const existing = db.prepare(`
            SELECT c.id FROM chats c
            INNER JOIN chat_members cm1 ON cm1.chat_id = c.id AND cm1.user_id = ?
            INNER JOIN chat_members cm2 ON cm2.chat_id = c.id AND cm2.user_id = ?
            WHERE c.type = 'private'
            LIMIT 1
        `).get(req.user.id, otherUserId);

        if (existing) {
            return res.json({ chat_id: existing.id, existed: true });
        }

        // Создаём новый
        const result = db.prepare(`
            INSERT INTO chats (type, created_by) VALUES ('private', ?)
        `).run(req.user.id);

        const chatId = result.lastInsertRowid;

        db.prepare(`INSERT INTO chat_members (chat_id, user_id, role) VALUES (?, ?, 'member')`)
            .run(chatId, req.user.id);
        db.prepare(`INSERT INTO chat_members (chat_id, user_id, role) VALUES (?, ?, 'member')`)
            .run(chatId, otherUserId);

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

// -----------------------------------------------------
// 👥 GET /api/chats/:id — Информация о чате
// -----------------------------------------------------
router.get('/:id', authMiddleware, (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);

        // Проверка доступа через централизованную функцию
        const access = checkChatAccess(chatId, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        const chat = db.prepare('SELECT * FROM chats WHERE id = ?').get(chatId);
        if (!chat) return res.status(404).json({ error: 'Чат не найден' });

        // Участники
        const members = getChatMembers(chatId);

        res.json({
            chat: { ...chat, my_role: access.role },
            members,
        });
    } catch (error) {
        logger.error('Ошибка /chats/:id', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// -----------------------------------------------------
// ➕ POST /api/chats/:id/members — Добавить участника
// -----------------------------------------------------
router.post('/:id/members', authMiddleware, (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        const { userId } = req.body;

        if (!isChatAdmin(chatId, req.user.id)) {
            return res.status(403).json({ error: 'Только админ чата может добавлять' });
        }

        db.prepare(`
            INSERT OR IGNORE INTO chat_members (chat_id, user_id, role)
            VALUES (?, ?, 'member')
        `).run(chatId, userId);

        logger.info('Участник добавлен', {
            chatId, userId, by: req.user.id,
        });

        res.json({ message: 'Участник добавлен' });
    } catch (error) {
        logger.error('Ошибка добавления участника', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// -----------------------------------------------------
// 🗑️ DELETE /api/chats/:id/members/:userId — Убрать
// -----------------------------------------------------
router.delete('/:id/members/:userId', authMiddleware, (req, res) => {
    try {
        const chatId = parseInt(req.params.id, 10);
        const userId = parseInt(req.params.userId, 10);

        if (!isChatAdmin(chatId, req.user.id)) {
            return res.status(403).json({ error: 'Только админ может убирать' });
        }

        db.prepare('DELETE FROM chat_members WHERE chat_id = ? AND user_id = ?')
            .run(chatId, userId);

        logger.info('Участник убран', {
            chatId, userId, by: req.user.id,
        });

        res.json({ message: 'Участник убран' });
    } catch (error) {
        logger.error('Ошибка удаления участника', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;