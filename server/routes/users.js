// =====================================================
// 👥 BMSChat — РОУТЫ ПОЛЬЗОВАТЕЛЕЙ
// =====================================================
// Управление пользователями, ролями, подтверждением.
//
// ПРАВА:
//   • Читать список — любой авторизованный
//   • Подтверждать новичков — Командир, Admin
//   • Назначать командиров — ТОЛЬКО Admin
//   • Повышать/понижать роли — Admin (любые) и Командир (до бойца)
//
// ЛОГИКА ПОДТВЕРЖДЕНИЯ (упрощённая):
//   Регистрация → is_approved=0 → статус "ожидает"
//   Командир подтверждает → is_approved=1 + роль «Боец»
// =====================================================

const express = require('express');
const router = express.Router();

const { db } = require('../database/init');
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
 * Гарантирует, что роль с указанным именем существует.
 * Если нет — создаёт с базовыми правами.
 * 
 * @param {string} roleName
 * @returns {number} ID роли
 */
function ensureRole(roleName) {
    let role = db.prepare('SELECT id FROM roles WHERE name = ?').get(roleName);
    if (role) return role.id;

    // Создаём базовую роль
    const defaults = {
        'Новобранец': {
            description: 'Новичок на испытательном сроке',
            color: '#FED100', icon: '🆕', priority: 10,
            can_write_general: 0, can_write_private: 0, can_write_to_commander: 1,
            can_create_feed: 0, can_approve_users: 0, can_manage_roles: 0,
            can_manage_users: 0, can_assign_commanders: 0,
        },
        'Боец': {
            description: 'Полноправный боец команды',
            color: '#00843D', icon: '🪖', priority: 50,
            can_write_general: 1, can_write_private: 1, can_write_to_commander: 0,
            can_create_feed: 0, can_approve_users: 0, can_manage_roles: 0,
            can_manage_users: 0, can_assign_commanders: 0,
        },
    };

    const cfg = defaults[roleName] || {
        description: null, color: '#FED100', icon: '🎖️', priority: 0,
        can_write_general: 0, can_write_private: 0, can_write_to_commander: 0,
        can_create_feed: 0, can_approve_users: 0, can_manage_roles: 0,
        can_manage_users: 0, can_assign_commanders: 0,
    };

    const result = db.prepare(`
        INSERT INTO roles (
            name, description, color, icon, priority,
            can_write_general, can_write_private, can_write_to_commander,
            can_create_feed, can_approve_users, can_manage_roles,
            can_manage_users, can_assign_commanders,
            is_system
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    `).run(
        roleName,
        cfg.description,
        cfg.color,
        cfg.icon,
        cfg.priority,
        cfg.can_write_general,
        cfg.can_write_private,
        cfg.can_write_to_commander,
        cfg.can_create_feed,
        cfg.can_approve_users,
        cfg.can_manage_roles,
        cfg.can_manage_users,
        cfg.can_assign_commanders
    );

    logger.success(`Роль "${roleName}" создана автоматически`, {
        roleId: result.lastInsertRowid,
    });

    return result.lastInsertRowid;
}

/**
 * Назначает роль пользователю (если её нет).
 */
function assignRoleToUser(userId, roleId, assignedBy) {
    db.prepare(`
        INSERT OR IGNORE INTO user_roles (user_id, role_id, assigned_by)
        VALUES (?, ?, ?)
    `).run(userId, roleId, assignedBy);
}

/**
 * Убирает все роли пользователя.
 */
function clearUserRoles(userId) {
    db.prepare('DELETE FROM user_roles WHERE user_id = ?').run(userId);
}

