// =====================================================
// 🔐 BMSChat — РОУТЫ АВТОРИЗАЦИИ (PostgreSQL)
// =====================================================

const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();

const config = require('../config');
const { pool } = require('../database/init');
const { hashPassword, verifyPassword, validatePasswordStrength } = require('../utils/password');
const { generateToken } = require('../utils/jwt');
const { authMiddleware } = require('../middleware/auth');
const { getMergedPermissions, getUserRoles } = require('../middleware/roles');
const { notifyAdminsNewRecruit } = require('../socket/handlers');
const logger = require('../utils/logger');

// =====================================================
// 🛡️ RATE LIMITING
// =====================================================

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
// 📝 POST /api/auth/register
// =====================================================
router.post('/register', registerLimiter, async (req, res) => {
    try {
        const { username, password, display_name } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Логин и пароль обязательны' });
        }

        if (username.length < 3 || username.length > 30) {
            return res.status(400).json({ error: 'Логин должен быть от 3 до 30 символов' });
        }

        if (!/^[a-zA-Z0-9_]+$/.test(username)) {
            return res.status(400).json({ error: 'Логин может содержать только латиницу, цифры и _' });
        }

        const pwdCheck = validatePasswordStrength(password);
        if (!pwdCheck.valid) {
            return res.status(400).json({ error: pwdCheck.message });
        }

        // Проверка, что логин свободен
        const existing = await pool.query('SELECT id FROM users WHERE username = $1', [username]);
        if (existing.rows.length > 0) {
            return res.status(409).json({ error: 'Пользователь с таким логином уже существует' });
        }

        // Лимит пользователей
        const count = await pool.query('SELECT COUNT(*) as cnt FROM users');
        if (parseInt(count.rows[0].cnt, 10) >= config.MAX_USERS) {
            return res.status(403).json({
                error: `Достигнут лимит пользователей (${config.MAX_USERS})`,
            });
        }

        const passwordHash = await hashPassword(password);

        const result = await pool.query(`
            INSERT INTO users (username, password, display_name, is_approved)
            VALUES ($1, $2, $3, FALSE)
            RETURNING id, username, display_name, created_at
        `, [username, passwordHash, display_name || username]);

        const newUser = result.rows[0];
        const userId = newUser.id;

        logger.success('Новый пользователь зарегистрирован', { userId, username });

        // 🔔 Уведомляем командиров и админов о новом новобранце
        const io = req.app.get('io');
        if (io) {
            await notifyAdminsNewRecruit(io, newUser);
        } else {
            logger.warn('io не найден в req.app — уведомление не отправлено');
        }

        res.status(201).json({
            message: 'Регистрация успешна! Ожидайте подтверждения командира.',
            user: {
                id: userId,
                username,
                display_name: display_name || username,
                is_approved: false,
            },
        });
    } catch (error) {
        logger.error('Ошибка регистрации', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// =====================================================
// 🔑 POST /api/auth/login
// =====================================================
router.post('/login', loginLimiter, async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Логин и пароль обязательны' });
        }

        const result = await pool.query(`
            SELECT id, username, password, display_name, avatar,
                   is_approved, failed_login_attempts, lockout_until
            FROM users WHERE username = $1
        `, [username]);

        if (result.rows.length === 0) {
            logger.logLoginAttempt(username, false);
            return res.status(401).json({ error: 'Неверный логин или пароль' });
        }

        const user = result.rows[0];

        // Проверка блокировки
        if (user.lockout_until) {
            const lockoutTime = new Date(user.lockout_until);
            const now = new Date();

            if (lockoutTime > now) {
                const minutesLeft = Math.ceil((lockoutTime - now) / 60000);
                logger.warn('Попытка входа в заблокированный аккаунт', {
                    userId: user.id,
                    minutesLeft,
                });
                return res.status(429).json({
                    error: 'Аккаунт временно заблокирован',
                    message: `Попробуйте через ${minutesLeft} мин.`,
                    lockoutUntil: user.lockout_until,
                });
            } else {
                await pool.query(`
                    UPDATE users 
                    SET failed_login_attempts = 0, lockout_until = NULL 
                    WHERE id = $1
                `, [user.id]);
                user.failed_login_attempts = 0;
                user.lockout_until = null;
            }
        }

        // Проверка пароля
        const valid = await verifyPassword(password, user.password);

        if (!valid) {
            const attempts = (user.failed_login_attempts || 0) + 1;

            if (attempts >= config.MAX_LOGIN_ATTEMPTS) {
                const lockoutUntil = new Date(
                    Date.now() + config.LOCKOUT_DURATION_MINUTES * 60 * 1000
                );

                await pool.query(`
                    UPDATE users 
                    SET failed_login_attempts = $1, lockout_until = $2
                    WHERE id = $3
                `, [attempts, lockoutUntil, user.id]);

                logger.logAccountLockout(user.id, lockoutUntil.toISOString());

                return res.status(429).json({
                    error: 'Аккаунт заблокирован',
                    message: `Слишком много попыток. Попробуйте через ${config.LOCKOUT_DURATION_MINUTES} мин.`,
                    lockoutUntil,
                });
            } else {
                await pool.query(`
                    UPDATE users SET failed_login_attempts = $1 WHERE id = $2
                `, [attempts, user.id]);

                logger.logLoginAttempt(username, false);

                return res.status(401).json({
                    error: 'Неверный логин или пароль',
                    attemptsLeft: config.MAX_LOGIN_ATTEMPTS - attempts,
                });
            }
        }

        // Проверка подтверждения
        if (!user.is_approved) {
            logger.logLoginAttempt(username, false);
            return res.status(403).json({
                error: 'Аккаунт не подтверждён',
                message: 'Дождитесь подтверждения командира',
            });
        }

        // Успешный вход
        await pool.query(`
            UPDATE users
            SET status = 'online',
                last_seen = NOW(),
                failed_login_attempts = 0,
                lockout_until = NULL
            WHERE id = $1
        `, [user.id]);

        const token = generateToken(user);
        const roles = await getUserRoles(user.id);
        const permissions = await getMergedPermissions(user.id);

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
                roles: roles.map((r) => ({
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
// 👤 GET /api/auth/me
// =====================================================
router.get('/me', authMiddleware, async (req, res) => {
    try {
        const roles = await getUserRoles(req.user.id);
        const permissions = await getMergedPermissions(req.user.id);

        res.json({
            user: {
                ...req.user,
                roles: roles.map((r) => ({
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
// 🚪 POST /api/auth/logout
// =====================================================
router.post('/logout', authMiddleware, async (req, res) => {
    try {
        await pool.query(`
            UPDATE users
            SET status = 'offline', last_seen = NOW()
            WHERE id = $1
        `, [req.user.id]);

        logger.info('Выход пользователя', { userId: req.user.id });

        res.json({ message: 'Выход выполнен' });
    } catch (error) {
        logger.error('Ошибка выхода', error, { userId: req.user?.id });
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;