// =====================================================
// 🎯 BMSChat — ГЛАВНЫЙ ФАЙЛ СЕРВЕРА
// =====================================================
// Точка входа. Собирает всё вместе:
//   1. Express-приложение
//   2. Middleware (CORS, JSON, статика)
//   3. Роуты (auth, users, chats, messages, upload)
//   4. Socket.IO (WebSocket)
//   5. Health-check (для UptimeRobot)
//
// Запуск:
//   npm run dev   # с автоперезапуском
//   npm start     # обычно
// =====================================================

const express = require('express');
const http = require('http');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

// Конфигурация
const config = require('./config');
const logger = require('./utils/logger');

// Инициализация Socket.IO
const { initSocket } = require('./socket');

// =====================================================
// 🚀 СОЗДАНИЕ EXPRESS-ПРИЛОЖЕНИЯ
// =====================================================
const app = express();

// -----------------------------------------------------
// 🌍 CORS
// -----------------------------------------------------
app.use(cors({
    origin: config.CORS_ORIGIN || '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
}));

// -----------------------------------------------------
// 📦 JSON-парсер
// -----------------------------------------------------
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// -----------------------------------------------------
// 📸 СТАТИЧЕСКАЯ ПАПКА UPLOADS
// -----------------------------------------------------
const uploadsDir = path.join(__dirname, config.UPLOAD_DIR);

if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
    logger.info('Создана папка uploads', { path: uploadsDir });
}

app.use('/uploads', express.static(uploadsDir));

// -----------------------------------------------------
// 📝 ЛОГИРОВАНИЕ (только не-GET в development)
// -----------------------------------------------------
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
app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        version: '1.0.0',
    });
});

// =====================================================
// 📡 ПОДКЛЮЧЕНИЕ РОУТОВ
// =====================================================

// Авторизация: регистрация, вход, /me, logout
const authRoutes = require('./routes/auth');
app.use('/api/auth', authRoutes);

// Пользователи: список, профили, роли, подтверждение
const usersRoutes = require('./routes/users');
app.use('/api/users', usersRoutes);

// Чаты: список, создание, участники
const chatsRoutes = require('./routes/chats');
app.use('/api/chats', chatsRoutes);

// Сообщения: история, отправка, редактирование, реакции
const messagesRoutes = require('./routes/messages');
app.use('/api/messages', messagesRoutes);

// Загрузка файлов: фото, голосовые
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
// 🌐 HTTP-СЕРВЕР + SOCKET.IO
// =====================================================
const server = http.createServer(app);
const io = initSocket(server);
app.set('io', io);

// =====================================================
// 🚀 ЗАПУСК
// =====================================================
const PORT = config.PORT;
const HOST = config.HOST;

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

// =====================================================
// 🛑 КОРРЕКТНАЯ ОСТАНОВКА
// =====================================================
process.on('SIGINT', () => {
    console.log('');
    logger.info('Остановка сервера...');

    io.close(() => {
        logger.info('Socket.IO остановлен');

        server.close(() => {
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

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================
module.exports = { app, server, io };