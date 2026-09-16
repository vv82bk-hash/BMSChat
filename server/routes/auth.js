// =====================================================
// 🔐 BMSChat — РОУТЫ АВТОРИЗАЦИИ
// =====================================================
// Регистрация, вход, выход.
//
// ЛОГИКА РЕГИСТРАЦИИ:
//   1. Пользователь регистрируется → is_approved = 0
//   2. НЕ выдаём никаких ролей
//   3. Ждёт подтверждения командира
//
// ПОСЛЕ ПОДТВЕРЖДЕНИЯ (см. routes/users.js):
//   → Командир вызывает /approve
//   → Выдаётся роль "Боец"
//   → is_approved = 1
//
// БЕЗОПАСНОСТЬ:
//   • Rate Limiting — не более 5 попыток входа / 15 мин
//   • Account Lockout — блокировка после 5 неудач на 30 мин
//   • Pepper — дополнительный секрет для паролей
//   • JWT — токен на 7 дней
// =====================================================

const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();

const config = require('../config');
const { db } = require('../database/init');
const { hashPassword, verifyPassword, validatePasswordStrength } = require('../utils/password');
const { generateToken } = require('../utils/jwt');
const { authMiddleware } = require('../middleware/auth');
const { getMergedPermissions, getUserRoles } = require('../middleware/roles');
const logger = require('../utils/logger');

// =====================================================
// 🛡️ RATE LIMITING
// =====================================================

// /login — 5 попыток / 15 минут
const loginLimiter = rateLimit({
    windowMs: config.LOGIN_RATE_WINDOW_MINUTES * 60 * 1000,
    max: config.LOGIN_RATE_LIMIT,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
        logger.warn('Rate limit для /login', { ip: req.ip });
        res.status(429).json({
            error: 'Слишком много попыток входа',
            message: `Попробуйте через ${config.LOGIN_RATE_WINDOW_MINUTES} минут`,
        });
    },
});

// /register — 3 регистрации / час с одного IP
const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 3,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
        logger.warn('Rate limit для /register', { ip: req.ip });
        res.status(429).json({
            error: 'Слишком много регистраций',
            message: 'Попробуйте позже',
        });
    },
});

