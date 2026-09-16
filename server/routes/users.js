// =====================================================
// 👥 BMSChat — РОУТЫ ПОЛЬЗОВАТЕЛЕЙ (PostgreSQL)
// =====================================================

const express = require('express');
const router = express.Router();

const { pool } = require('../database/init');
const { authMiddleware } = require('../middleware/auth');
const {
    requirePermission,
    requireAnyPermission,
    requireAdmin,
    requireRole,
    getUserRoles,
} = require('../middleware/roles');
const logger = require('../utils/logger');

// =====================================================
// 🛠️ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// =====================================================

/**
 * Гарантирует, что роль существует
 */
async function ensureRole(roleName) {
    const existing = await pool.query('SELECT id FROM roles WHERE name = $1', [roleName]);
    if (existing.rows.length > 0) return existing.rows[0].id;

    const defaults = {
        'Новобранец': {
            description: 'Новичок на испытательном сроке',
            color: '#FED100', icon: '🆕', priority: 10,
            can_write_general: false, can_write_private: false, can_write_to_commander: true,
            can_create_feed: false, can_approve_users: false, can_manage_roles: false,
            can_manage_users: false, can_assign_commanders: false,
        },
        'Боец': {
            description: 'Полноправный боец команды',
            color: '#00843D', icon: '🪖', priority: 50,
            can_write_general: true, can_write_private: true, can_write_to_commander: false,
            can_create_feed: false, can_approve_users: false, can_manage_roles: false,
            can_manage_users: false, can_assign_commanders: false,
        },
    };

    const cfg = defaults[roleName] || {
        description: null, color: '#FED100', icon: '🎖️', priority: 0,
        can_write_general: false, can_write_private: false, can_write_to_commander: false,
        can_create_feed: false, can_approve_users: false, can_manage_roles: false,
        can_manage_users: false, can_assign_commanders: false,
    };

    const result = await pool.query(`
        INSERT INTO roles (
            name, description, color, icon, priority,
            can_write_general, can_write_private, can_write_to_commander,
            can_create_feed, can_approve_users, can_manage_roles,
            can_manage_users, can_assign_commanders, is_system
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING id
    `, [
        roleName, cfg.description, cfg.color, cfg.icon, cfg.priority,
        cfg.can_write_general, cfg.can_write_private, cfg.can_write_to_commander,
        cfg.can_create_feed, cfg.can_approve_users, cfg.can_manage_roles,
        cfg.can_manage_users, cfg.can_assign_commanders, true,
    ]);

    logger.success(`Роль "${roleName}" создана автоматически`, {
        roleId: result.rows[0].id,
    });

    return result.rows[0].id;
}

async function assignRoleToUser(userId, roleId, assignedBy) {
    await pool.query(`
        INSERT INTO user_roles (user_id, role_id, assigned_by)
        VALUES ($1, $2, $3)
        ON CONFLICT DO NOTHING
    `, [userId, roleId, assignedBy]);
}

async function clearUserRoles(userId) {
    await pool.query('DELETE FROM user_roles WHERE user_id = $1', [userId]);
}

