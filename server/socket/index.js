// =====================================================
// 🔌 BMSChat — ИНИЦИАЛИЗАЦИЯ SOCKET.IO
// =====================================================
// Создаёт Socket.IO сервер, подключает middleware
// авторизации и обработчики событий.
//
// КАК ИСПОЛЬЗУЕТСЯ:
//   const { initSocket } = require('./socket');
//   const io = initSocket(httpServer);
// =====================================================

const { Server } = require('socket.io');
const socketAuth = require('../utils/socketAuth');
const { registerHandlers } = require('./handlers');
const config = require('../config');
const logger = require('../utils/logger');

/**
 * Инициализирует Socket.IO.
 * 
 * @param {http.Server} httpServer - HTTP-сервер Express
 * @returns {Server} - Socket.IO сервер
 */
function initSocket(httpServer) {
    // ============================================
    // СОЗДАНИЕ SOCKET.IO СЕРВЕРА
    // ============================================
    const io = new Server(httpServer, {
        cors: {
            origin: config.CORS_ORIGIN || '*',
            methods: ['GET', 'POST'],
            credentials: true,
        },
        // WebSocket — основной транспорт (быстрее polling)
        transports: ['websocket', 'polling'],
        
        // Пингование: проверяем, жив ли клиент
        pingTimeout: 60000,  // Если нет ответа 60 сек — считать мёртвым
        pingInterval: 25000, // Пингать каждые 25 сек
        
        // Максимальный размер сообщения
        maxHttpBufferSize: 10 * 1024 * 1024, // 10 МБ
    });

    // ============================================
    // MIDDLEWARE АВТОРИЗАЦИИ
    // ============================================
    // Выполняется ДО того, как сокет подключится.
    // Если токен невалидный — соединение отклоняется.
    io.use(socketAuth);

    // ============================================
    // ЛОГИРОВАНИЕ ПОДКЛЮЧЕНИЙ
    // ============================================
    io.on('connection', (socket) => {
        const user = socket.data.user;
        logger.logSocket(user.id, 'connect', { displayName: user.display_name });
    });

    // ============================================
    // РЕГИСТРАЦИЯ ОБРАБОТЧИКОВ
    // ============================================
    registerHandlers(io);

    logger.success('Socket.IO инициализирован');

    return io;
}

module.exports = { initSocket };