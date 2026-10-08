// =====================================================
// 🎭 BMSChat — MIDDLEWARE ПРОВЕРКИ РОЛЕЙ (PostgreSQL)
// =====================================================
// ⚠️ Все функции — async (await при вызове!)
//
// 🎯 2026-09-21:
//   • getMergedPermissions — 1 запрос (BOOL_OR)
//   • isCommanderOrHigher — 1 запрос
//   • queryWithRetry — maxRetries=2 (быстрее сдаётся)
//   • Кэш getMergedPermissions на 30 сек (меньше запросов к БД)
// =====================================================

const { pool } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 🔄 RETRY-ЛОГИКА (maxRetries=2 — быстрее)
// =====================================================
async function queryWithRetry(sql, params, context = 'query', maxRetries = 2) {
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

            const delay = 500;
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
// 🎯 КЭШ ПРАВ ПОЛЬЗОВАТЕЛЯ (TTL 30 секунд)
// =====================================================
const _permsCache = new Map();
const PERMS_TTL = 30 * 1000; // 30 секунд

/**
 * Сброс кэша прав.
 * @param {number|null} userId — если указан, сбросить только его; иначе — весь кэш
 */
function clearPermsCache(userId = null) {
    if (userId) {
        _permsCache.delete(userId);
        logger.info(`🗑️ Кэш прав сброшен для user=${userId}`);
    } else {
        _permsCache.clear();
        logger.info('🗑️ Весь кэш прав сброшен');
    }
}

// =====================================================
// 📋 ПОЛУЧЕНИЕ РОЛЕЙ
// =====================================================

/**
 * Загружает все роли пользователя
 */
async function getUserRoles(userId) {
    const result = await queryWithRetry(`
        SELECT r.*
        FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = $1
        ORDER BY r.priority DESC
    `, [userId], 'getUserRoles');

    return result.rows;
}

/**
 * Возвращает объединённые права пользователя (8 штук)
 * 🎯 ОДИН запрос + кэш на 30 секунд
 */
async function getMergedPermissions(userId) {
    // 🎯 Проверяем кэш
    const cached = _permsCache.get(userId);
    if (cached && Date.now() - cached.cachedAt < PERMS_TTL) {
        return cached.perms;
    }

    const result = await queryWithRetry(`
        SELECT
            BOOL_OR(r.can_write_general) AS can_write_general,
            BOOL_OR(r.can_write_private) AS can_write_private,
            BOOL_OR(r.can_write_to_commander) AS can_write_to_commander,
            BOOL_OR(r.can_create_feed) AS can_create_feed,
            BOOL_OR(r.can_approve_users) AS can_approve_users,
            BOOL_OR(r.can_manage_roles) AS can_manage_roles,
            BOOL_OR(r.can_manage_users) AS can_manage_users,
            BOOL_OR(r.can_assign_commanders) AS can_assign_commanders
        FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = $1
    `, [userId], 'getMergedPermissions');

    const perms = result.rows[0] || {};
    const result_perms = {
        can_write_general: perms.can_write_general || false,
        can_write_private: perms.can_write_private || false,
        can_write_to_commander: perms.can_write_to_commander || false,
        can_create_feed: perms.can_create_feed || false,
        can_approve_users: perms.can_approve_users || false,
        can_manage_roles: perms.can_manage_roles || false,
        can_manage_users: perms.can_manage_users || false,
        can_assign_commanders: perms.can_assign_commanders || false,
    };

    // 🎯 Сохраняем в кэш
    _permsCache.set(userId, {
        perms: result_perms,
        cachedAt: Date.now(),
    });

    return result_perms;
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
    const result = await queryWithRetry(`
        SELECT 1 FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = $1 AND r.name = $2
        LIMIT 1
    `, [userId, roleName], 'hasRole');

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
 * 🎯 ОДИН запрос вместо двух hasRole
 */
async function isCommanderOrHigher(userId) {
    const result = await queryWithRetry(`
        SELECT 1 FROM roles r
        INNER JOIN user_roles ur ON ur.role_id = r.id
        WHERE ur.user_id = $1 AND r.name IN ('Командир', 'Администратор')
        LIMIT 1
    `, [userId], 'isCommanderOrHigher');

    return result.rows.length > 0;
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
    clearPermsCache,  // 🎯 НОВОЕ
};