// =====================================================
// 📝 POST /api/auth/register — Регистрация
// =====================================================
// ⚠️ НЕ выдаём роли! Пользователь ждёт подтверждения.
// После подтверждения командиром выдаётся роль "Боец"
// (см. routes/users.js → POST /:id/approve).
// =====================================================
router.post('/register', registerLimiter, async (req, res) => {
    try {
        const { username, password, display_name } = req.body;

        // Валидация
        if (!username || !password) {
            return res.status(400).json({
                error: 'Логин и пароль обязательны',
            });
        }

        if (username.length < 3 || username.length > 30) {
            return res.status(400).json({
                error: 'Логин должен быть от 3 до 30 символов',
            });
        }

        if (!/^[a-zA-Z0-9_]+$/.test(username)) {
            return res.status(400).json({
                error: 'Логин может содержать только латиницу, цифры и _',
            });
        }

        const pwdCheck = validatePasswordStrength(password);
        if (!pwdCheck.valid) {
            return res.status(400).json({ error: pwdCheck.message });
        }

        // Проверка логина
        const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
        if (existing) {
            return res.status(409).json({
                error: 'Пользователь с таким логином уже существует',
            });
        }

        // Лимит пользователей
        const count = db.prepare('SELECT COUNT(*) as cnt FROM users').get();
        if (count.cnt >= config.MAX_USERS) {
            return res.status(403).json({
                error: `Достигнут лимит пользователей (${config.MAX_USERS})`,
            });
        }

        // Хешируем пароль
        const passwordHash = await hashPassword(password);

        // Создаём пользователя БЕЗ ролей (is_approved=0)
        const result = db.prepare(`
            INSERT INTO users (username, password, display_name, is_approved)
            VALUES (?, ?, ?, 0)
        `).run(username, passwordHash, display_name || username);

        const userId = result.lastInsertRowid;

        logger.success('Новый пользователь зарегистрирован', {
            userId,
            username,
        });

        res.status(201).json({
            message: 'Регистрация успешна! Ожидайте подтверждения командира.',
            user: {
                id: userId,
                username,
                display_name: display_name || username,
                is_approved: 0,
            },
        });

    } catch (error) {
        logger.error('Ошибка регистрации', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🔑 POST /api/auth/login — Вход
// =====================================================
router.post('/login', loginLimiter, async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({
                error: 'Логин и пароль обязательны',
            });
        }

        // Ищем пользователя
        const user = db.prepare(`
            SELECT id, username, password, display_name, avatar,
                   is_approved, failed_login_attempts, lockout_until
            FROM users WHERE username = ?
        `).get(username);

        if (!user) {
            logger.logLoginAttempt(username, false);
            return res.status(401).json({
                error: 'Неверный логин или пароль',
            });
        }

        // ============================================
        // 🔒 ПРОВЕРКА БЛОКИРОВКИ
        // ============================================
        if (user.lockout_until) {
            const lockoutTime = new Date(user.lockout_until);
            const now = new Date();

            if (lockoutTime > now) {
                const minutesLeft = Math.ceil((lockoutTime - now) / 60000);
                logger.warn('Попытка входа в заблокированный аккаунт', {
                    userId: user.id, minutesLeft,
                });
                return res.status(429).json({
                    error: 'Аккаунт временно заблокирован',
                    message: `Попробуйте через ${minutesLeft} мин.`,
                    lockoutUntil: user.lockout_until,
                });
            } else {
                db.prepare(`
                    UPDATE users 
                    SET failed_login_attempts = 0, lockout_until = NULL 
                    WHERE id = ?
                `).run(user.id);
                user.failed_login_attempts = 0;
                user.lockout_until = null;
            }
        }

        // ============================================
        // ✓ ПРОВЕРКА ПАРОЛЯ
        // ============================================
        const valid = await verifyPassword(password, user.password);

        if (!valid) {
            const attempts = (user.failed_login_attempts || 0) + 1;

            if (attempts >= config.MAX_LOGIN_ATTEMPTS) {
                const lockoutUntil = new Date(
                    Date.now() + config.LOCKOUT_DURATION_MINUTES * 60 * 1000
                ).toISOString();

                db.prepare(`
                    UPDATE users 
                    SET failed_login_attempts = ?, lockout_until = ? 
                    WHERE id = ?
                `).run(attempts, lockoutUntil, user.id);

                logger.logAccountLockout(user.id, lockoutUntil);

                return res.status(429).json({
                    error: 'Аккаунт заблокирован',
                    message: `Слишком много попыток. Попробуйте через ${config.LOCKOUT_DURATION_MINUTES} мин.`,
                    lockoutUntil,
                });
            } else {
                db.prepare(`
                    UPDATE users SET failed_login_attempts = ? WHERE id = ?
                `).run(attempts, user.id);

                logger.logLoginAttempt(username, false);

                return res.status(401).json({
                    error: 'Неверный логин или пароль',
                    attemptsLeft: config.MAX_LOGIN_ATTEMPTS - attempts,
                });
            }
        }

        // ============================================
        // ✓ ПРОВЕРКА ПОДТВЕРЖДЕНИЯ
        // ============================================
        if (!user.is_approved) {
            logger.logLoginAttempt(username, false);
            return res.status(403).json({
                error: 'Аккаунт не подтверждён',
                message: 'Дождитесь подтверждения командира',
            });
        }

        // ============================================
        // ✅ УСПЕШНЫЙ ВХОД
        // ============================================

        db.prepare(`
            UPDATE users
            SET status = 'online',
                last_seen = CURRENT_TIMESTAMP,
                failed_login_attempts = 0,
                lockout_until = NULL
            WHERE id = ?
        `).run(user.id);

        // Генерируем токен
        const token = generateToken(user);

        // Загружаем роли и права (НОВАЯ СХЕМА)
        const roles = getUserRoles(user.id);
        const permissions = getMergedPermissions(user.id);

        logger.logLoginAttempt(username, true);

        res.json({
            message: 'Вход выполнен',
            token,
            user: {
                id: user.id,
                username: user.username,
                display_name: user.display_name,
                avatar: user.avatar,
                is_approved: user.is_approved,
                roles: roles.map(r => ({
                    id: r.id,
                    name: r.name,
                    color: r.color,
                    icon: r.icon,
                    priority: r.priority,
                })),
                permissions,
            },
        });

    } catch (error) {
        logger.error('Ошибка входа', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 👤 GET /api/auth/me — Текущий пользователь
// =====================================================
router.get('/me', authMiddleware, (req, res) => {
    try {
        const roles = getUserRoles(req.user.id);
        const permissions = getMergedPermissions(req.user.id);

        res.json({
            user: {
                ...req.user,
                roles: roles.map(r => ({
                    id: r.id,
                    name: r.name,
                    color: r.color,
                    icon: r.icon,
                    priority: r.priority,
                })),
                permissions,
            },
        });
    } catch (error) {
        logger.error('Ошибка /me', error, { userId: req.user?.id });
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🚪 POST /api/auth/logout — Выход
// =====================================================
router.post('/logout', authMiddleware, (req, res) => {
    try {
        db.prepare(`
            UPDATE users
            SET status = 'offline', last_seen = CURRENT_TIMESTAMP
            WHERE id = ?
        `).run(req.user.id);

        logger.info('Выход пользователя', { userId: req.user.id });

        res.json({ message: 'Выход выполнен' });
    } catch (error) {
        logger.error('Ошибка выхода', error, { userId: req.user?.id });
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;