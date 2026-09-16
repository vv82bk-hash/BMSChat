// =====================================================
// 🎭 BMSChat — MIDDLEWARE ПРОВЕРКИ РОЛЕЙ (PostgreSQL)
// =====================================================
// ⚠️ Все функции — async (await при вызове!)
// =====================================================

const { pool } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 📋 ПОЛУЧЕНИЕ РОЛЕЙ
// =====================================================

/**
 * Загружает все роли пользователя
 */
async function getUserRoles(userId) {
    const result = await pool.query(`
        SELECT r.*
        FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = $1
        ORDER BY r.priority DESC
    `, [userId]);

    return result.rows;
}

/**
 * Возвращает объединённые права пользователя (8 штук)
 */
async function getMergedPermissions(userId) {
    const roles = await getUserRoles(userId);

    return {
        can_write_general: roles.some((r) => r.can_write_general),
        can_write_private: roles.some((r) => r.can_write_private),
        can_write_to_commander: roles.some((r) => r.can_write_to_commander),
        can_create_feed: roles.some((r) => r.can_create_feed),
        can_approve_users: roles.some((r) => r.can_approve_users),
        can_manage_roles: roles.some((r) => r.can_manage_roles),
        can_manage_users: roles.some((r) => r.can_manage_users),
        can_assign_commanders: roles.some((r) => r.can_assign_commanders),
    };
}

/**
 * Проверяет конкретное право
 */
async function hasPermission(userId, permission) {
    const perms = await getMergedPermissions(userId);
    return perms[permission] === true;
}

/**
 * Проверяет хотя бы одно право
 */
async function hasAnyPermission(userId, permissions) {
    const perms = await getMergedPermissions(userId);
    return permissions.some((p) => perms[p] === true);
}

/**
 * Есть ли роль?
 */
async function hasRole(userId, roleName) {
    const result = await pool.query(`
        SELECT 1 FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = $1 AND r.name = $2
        LIMIT 1
    `, [userId, roleName]);

    return result.rows.length > 0;
}

/**
 * Администратор?
 */
async function isAdmin(userId) {
    return await hasRole(userId, 'Администратор');
}

/**
 * Командир или выше?
 */
async function isCommanderOrHigher(userId) {
    return (await hasRole(userId, 'Командир')) || (await hasRole(userId, 'Администратор'));
}

// =====================================================
// 🛡️ MIDDLEWARE-ФАБРИКИ
// =====================================================

/**
 * Требует конкретное право
 */
function requirePermission(permission) {
    return async (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Не авторизован' });
        }

        try {
            const allowed = await hasPermission(req.user.id, permission);

            if (!allowed) {
                logger.warn('Отказано в доступе', {
                    userId: req.user.id,
                    permission,
                    path: req.path,
                });
                return res.status(403).json({
                    error: 'Недостаточно прав',
                    message: `Требуется право: ${permission}`,
                });
            }

            next();
        } catch (error) {
            logger.error('Ошибка requirePermission', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    };
}

/**
 * Требует хотя бы одно право
 */
function requireAnyPermission(permissions) {
    return async (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Не авторизован' });
        }

        try {
            const allowed = await hasAnyPermission(req.user.id, permissions);

            if (!allowed) {
                logger.warn('Отказано в доступе (any)', {
                    userId: req.user.id,
                    permissions,
                    path: req.path,
                });
                return res.status(403).json({
                    error: 'Недостаточно прав',
                    message: `Требуется одно из прав: ${permissions.join(', ')}`,
                });
            }

            next();
        } catch (error) {
            logger.error('Ошибка requireAnyPermission', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    };
}

/**
 * Требует одну из ролей
 */
function requireRole(...roleNames) {
    return async (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Не авторизован' });
        }

        try {
            const roles = await getUserRoles(req.user.id);
            const userRoleNames = roles.map((r) => r.name);
            const hasRequiredRole = roleNames.some((name) => userRoleNames.includes(name));

            if (!hasRequiredRole) {
                logger.warn('Отказано в доступе (role)', {
                    userId: req.user.id,
                    requiredRoles: roleNames,
                    userRoles: userRoleNames,
                    path: req.path,
                });
                return res.status(403).json({
                    error: 'Недостаточно прав',
                    message: `Требуется одна из ролей: ${roleNames.join(', ')}`,
                });
            }

            next();
        } catch (error) {
            logger.error('Ошибка requireRole', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    };
}

/**
 * Требует статус администратора
 */
function requireAdmin() {
    return requireRole('Администратор');
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================
module.exports = {
    getUserRoles,
    getMergedPermissions,
    hasPermission,
    hasAnyPermission,
    hasRole,
    isAdmin,
    isCommanderOrHigher,
    requirePermission,
    requireAnyPermission,
    requireRole,
    requireAdmin,
};