// =====================================================
// 👥 GET /api/users
// =====================================================
router.get('/', authMiddleware, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT id, username, display_name, avatar, status, last_seen, is_approved
            FROM users
            ORDER BY 
                CASE status WHEN 'online' THEN 0 ELSE 1 END,
                display_name ASC
        `);

        const users = await Promise.all(result.rows.map(async (user) => {
            const roles = await getUserRoles(user.id);
            return {
                ...user,
                roles: roles.map((r) => ({
                    id: r.id,
                    name: r.name,
                    color: r.color,
                    icon: r.icon,
                    priority: r.priority,
                })),
            };
        }));

        res.json({ users });
    } catch (error) {
        logger.error('Ошибка /users', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ⏳ GET /api/users/pending/list
// =====================================================
router.get(
    '/pending/list',
    authMiddleware,
    requirePermission('can_approve_users'),
    async (req, res) => {
        try {
            const result = await pool.query(`
                SELECT id, username, display_name, created_at
                FROM users
                WHERE is_approved = FALSE
                ORDER BY created_at ASC
            `);

            res.json({ pending: result.rows });
        } catch (error) {
            logger.error('Ошибка pending', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🎭 GET /api/users/roles/list
// =====================================================
router.get('/roles/list', authMiddleware, async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM roles ORDER BY priority DESC');
        res.json({ roles: result.rows });
    } catch (error) {
        logger.error('Ошибка списка ролей', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 👤 GET /api/users/:id
// =====================================================
router.get('/:id', authMiddleware, async (req, res) => {
    try {
        const userId = parseInt(req.params.id, 10);

        const result = await pool.query(`
            SELECT id, username, display_name, avatar, status, last_seen,
                   is_approved, created_at
            FROM users WHERE id = $1
        `, [userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Пользователь не найден' });
        }

        const roles = await getUserRoles(userId);

        res.json({
            user: {
                ...result.rows[0],
                roles: roles.map((r) => ({
                    id: r.id,
                    name: r.name,
                    color: r.color,
                    icon: r.icon,
                    priority: r.priority,
                })),
            },
        });
    } catch (error) {
        logger.error('Ошибка /users/:id', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ✅ POST /api/users/:id/approve
// =====================================================
router.post(
    '/:id/approve',
    authMiddleware,
    requirePermission('can_approve_users'),
    async (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const userResult = await pool.query(`
                SELECT id, username, display_name, is_approved 
                FROM users WHERE id = $1
            `, [userId]);

            if (userResult.rows.length === 0) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            const user = userResult.rows[0];

            if (user.is_approved) {
                return res.status(400).json({ error: 'Пользователь уже подтверждён' });
            }

            // Подтверждаем
            await pool.query(`
                UPDATE users 
                SET is_approved = TRUE, approved_by = $1 
                WHERE id = $2
            `, [req.user.id, userId]);

            // Роль «Боец»
            const soldierRoleId = await ensureRole('Боец');
            await assignRoleToUser(userId, soldierRoleId, req.user.id);

            logger.success('Пользователь подтверждён', {
                userId,
                approvedBy: req.user.id,
                roleAssigned: 'Боец',
            });

            // Добавляем в общий чат
            const generalChat = await pool.query(
                `SELECT id FROM chats WHERE type = 'general' LIMIT 1`
            );

            if (generalChat.rows.length > 0) {
                await pool.query(`
                    INSERT INTO chat_members (chat_id, user_id, role)
                    VALUES ($1, $2, 'member')
                    ON CONFLICT DO NOTHING
                `, [generalChat.rows[0].id, userId]);
            }

            // Событие в ленте
            await pool.query(`
                INSERT INTO feed_events (type, title, content, author_id, target_id)
                VALUES ('new_member', $1, $2, $3, $4)
            `, [
                `🎉 Новый боец: ${user.display_name}`,
                `Добро пожаловать в команду!`,
                req.user.id,
                userId,
            ]);

            res.json({
                message: 'Пользователь подтверждён',
                details: {
                    userId,
                    roleAssigned: 'Боец',
                    addedToGeneralChat: generalChat.rows.length > 0,
                },
            });
        } catch (error) {
            logger.error('Ошибка approve', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// ❌ POST /api/users/:id/reject
// =====================================================
router.post(
    '/:id/reject',
    authMiddleware,
    requirePermission('can_approve_users'),
    async (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const result = await pool.query(
                'SELECT id, is_approved FROM users WHERE id = $1',
                [userId]
            );

            if (result.rows.length === 0) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            if (result.rows[0].is_approved) {
                return res.status(400).json({
                    error: 'Нельзя отклонить подтверждённого пользователя',
                });
            }

            await pool.query('DELETE FROM users WHERE id = $1', [userId]);

            logger.info('Заявка отклонена', {
                userId,
                rejectedBy: req.user.id,
            });

            res.json({ message: 'Заявка отклонена' });
        } catch (error) {
            logger.error('Ошибка reject', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 👑 POST /api/users/:id/assign-commander
// =====================================================
router.post(
    '/:id/assign-commander',
    authMiddleware,
    requireAdmin(),
    async (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const userResult = await pool.query(`
                SELECT id, username, display_name, is_approved 
                FROM users WHERE id = $1
            `, [userId]);

            if (userResult.rows.length === 0) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            const user = userResult.rows[0];

            if (!user.is_approved) {
                return res.status(400).json({
                    error: 'Нельзя назначить командиром неподтверждённого пользователя',
                });
            }

            const alreadyCommander = await pool.query(`
                SELECT 1 FROM user_roles ur
                INNER JOIN roles r ON r.id = ur.role_id
                WHERE ur.user_id = $1 AND r.name = 'Командир'
                LIMIT 1
            `, [userId]);

            if (alreadyCommander.rows.length > 0) {
                return res.status(400).json({ error: 'Пользователь уже командир' });
            }

            const commanderRoleId = await ensureRole('Командир');
            await assignRoleToUser(userId, commanderRoleId, req.user.id);

            logger.success('Командир назначен', {
                userId,
                displayName: user.display_name,
                assignedBy: req.user.id,
            });

            res.json({
                message: `${user.display_name} назначен командиром`,
            });
        } catch (error) {
            logger.error('Ошибка назначения командира', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🚫 POST /api/users/:id/remove-commander
// =====================================================
router.post(
    '/:id/remove-commander',
    authMiddleware,
    requireAdmin(),
    async (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const userResult = await pool.query(
                'SELECT id, display_name FROM users WHERE id = $1',
                [userId]
            );

            if (userResult.rows.length === 0) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            const user = userResult.rows[0];

            // Убираем роль «Командир»
            const commanderRole = await pool.query(
                `SELECT id FROM roles WHERE name = 'Командир'`
            );

            if (commanderRole.rows.length > 0) {
                await pool.query(`
                    DELETE FROM user_roles WHERE user_id = $1 AND role_id = $2
                `, [userId, commanderRole.rows[0].id]);
            }

            // Если ролей не осталось — выдаём «Боец»
            const remaining = await pool.query(
                'SELECT COUNT(*) as cnt FROM user_roles WHERE user_id = $1',
                [userId]
            );

            if (parseInt(remaining.rows[0].cnt, 10) === 0) {
                const soldierRoleId = await ensureRole('Боец');
                await assignRoleToUser(userId, soldierRoleId, req.user.id);
            }

            logger.info('Командир снят', {
                userId,
                removedBy: req.user.id,
            });

            res.json({
                message: `${user.display_name} больше не командир`,
            });
        } catch (error) {
            logger.error('Ошибка снятия командира', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🆕 POST /api/users/:id/make-recruit
// =====================================================
router.post(
    '/:id/make-recruit',
    authMiddleware,
    requireAnyPermission(['can_approve_users']),
    async (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const userResult = await pool.query(
                'SELECT id, display_name FROM users WHERE id = $1',
                [userId]
            );

            if (userResult.rows.length === 0) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            await clearUserRoles(userId);
            const recruitRoleId = await ensureRole('Новобранец');
            await assignRoleToUser(userId, recruitRoleId, req.user.id);

            logger.info('Пользователь понижен до новобранца', {
                userId,
                by: req.user.id,
            });

            res.json({
                message: `${userResult.rows[0].display_name} стал новобранцем`,
            });
        } catch (error) {
            logger.error('Ошибка понижения', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🎭 POST /api/users/:id/set-role
// =====================================================
router.post(
    '/:id/set-role',
    authMiddleware,
    requireAdmin(),
    async (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);
            const { roleName } = req.body;

            if (!roleName) {
                return res.status(400).json({ error: 'roleName обязателен' });
            }

            const userResult = await pool.query(
                'SELECT id, display_name FROM users WHERE id = $1',
                [userId]
            );

            if (userResult.rows.length === 0) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            const roleResult = await pool.query(
                'SELECT id, name FROM roles WHERE name = $1',
                [roleName]
            );

            if (roleResult.rows.length === 0) {
                return res.status(404).json({ error: `Роль "${roleName}" не найдена` });
            }

            await clearUserRoles(userId);
            await assignRoleToUser(userId, roleResult.rows[0].id, req.user.id);

            logger.success('Роль установлена', {
                userId,
                roleName,
                by: req.user.id,
            });

            res.json({
                message: `Роль "${roleName}" установлена для ${userResult.rows[0].display_name}`,
            });
        } catch (error) {
            logger.error('Ошибка установки роли', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🎭 POST /api/users/:id/roles/:roleId
// =====================================================
router.post(
    '/:id/roles/:roleId',
    authMiddleware,
    requireAdmin(),
    async (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);
            const roleId = parseInt(req.params.roleId, 10);

            const userResult = await pool.query(
                'SELECT id FROM users WHERE id = $1',
                [userId]
            );
            if (userResult.rows.length === 0) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            const roleResult = await pool.query(
                'SELECT id, name FROM roles WHERE id = $1',
                [roleId]
            );
            if (roleResult.rows.length === 0) {
                return res.status(404).json({ error: 'Роль не найдена' });
            }

            await assignRoleToUser(userId, roleId, req.user.id);

            logger.success('Роль назначена', {
                userId,
                roleName: roleResult.rows[0].name,
                assignedBy: req.user.id,
            });

            res.json({ message: `Роль "${roleResult.rows[0].name}" назначена` });
        } catch (error) {
            logger.error('Ошибка назначения роли', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🎭 DELETE /api/users/:id/roles/:roleId
// =====================================================
router.delete(
    '/:id/roles/:roleId',
    authMiddleware,
    requireAdmin(),
    async (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);
            const roleId = parseInt(req.params.roleId, 10);

            const roleResult = await pool.query(
                'SELECT id, name, is_system FROM roles WHERE id = $1',
                [roleId]
            );

            if (roleResult.rows.length === 0) {
                return res.status(404).json({ error: 'Роль не найдена' });
            }

            const role = roleResult.rows[0];

            if (role.is_system) {
                const count = await pool.query(
                    'SELECT COUNT(*) as cnt FROM user_roles WHERE role_id = $1',
                    [roleId]
                );

                if (parseInt(count.rows[0].cnt, 10) <= 1) {
                    return res.status(400).json({
                        error: `Нельзя убрать системную роль "${role.name}" у последнего пользователя`,
                    });
                }
            }

            await pool.query(`
                DELETE FROM user_roles WHERE user_id = $1 AND role_id = $2
            `, [userId, roleId]);

            logger.info('Роль убрана', {
                userId,
                roleName: role.name,
                removedBy: req.user.id,
            });

            res.json({ message: 'Роль убрана' });
        } catch (error) {
            logger.error('Ошибка удаления роли', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

module.exports = router;