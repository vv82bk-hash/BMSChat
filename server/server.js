// =====================================================
// 🎯 BMSChat — ГЛАВНЫЙ ФАЙЛ СЕРВЕРА (PostgreSQL)
// =====================================================

const express = require('express');
const http = require('http');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const config = require('./config');
const logger = require('./utils/logger');
const { pool } = require('./database/init');
// Страховка от падения при ошибках простаивающих соединений
pool.on('error', (err) => {
    console.error('⚠️ Ошибка пула PostgreSQL (не критично):', err.message);
const { initSocket } = require('./socket');

// =====================================================
// 🚀 EXPRESS
// =====================================================
const app = express();

app.use(cors({
    origin: config.CORS_ORIGIN || '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Статика uploads
const uploadsDir = path.join(__dirname, config.UPLOAD_DIR);
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
    logger.info('Создана папка uploads', { path: uploadsDir });
}
app.use('/uploads', express.static(uploadsDir));

// Логирование в development
if (config.IS_DEVELOPMENT) {
    app.use((req, res, next) => {
        if (req.method !== 'GET') {
            logger.info(`${req.method} ${req.path}`, { ip: req.ip });
        }
        next();
    });
}

// =====================================================
// 🩺 HEALTH-CHECK
// =====================================================
app.get('/api/health', async (req, res) => {
    try {
        const dbCheck = await pool.query('SELECT NOW() as now');
        res.json({
            status: 'healthy',
            uptime: process.uptime(),
            timestamp: new Date().toISOString(),
            database: 'connected',
            dbTime: dbCheck.rows[0].now,
            version: '1.0.0',
        });
    } catch (error) {
        res.status(500).json({
            status: 'unhealthy',
            error: error.message,
        });
    }
});

// =====================================================
// 📡 РОУТЫ
// =====================================================
const authRoutes = require('./routes/auth');
app.use('/api/auth', authRoutes);

const usersRoutes = require('./routes/users');
app.use('/api/users', usersRoutes);

const chatsRoutes = require('./routes/chats');
app.use('/api/chats', chatsRoutes);

const messagesRoutes = require('./routes/messages');
app.use('/api/messages', messagesRoutes);

const uploadRoutes = require('./routes/upload');
app.use('/api/upload', uploadRoutes);

logger.info('Роуты подключены', {
    routes: [
        '/api/auth',
        '/api/users',
        '/api/chats',
        '/api/messages',
        '/api/upload',
    ],
});

// =====================================================
// 🚫 404
// =====================================================
app.use((req, res) => {
    res.status(404).json({
        error: 'Роут не найден',
        path: req.path,
    });
});

// =====================================================
// ❌ ГЛОБАЛЬНЫЙ ОБРАБОТЧИК ОШИБОК
// =====================================================
app.use((err, req, res, next) => {
    logger.error('Необработанная ошибка', err, {
        path: req.path,
        method: req.method,
    });

    res.status(err.status || 500).json({
        error: config.IS_DEVELOPMENT ? err.message : 'Ошибка сервера',
    });
});

// =====================================================
// 🌐 HTTP + SOCKET.IO
// =====================================================
const server = http.createServer(app);
const io = initSocket(server);
app.set('io', io);

// =====================================================
// 🚀 ЗАПУСК
// =====================================================
const PORT = config.PORT;
const HOST = config.HOST;

async function start() {
    try {
        // Проверка подключения к PostgreSQL
        console.log('');
        console.log('🔌 Проверка подключения к PostgreSQL...');
        const result = await pool.query('SELECT NOW() as now, version() as ver');
        console.log('✅ PostgreSQL подключён');
        console.log(`   Время сервера: ${result.rows[0].now}`);
        console.log(`   Версия: ${result.rows[0].ver.split(' ').slice(0, 2).join(' ')}`);

        server.listen(PORT, HOST, () => {
            console.log('');
            console.log('═══════════════════════════════════════');
            console.log('🎯 BMSChat — СЕРВЕР ЗАПУЩЕН');
            console.log('═══════════════════════════════════════');
            console.log(`🚀 Порт:      ${PORT}`);
            console.log(`📡 HTTP:      http://localhost:${PORT}`);
            console.log(`📡 API:       http://localhost:${PORT}/api`);
            console.log(`🔌 WebSocket: ws://localhost:${PORT}`);
            console.log(`📁 Uploads:   http://localhost:${PORT}/uploads`);
            console.log(`🌍 CORS:      ${config.CORS_ORIGIN}`);
            console.log(`💾 БД:        PostgreSQL`);
            console.log('');
            console.log('📋 Проверка:');
            console.log(`   curl http://localhost:${PORT}/api/health`);
            console.log('');
            console.log('🔐 Данные для входа:');
            console.log('   Логин:  admin');
            console.log('   Пароль: admin_secret_2024');
            console.log('');
            console.log('⛔ Для остановки: Ctrl+C');
            console.log('═══════════════════════════════════════');
            console.log('');

            logger.success('Сервер запущен', {
                port: PORT,
                host: HOST,
                env: config.NODE_ENV,
            });
        });
    } catch (error) {
        console.error('');
        console.error('❌ ОШИБКА ЗАПУСКА СЕРВЕРА:');
        console.error(error.message);
        logger.error('Ошибка запуска', error);
        process.exit(1);
    }
}

start();

// =====================================================
// 🛑 КОРРЕКТНАЯ ОСТАНОВКА
// =====================================================
process.on('SIGINT', async () => {
    console.log('');
    logger.info('Остановка сервера...');

    io.close(async () => {
        logger.info('Socket.IO остановлен');

        server.close(async () => {
            await pool.end();
            logger.success('Сервер остановлен');
            process.exit(0);
        });
    });

    setTimeout(() => {
        logger.warn('Форсированная остановка');
        process.exit(1);
    }, 5000);
});

process.on('uncaughtException', (err) => {
    logger.error('Uncaught Exception', err);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection', reason);
});

module.exports = { app, server, io };