// =====================================================
// 🎭 BMSChat — MIDDLEWARE ПРОВЕРКИ РОЛЕЙ
// =====================================================
// Проверяет, есть ли у пользователя нужные права.
//
// НОВАЯ СХЕМА (5 прав):
//   can_write_general       — писать в общий чат
//   can_write_private       — писать в личные чаты
//   can_write_to_commander  — писать лично командиру (для новобранцев)
//   can_manage_users        — управлять пользователями (Admin)
//   can_assign_commanders   — назначать командиров (Admin)
//
// СТАРЫЕ ПРАВА (остаются):
//   can_create_feed         — создавать события в ленте
//   can_approve_users       — подтверждать новобранцев
//   can_manage_roles        — управлять ролями
//
// ЛОГИКА:
//   Пользователь может иметь несколько ролей.
//   Права ОБЪЕДИНЯЮТСЯ (если хотя бы одна роль даёт право — разрешено).
// =====================================================

const { db } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 📋 ПОЛУЧЕНИЕ РОЛЕЙ
// =====================================================

/**
 * Загружает все роли пользователя
 * @param {number} userId
 * @returns {Array} - массив ролей (отсортирован по priority DESC)
 */
function getUserRoles(userId) {
    return db.prepare(`
        SELECT r.*
        FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = ?
        ORDER BY r.priority DESC
    `).all(userId);
}

/**
 * Возвращает объединённые права пользователя (из всех ролей).
 * 
 * Логика:
 *   Для каждого права — берём максимальное значение.
 *   Если хотя бы одна роль даёт право=1 — итог=1.
 * 
 * @param {number} userId
 * @returns {Object} - объект с 8 правами (bool)
 * 
 * @example
 *   const perms = getMergedPermissions(1);
 *   // {
 *   //   can_write_general: true,
 *   //   can_write_private: true,
 *   //   can_write_to_commander: false,
 *   //   can_create_feed: true,
 *   //   can_approve_users: true,
 *   //   can_manage_roles: true,
 *   //   can_manage_users: true,
 *   //   can_assign_commanders: true
 *   // }
 */
function getMergedPermissions(userId) {
    const roles = getUserRoles(userId);

    return {
        // Чат
        can_write_general: roles.some(r => r.can_write_general === 1),
        can_write_private: roles.some(r => r.can_write_private === 1),
        can_write_to_commander: roles.some(r => r.can_write_to_commander === 1),

        // Лента и модерация
        can_create_feed: roles.some(r => r.can_create_feed === 1),
        can_approve_users: roles.some(r => r.can_approve_users === 1),
        can_manage_roles: roles.some(r => r.can_manage_roles === 1),

        // Администрирование
        can_manage_users: roles.some(r => r.can_manage_users === 1),
        can_assign_commanders: roles.some(r => r.can_assign_commanders === 1),
    };
}

/**
 * Проверяет, есть ли у пользователя конкретное право.
 * @param {number} userId
 * @param {string} permission - имя права
 * @returns {boolean}
 */
function hasPermission(userId, permission) {
    const perms = getMergedPermissions(userId);
    return perms[permission] === true;
}

/**
 * Проверяет, есть ли у пользователя хотя бы одно из перечисленных прав.
 * @param {number} userId
 * @param {string[]} permissions
 * @returns {boolean}
 */
function hasAnyPermission(userId, permissions) {
    const perms = getMergedPermissions(userId);
    return permissions.some(p => perms[p] === true);
}

/**
 * Проверяет, есть ли у пользователя конкретная роль.
 * @param {number} userId
 * @param {string} roleName
 * @returns {boolean}
 */
function hasRole(userId, roleName) {
    const role = db.prepare(`
        SELECT 1 FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = ? AND r.name = ?
        LIMIT 1
    `).get(userId, roleName);
    
    return !!role;
}

/**
 * Проверяет, является ли пользователь администратором (техническим).
 * @param {number} userId
 * @returns {boolean}
 */
function isAdmin(userId) {
    return hasRole(userId, 'Администратор');
}

/**
 * Проверяет, является ли пользователь командиром или выше.
 * @param {number} userId
 * @returns {boolean}
 */
function isCommanderOrHigher(userId) {
    return hasRole(userId, 'Командир') || hasRole(userId, 'Администратор');
}

// =====================================================
// 🛡️ MIDDLEWARE-ФАБРИКИ
// =====================================================

/**
 * Middleware: требует конкретное право.
 * 
 * @param {string} permission - имя права
 * @returns {Function} - middleware
 * 
 * @example
 *   router.post('/feed', authMiddleware, requirePermission('can_create_feed'), ...)
 */
function requirePermission(permission) {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Не авторизован' });
        }

        const allowed = hasPermission(req.user.id, permission);

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
    };
}

/**
 * Middleware: требует хотя бы одно из прав.
 * 
 * @param {string[]} permissions
 * @returns {Function}
 * 
 * @example
 *   router.post('/chat', authMiddleware, requireAnyPermission([
 *       'can_manage_users', 'can_assign_commanders'
 *   ]), ...)
 */
function requireAnyPermission(permissions) {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Не авторизован' });
        }

        const allowed = hasAnyPermission(req.user.id, permissions);

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
    };
}

/**
 * Middleware: требует одну из указанных ролей.
 * 
 * @param {...string} roleNames
 * @returns {Function}
 * 
 * @example
 *   router.post('/users/:id/assign-commander', 
 *       authMiddleware, 
 *       requireRole('Администратор'), 
 *       ...)
 */
function requireRole(...roleNames) {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Не авторизован' });
        }

        const userRoles = getUserRoles(req.user.id).map(r => r.name);
        const hasRequiredRole = roleNames.some(name => userRoles.includes(name));

        if (!hasRequiredRole) {
            logger.warn('Отказано в доступе (role)', {
                userId: req.user.id,
                requiredRoles: roleNames,
                userRoles,
                path: req.path,
            });
            return res.status(403).json({
                error: 'Недостаточно прав',
                message: `Требуется одна из ролей: ${roleNames.join(', ')}`,
            });
        }

        next();
    };
}

/**
 * Middleware: требует статус администратора (технического).
 */
function requireAdmin() {
    return requireRole('Администратор');
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================

module.exports = {
    // Функции
    getUserRoles,
    getMergedPermissions,
    hasPermission,
    hasAnyPermission,
    hasRole,
    isAdmin,
    isCommanderOrHigher,

    // Middleware-фабрики
    requirePermission,
    requireAnyPermission,
    requireRole,
    requireAdmin,
};