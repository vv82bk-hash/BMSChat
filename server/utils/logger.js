// =====================================================
// 📝 BMSChat — БЕЗОПАСНОЕ ЛОГИРОВАНИЕ
// =====================================================
// Логирует ТОЛЬКО метаданные:
//   ✅ Кто, куда, когда, сколько символов
//   ❌ Текст сообщений, содержимое, пароли
//
// ЗАЧЕМ ЭТО НУЖНО:
//   Если логи утекут (например, через ошибку в коде или
//   доступ к серверу), злоумышленник НЕ должен получить
//   содержимое переписок.
//
// ПРИМЕР ПРАВИЛЬНОГО ЛОГА:
//   📨 user=5 → chat=2 (127 симв.)
//
// ПРИМЕР НЕПРАВИЛЬНОГО ЛОГА (НЕ ДЕЛАЕМ ТАК):
//   📨 user=5 → chat=2: "Встречаемся в 18:00 у базы"
// =====================================================

const config = require('../config');

// -----------------------------------------------------
// 🕒 ВСПОМОГАТЕЛЬНОЕ: TIMESTAMP
// -----------------------------------------------------
/**
 * Возвращает текущее время в ISO-формате.
 * @returns {string}
 */
function ts() {
    return new Date().toISOString();
}

/**
 * Форматирует метаданные в строку для лога.
 * @param {Object} meta
 * @returns {string}
 */
function formatMeta(meta) {
    if (!meta || Object.keys(meta).length === 0) return '';
    try {
        return ` ${JSON.stringify(meta)}`;
    } catch (e) {
        return ' [meta error]';
    }
}

// -----------------------------------------------------
// ℹ️ INFO — обычная информация
// -----------------------------------------------------
/**
 * Логирует обычное информационное сообщение.
 * 
 * @param {string} message
 * @param {Object} meta - метаданные (БЕЗ секретов!)
 * 
 * @example
 *   logger.info('Сервер запущен', { port: 5000 });
 */
function info(message, meta = {}) {
    console.log(`ℹ️  [${ts()}] ${message}${formatMeta(meta)}`);
}

// -----------------------------------------------------
// ✅ SUCCESS — успешное действие
// -----------------------------------------------------
/**
 * Логирует успешное действие.
 * 
 * @param {string} message
 * @param {Object} meta
 * 
 * @example
 *   logger.success('Пользователь создан', { userId: 1 });
 */
function success(message, meta = {}) {
    console.log(`✅ [${ts()}] ${message}${formatMeta(meta)}`);
}

// -----------------------------------------------------
// ⚠️ WARN — предупреждение
// -----------------------------------------------------
/**
 * Логирует предупреждение.
 * 
 * @param {string} message
 * @param {Object} meta
 * 
 * @example
 *   logger.warn('Попытка доступа к чужому чату', { userId: 5, chatId: 2 });
 */
function warn(message, meta = {}) {
    console.warn(`⚠️  [${ts()}] ${message}${formatMeta(meta)}`);
}

// -----------------------------------------------------
// ❌ ERROR — ошибка
// -----------------------------------------------------
/**
 * Логирует ошибку.
 * 
 * В development — показывает stack trace.
 * В production — только сообщение (чтобы не светить пути файлов).
 * 
 * @param {string} message
 * @param {Error|null} err
 * @param {Object} meta
 * 
 * @example
 *   logger.error('Ошибка БД', error, { userId: 5 });
 */
function error(message, err = null, meta = {}) {
    console.error(`❌ [${ts()}] ${message}${formatMeta(meta)}`);
    
    if (err && config.IS_DEVELOPMENT) {
        console.error(err.stack || err);
    }
}

// -----------------------------------------------------
// 📨 LOG MESSAGE — БЕЗОПАСНОЕ ЛОГИРОВАНИЕ СООБЩЕНИЙ
// -----------------------------------------------------
/**
 * Логирует отправку сообщения БЕЗ ТЕКСТА.
 * 
 * Указывает только:
 *   • ID отправителя
 *   • ID чата
 *   • Длину текста (символов)
 * 
 * @param {number} senderId
 * @param {number} chatId
 * @param {number} textLength
 * 
 * @example
 *   logger.logMessage(5, 2, 127);
 *   // 📨 [timestamp] user=5 → chat=2 (127 симв.)
 */
function logMessage(senderId, chatId, textLength) {
    // Логируем только в development — в production это слишком накладно
    if (config.IS_DEVELOPMENT) {
        console.log(`📨 [${ts()}] user=${senderId} → chat=${chatId} (${textLength} симв.)`);
    }
}

// -----------------------------------------------------
// 🚨 LOG ACCESS DENIED — попытка доступа к чужому
// -----------------------------------------------------
/**
 * Логирует попытку доступа к чужому чату.
 * 
 * ЭТО КРИТИЧНЫЙ ЛОГ — используется для аудита безопасности.
 * Если пользователь пытается читать чужие чаты — мы должны знать.
 * 
 * @param {number} userId
 * @param {number} chatId
 * @param {string} reason
 * 
 * @example
 *   logger.logAccessDenied(5, 2, 'не участник чата');
 *   // 🚨 [timestamp] Отказано в доступе: user=5, chat=2, reason=не участник чата
 */
function logAccessDenied(userId, chatId, reason) {
    console.warn(
        `🚨 [${ts()}] ОТКАЗАНО В ДОСТУПЕ: user=${userId}, chat=${chatId}, reason=${reason}`
    );
}

// -----------------------------------------------------
// 🔑 LOG LOGIN ATTEMPT — попытка входа
// -----------------------------------------------------
/**
 * Логирует попытку входа.
 * 
 * @param {string} username - логин (НЕ пароль!)
 * @param {boolean} success - успешно ли
 * 
 * @example
 *   logger.logLoginAttempt('commander', true);
 *   // ✅ [timestamp] Вход: commander
 */
function logLoginAttempt(username, success) {
    const status = success ? '✅' : '❌';
    console.log(`${status} [${ts()}] Вход: ${username}`);
}

// -----------------------------------------------------
// 🔒 LOG ACCOUNT LOCKOUT — блокировка аккаунта
// -----------------------------------------------------
/**
 * Логирует блокировку аккаунта после неудачных попыток.
 * 
 * @param {number} userId
 * @param {string} until - ISO-дата окончания блокировки
 * 
 * @example
 *   logger.logAccountLockout(5, '2024-01-15T10:30:00.000Z');
 *   // 🔒 [timestamp] Аккаунт 5 заблокирован до 2024-01-15T10:30:00.000Z
 */
function logAccountLockout(userId, until) {
    console.warn(`🔒 [${ts()}] Аккаунт ${userId} заблокирован до ${until}`);
}

// -----------------------------------------------------
// 🔌 LOG SOCKET — подключение/отключение WebSocket
// -----------------------------------------------------
/**
 * Логирует подключение или отключение WebSocket.
 * 
 * @param {number} userId
 * @param {string} action - 'connect' | 'disconnect'
 * @param {Object} meta
 */
function logSocket(userId, action, meta = {}) {
    const icon = action === 'connect' ? '🔗' : '🔌';
    console.log(`${icon} [${ts()}] Socket ${action}: user=${userId}${formatMeta(meta)}`);
}

// -----------------------------------------------------
// 📤 ЭКСПОРТ
// -----------------------------------------------------
module.exports = {
    // Общие
    info,
    success,
    warn,
    error,
    
    // Специальные (для безопасности)
    logMessage,
    logAccessDenied,
    logLoginAttempt,
    logAccountLockout,
    logSocket,
};