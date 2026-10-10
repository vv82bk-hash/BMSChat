// =====================================================
// 📊 BMSChat — РОУТЫ ГОЛОСОВАНИЙ (PostgreSQL)
// =====================================================
// Операции над уже созданным голосованием:
//   • GET    /api/polls/:id          — получить с результатами
//   • POST   /api/polls/:id/vote     — проголосовать
//   • DELETE /api/polls/:id/vote     — убрать голос
//   • POST   /api/polls/:id/close    — закрыть (автор + админ)
//
// Создание голосования — в routes/chats.js
//   POST /api/chats/:chatId/polls
// =====================================================

const express = require('express');
const router = express.Router();

const { authMiddleware } = require('../middleware/auth');
const { checkChatAccess, isChatAdmin } = require('../utils/chatAccess');
const {
    queryWithRetry,
    loadPoll,
} = require('../utils/pollAccess');
const logger = require('../utils/logger');

// =====================================================
// 📥 GET /api/polls/:id
// =====================================================
router.get('/:id', authMiddleware, async (req, res) => {
    try {
        const pollId = parseInt(req.params.id, 10);
        if (!Number.isInteger(pollId) || pollId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID' });
        }

        const poll = await loadPoll(pollId, req.user.id);
        if (!poll) {
            return res.status(404).json({ error: 'Голосование не найдено' });
        }

        const access = await checkChatAccess(poll.chat_id, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        res.json({ poll });
    } catch (error) {
        logger.error('Ошибка загрузки голосования', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🗳️ POST /api/polls/:id/vote
// =====================================================
// Тело: { option_ids: [1] }  — массив, даже если один вариант
// =====================================================
router.post('/:id/vote', authMiddleware, async (req, res) => {
    const { pool } = require('../database/init');
    const client = await pool.connect();

    try {
        const pollId = parseInt(req.params.id, 10);
        if (!Number.isInteger(pollId) || pollId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID' });
        }

        const { option_ids } = req.body;
        if (!Array.isArray(option_ids) || option_ids.length === 0) {
            return res.status(400).json({ error: 'Выберите вариант' });
        }

        const optionIds = option_ids
            .map((id) => parseInt(id, 10))
            .filter((id) => Number.isInteger(id) && id > 0);

        if (optionIds.length === 0) {
            return res.status(400).json({ error: 'Некорректные варианты' });
        }

        const pollResult = await queryWithRetry(`
            SELECT id, chat_id, is_multiple, is_closed
            FROM polls WHERE id = $1
        `, [pollId], 'vote:poll');

        if (pollResult.rows.length === 0) {
            return res.status(404).json({ error: 'Голосование не найдено' });
        }
        const poll = pollResult.rows[0];

        if (poll.is_closed) {
            return res.status(400).json({ error: 'Голосование закрыто' });
        }

        if (!poll.is_multiple && optionIds.length > 1) {
            return res.status(400).json({
                error: 'Можно выбрать только один вариант',
            });
        }

        const access = await checkChatAccess(poll.chat_id, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        // Проверяем, что варианты принадлежат этому поллу
        const validOptions = await queryWithRetry(`
            SELECT id FROM poll_options
            WHERE poll_id = $1 AND id = ANY($2::int[])
        `, [pollId, optionIds], 'vote:validOptions');

        const validIds = validOptions.rows.map((r) => r.id);
        if (validIds.length !== optionIds.length) {
            return res.status(400).json({ error: 'Некорректный вариант' });
        }

        // Транзакция: удаляем старые голоса, добавляем новые
        await client.query('BEGIN');

        await client.query(`
            DELETE FROM poll_votes
            WHERE poll_id = $1 AND user_id = $2
        `, [pollId, req.user.id]);

        for (const optId of validIds) {
            await client.query(`
                INSERT INTO poll_votes (poll_id, option_id, user_id)
                VALUES ($1, $2, $3)
            `, [pollId, optId, req.user.id]);
        }

        await client.query('COMMIT');

        const updated = await loadPoll(pollId, req.user.id);

        const io = req.app.get('io');
        if (io) {
            io.to(`chat_${poll.chat_id}`).emit('poll_updated', {
                pollId,
                chatId: poll.chat_id,
                poll: updated,
            });
        }

        logger.info('Голос отдан', {
            pollId,
            userId: req.user.id,
            options: validIds,
        });

        res.json({ message: 'Голос учтён', poll: updated });
    } catch (error) {
        await client.query('ROLLBACK').catch(() => {});
        logger.error('Ошибка голосования', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    } finally {
        client.release();
    }
});

// =====================================================
// 🗑️ DELETE /api/polls/:id/vote
// =====================================================
router.delete('/:id/vote', authMiddleware, async (req, res) => {
    try {
        const pollId = parseInt(req.params.id, 10);
        if (!Number.isInteger(pollId) || pollId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID' });
        }

        const pollResult = await queryWithRetry(`
            SELECT id, chat_id, is_closed FROM polls WHERE id = $1
        `, [pollId], 'unvote:poll');

        if (pollResult.rows.length === 0) {
            return res.status(404).json({ error: 'Голосование не найдено' });
        }
        const poll = pollResult.rows[0];

        if (poll.is_closed) {
            return res.status(400).json({ error: 'Голосование закрыто' });
        }

        const access = await checkChatAccess(poll.chat_id, req.user.id);
        if (!access.allowed) {
            return res.status(403).json({ error: access.reason });
        }

        const delResult = await queryWithRetry(`
            DELETE FROM poll_votes
            WHERE poll_id = $1 AND user_id = $2
        `, [pollId, req.user.id], 'unvote:delete');

        if (delResult.rowCount === 0) {
            return res.status(400).json({ error: 'Вы ещё не голосовали' });
        }

        const updated = await loadPoll(pollId, req.user.id);

        const io = req.app.get('io');
        if (io) {
            io.to(`chat_${poll.chat_id}`).emit('poll_updated', {
                pollId,
                chatId: poll.chat_id,
                poll: updated,
            });
        }

        logger.info('Голос отменён', { pollId, userId: req.user.id });

        res.json({ message: 'Голос отменён', poll: updated });
    } catch (error) {
        logger.error('Ошибка отмены голоса', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🔒 POST /api/polls/:id/close
// =====================================================
router.post('/:id/close', authMiddleware, async (req, res) => {
    try {
        const pollId = parseInt(req.params.id, 10);
        if (!Number.isInteger(pollId) || pollId <= 0) {
            return res.status(400).json({ error: 'Некорректный ID' });
        }

        const pollResult = await queryWithRetry(`
            SELECT id, chat_id, created_by, is_closed
            FROM polls WHERE id = $1
        `, [pollId], 'close:poll');

        if (pollResult.rows.length === 0) {
            return res.status(404).json({ error: 'Голосование не найдено' });
        }
        const poll = pollResult.rows[0];

        if (poll.is_closed) {
            return res.status(400).json({ error: 'Уже закрыто' });
        }

        const isAuthor = poll.created_by === req.user.id;
        const isAdmin = await isChatAdmin(poll.chat_id, req.user.id);

        if (!isAuthor && !isAdmin) {
            return res.status(403).json({
                error: 'Только автор или админ чата может закрыть',
            });
        }

        await queryWithRetry(`
            UPDATE polls
            SET is_closed = TRUE, closed_at = NOW()
            WHERE id = $1
        `, [pollId], 'close:update');

        const updated = await loadPoll(pollId, req.user.id);

        const io = req.app.get('io');
        if (io) {
            io.to(`chat_${poll.chat_id}`).emit('poll_closed', {
                pollId,
                chatId: poll.chat_id,
                closedBy: req.user.id,
                poll: updated,
            });
        }

        logger.success('Голосование закрыто', {
            pollId,
            by: req.user.id,
            asAuthor: isAuthor,
        });

        res.json({ message: 'Голосование закрыто', poll: updated });
    } catch (error) {
        logger.error('Ошибка закрытия голосования', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;