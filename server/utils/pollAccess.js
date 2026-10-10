// =====================================================
// 📊 BMSChat — ДОСТУП К ГОЛОСОВАНИЯМ
// =====================================================
// Общие хелперы для роутов голосований:
//   • queryWithRetry — устойчивый к сбоям запрос
//   • loadPoll — загрузка полла с вариантами, голосами,
//     голосовавшими и подсчётом
//
// Используется в:
//   • routes/chats.js  → POST /:chatId/polls (создание)
//   • routes/polls.js  → GET/POST/DELETE /:id (операции)
// =====================================================

const { pool } = require('../database/init');
const logger = require('./logger');

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
// 📊 LIMITS
// =====================================================
const POLL_LIMITS = {
    QUESTION_MAX: 300,
    OPTION_MAX: 150,
    OPTIONS_MIN: 2,
    OPTIONS_MAX: 10,
};

// =====================================================
// 📥 ЗАГРУЗКА ПОЛЛА
// =====================================================
// Возвращает полный объект полла:
//   id, chat_id, message_id, created_by, question,
//   is_multiple, is_anonymous, is_closed, created_at, closed_at,
//   options: [{ id, text, position, votes_count, voters? }],
//   my_votes: [option_id, ...],
//   total_votes, distinct_voters
//
// Если полл не найден — возвращает null.
// =====================================================
async function loadPoll(pollId, userId) {
    // 1. Сам полл
    const pollResult = await queryWithRetry(`
        SELECT
            p.id, p.chat_id, p.message_id, p.created_by,
            p.question, p.is_multiple, p.is_anonymous,
            p.is_closed, p.created_at, p.closed_at
        FROM polls p
        WHERE p.id = $1
    `, [pollId], 'loadPoll:poll');

    if (pollResult.rows.length === 0) {
        return null;
    }

    const poll = pollResult.rows[0];

    // 2. Варианты + количество голосов за каждый
    const optionsResult = await queryWithRetry(`
        SELECT
            o.id, o.text, o.position,
            COALESCE(COUNT(v.id), 0)::int AS votes_count
        FROM poll_options o
        LEFT JOIN poll_votes v ON v.option_id = o.id
        WHERE o.poll_id = $1
        GROUP BY o.id
        ORDER BY o.position ASC, o.id ASC
    `, [pollId], 'loadPoll:options');

    // 3. Мои голоса (за какие варианты я проголосовал)
    const myVotesResult = await queryWithRetry(`
        SELECT option_id
        FROM poll_votes
        WHERE poll_id = $1 AND user_id = $2
    `, [pollId, userId], 'loadPoll:myVotes');

    const myVotes = myVotesResult.rows.map((r) => r.option_id);

    // 4. Список голосовавших — только если полл не анонимный
    let voters = [];
    if (!poll.is_anonymous) {
        const votersResult = await queryWithRetry(`
            SELECT v.option_id, v.user_id,
                   u.display_name, u.username
            FROM poll_votes v
            INNER JOIN users u ON u.id = v.user_id
            WHERE v.poll_id = $1
            ORDER BY v.created_at ASC
        `, [pollId], 'loadPoll:voters');

        voters = votersResult.rows;
    }

    // 5. Итоги
    const totalVotes = optionsResult.rows.reduce(
        (sum, o) => sum + o.votes_count,
        0
    );

    const distinctVotersResult = await queryWithRetry(`
        SELECT COUNT(DISTINCT user_id)::int AS count
        FROM poll_votes
        WHERE poll_id = $1
    `, [pollId], 'loadPoll:distinctVoters');

    const distinctVoters = distinctVotersResult.rows[0]?.count || 0;

    return {
        id: poll.id,
        chat_id: poll.chat_id,
        message_id: poll.message_id,
        created_by: poll.created_by,
        question: poll.question,
        is_multiple: poll.is_multiple,
        is_anonymous: poll.is_anonymous,
        is_closed: poll.is_closed,
        created_at: poll.created_at,
        closed_at: poll.closed_at,
        options: optionsResult.rows.map((o) => ({
            id: o.id,
            text: o.text,
            position: o.position,
            votes_count: o.votes_count,
            voters: poll.is_anonymous
                ? null
                : voters
                    .filter((v) => v.option_id === o.id)
                    .map((v) => ({
                        user_id: v.user_id,
                        display_name: v.display_name,
                        username: v.username,
                    })),
        })),
        my_votes: myVotes,
        total_votes: totalVotes,
        distinct_voters: distinctVoters,
    };
}

module.exports = {
    queryWithRetry,
    loadPoll,
    POLL_LIMITS,
};