// =====================================================
// 👥 GET /api/users — Список всех пользователей
// =====================================================
router.get('/', authMiddleware, (req, res) => {
    try {
        const users = db.prepare(`
            SELECT id, username, display_name, avatar, status, last_seen, is_approved
            FROM users
            ORDER BY 
                CASE status WHEN 'online' THEN 0 ELSE 1 END,
                display_name ASC
        `).all();

        // Добавляем роли
        const result = users.map(user => ({
            ...user,
            roles: getUserRoles(user.id).map(r => ({
                id: r.id,
                name: r.name,
                color: r.color,
                icon: r.icon,
                priority: r.priority,
            })),
        }));

        res.json({ users: result });
    } catch (error) {
        logger.error('Ошибка /users', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// ⏳ GET /api/users/pending/list — Неподтверждённые
// =====================================================
router.get(
    '/pending/list',
    authMiddleware,
    requirePermission('can_approve_users'),
    (req, res) => {
        try {
            const users = db.prepare(`
                SELECT id, username, display_name, created_at
                FROM users
                WHERE is_approved = 0
                ORDER BY created_at ASC
            `).all();

            res.json({ pending: users });
        } catch (error) {
            logger.error('Ошибка pending', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🎭 GET /api/users/roles/list — Список всех ролей
// =====================================================
router.get('/roles/list', authMiddleware, (req, res) => {
    try {
        const roles = db.prepare(`
            SELECT * FROM roles ORDER BY priority DESC
        `).all();

        res.json({ roles });
    } catch (error) {
        logger.error('Ошибка списка ролей', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 👤 GET /api/users/:id — Профиль
// =====================================================
router.get('/:id', authMiddleware, (req, res) => {
    try {
        const userId = parseInt(req.params.id, 10);

        const user = db.prepare(`
            SELECT id, username, display_name, avatar, status, last_seen,
                   is_approved, created_at
            FROM users WHERE id = ?
        `).get(userId);

        if (!user) {
            return res.status(404).json({ error: 'Пользователь не найден' });
        }

        const roles = getUserRoles(userId);

        res.json({
            user: {
                ...user,
                roles: roles.map(r => ({
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
// ✅ POST /api/users/:id/approve — Подтвердить (упрощённая логика)
// =====================================================
// Что делает:
//   1. is_approved = 1
//   2. Выдаёт роль «Боец» (сразу полные права)
//   3. Добавляет в общий чат
//   4. Создаёт событие в ленте
// =====================================================
router.post(
    '/:id/approve',
    authMiddleware,
    requirePermission('can_approve_users'),
    (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const user = db.prepare(`
                SELECT id, username, display_name, is_approved 
                FROM users WHERE id = ?
            `).get(userId);

            if (!user) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            if (user.is_approved) {
                return res.status(400).json({ error: 'Пользователь уже подтверждён' });
            }

            // 1. Подтверждаем
            db.prepare(`
                UPDATE users 
                SET is_approved = 1, approved_by = ? 
                WHERE id = ?
            `).run(req.user.id, userId);

            // 2. Выдаём роль «Боец» (упрощённая логика)
            const soldierRoleId = ensureRole('Боец');
            assignRoleToUser(userId, soldierRoleId, req.user.id);

            logger.success('Пользователь подтверждён', {
                userId,
                approvedBy: req.user.id,
                roleAssigned: 'Боец',
            });

            // 3. Добавляем в общий чат
            const generalChat = db.prepare(`
                SELECT id FROM chats WHERE type = 'general' LIMIT 1
            `).get();

            if (generalChat) {
                db.prepare(`
                    INSERT OR IGNORE INTO chat_members (chat_id, user_id, role)
                    VALUES (?, ?, 'member')
                `).run(generalChat.id, userId);
            }

            // 4. Событие в ленте
            db.prepare(`
                INSERT INTO feed_events (type, title, content, author_id, target_id)
                VALUES ('new_member', ?, ?, ?, ?)
            `).run(
                `🎉 Новый боец: ${user.display_name}`,
                `Добро пожаловать в команду!`,
                req.user.id,
                userId
            );

            res.json({
                message: 'Пользователь подтверждён',
                details: {
                    userId,
                    roleAssigned: 'Боец',
                    addedToGeneralChat: !!generalChat,
                },
            });
        } catch (error) {
            logger.error('Ошибка approve', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// ❌ POST /api/users/:id/reject — Отклонить
// =====================================================
router.post(
    '/:id/reject',
    authMiddleware,
    requirePermission('can_approve_users'),
    (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const user = db.prepare('SELECT id, is_approved FROM users WHERE id = ?').get(userId);

            if (!user) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            if (user.is_approved) {
                return res.status(400).json({
                    error: 'Нельзя отклонить подтверждённого пользователя',
                });
            }

            // Удаляем
            db.prepare('DELETE FROM users WHERE id = ?').run(userId);

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
// 👑 POST /api/users/:id/assign-commander — Назначить командиром
// =====================================================
// ⚠️ ТОЛЬКО ADMIN может назначать командиров.
// =====================================================
router.post(
    '/:id/assign-commander',
    authMiddleware,
    requireAdmin(),
    (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const user = db.prepare(`
                SELECT id, username, display_name, is_approved 
                FROM users WHERE id = ?
            `).get(userId);

            if (!user) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            if (!user.is_approved) {
                return res.status(400).json({
                    error: 'Нельзя назначить командиром неподтверждённого пользователя',
                });
            }

            // Проверяем, не командир ли уже
            const alreadyCommander = db.prepare(`
                SELECT 1 FROM user_roles ur
                INNER JOIN roles r ON r.id = ur.role_id
                WHERE ur.user_id = ? AND r.name = 'Командир'
                LIMIT 1
            `).get(userId);

            if (alreadyCommander) {
                return res.status(400).json({ error: 'Пользователь уже командир' });
            }

            // Выдаём роль
            const commanderRoleId = ensureRole('Командир');
            assignRoleToUser(userId, commanderRoleId, req.user.id);

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
// 🚫 POST /api/users/:id/remove-commander — Снять командира
// =====================================================
// ⚠️ ТОЛЬКО ADMIN.
// =====================================================
router.post(
    '/:id/remove-commander',
    authMiddleware,
    requireAdmin(),
    (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const user = db.prepare('SELECT id, display_name FROM users WHERE id = ?').get(userId);
            if (!user) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            // Убираем роль «Командир»
            const commanderRole = db.prepare(`SELECT id FROM roles WHERE name = 'Командир'`).get();
            if (commanderRole) {
                db.prepare(`
                    DELETE FROM user_roles WHERE user_id = ? AND role_id = ?
                `).run(userId, commanderRole.id);
            }

            // Выдаём роль «Боец», если других ролей нет
            const remainingRoles = db.prepare(`
                SELECT COUNT(*) as cnt FROM user_roles WHERE user_id = ?
            `).get(userId).cnt;

            if (remainingRoles === 0) {
                const soldierRoleId = ensureRole('Боец');
                assignRoleToUser(userId, soldierRoleId, req.user.id);
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
// 🆕 POST /api/users/:id/make-recruit — Понизить до новобранца
// =====================================================
// Может: Командир или Admin.
// =====================================================
router.post(
    '/:id/make-recruit',
    authMiddleware,
    requireAnyPermission(['can_approve_users']),
    (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);

            const user = db.prepare('SELECT id, display_name FROM users WHERE id = ?').get(userId);
            if (!user) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            // Убираем все роли и выдаём «Новобранец»
            clearUserRoles(userId);
            const recruitRoleId = ensureRole('Новобранец');
            assignRoleToUser(userId, recruitRoleId, req.user.id);

            logger.info('Пользователь понижен до новобранца', {
                userId,
                by: req.user.id,
            });

            res.json({
                message: `${user.display_name} стал новобранцем`,
            });
        } catch (error) {
            logger.error('Ошибка понижения', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🎭 POST /api/users/:id/set-role — Установить роль
// =====================================================
// ⚠️ ТОЛЬКО ADMIN.
// =====================================================
router.post(
    '/:id/set-role',
    authMiddleware,
    requireAdmin(),
    (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);
            const { roleName } = req.body;

            if (!roleName) {
                return res.status(400).json({ error: 'roleName обязателен' });
            }

            const user = db.prepare('SELECT id, display_name FROM users WHERE id = ?').get(userId);
            if (!user) {
                return res.status(404).json({ error: 'Пользователь не найден' });
            }

            // Проверяем, что роль существует
            const role = db.prepare('SELECT id, name FROM roles WHERE name = ?').get(roleName);
            if (!role) {
                return res.status(404).json({ error: `Роль "${roleName}" не найдена` });
            }

            // Убираем все роли и выдаём новую
            clearUserRoles(userId);
            assignRoleToUser(userId, role.id, req.user.id);

            logger.success('Роль установлена', {
                userId,
                roleName,
                by: req.user.id,
            });

            res.json({
                message: `Роль "${roleName}" установлена для ${user.display_name}`,
            });
        } catch (error) {
            logger.error('Ошибка установки роли', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🎭 POST /api/users/:id/roles/:roleId — Назначить роль
// =====================================================
router.post(
    '/:id/roles/:roleId',
    authMiddleware,
    requireAdmin(),
    (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);
            const roleId = parseInt(req.params.roleId, 10);

            const user = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
            if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

            const role = db.prepare('SELECT id, name FROM roles WHERE id = ?').get(roleId);
            if (!role) return res.status(404).json({ error: 'Роль не найдена' });

            assignRoleToUser(userId, roleId, req.user.id);

            logger.success('Роль назначена', {
                userId,
                roleName: role.name,
                assignedBy: req.user.id,
            });

            res.json({ message: `Роль "${role.name}" назначена` });
        } catch (error) {
            logger.error('Ошибка назначения роли', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
);

// =====================================================
// 🎭 DELETE /api/users/:id/roles/:roleId — Убрать роль
// =====================================================
router.delete(
    '/:id/roles/:roleId',
    authMiddleware,
    requireAdmin(),
    (req, res) => {
        try {
            const userId = parseInt(req.params.id, 10);
            const roleId = parseInt(req.params.roleId, 10);

            const role = db.prepare('SELECT id, name, is_system FROM roles WHERE id = ?').get(roleId);
            if (!role) {
                return res.status(404).json({ error: 'Роль не найдена' });
            }

            // Защита системных ролей
            if (role.is_system) {
                const count = db.prepare(`
                    SELECT COUNT(*) as cnt FROM user_roles WHERE role_id = ?
                `).get(roleId);

                if (count.cnt <= 1) {
                    return res.status(400).json({
                        error: `Нельзя убрать системную роль "${role.name}" у последнего пользователя`,
                    });
                }
            }

            db.prepare(`
                DELETE FROM user_roles WHERE user_id = ? AND role_id = ?
            `).run(userId, roleId);

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