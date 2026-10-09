// =====================================================
// 🔔 BMSChat — FCM (Firebase Cloud Messaging)
// =====================================================
// 🎯 Отправка push-уведомлений через Firebase Admin SDK.
// 🎯 Инициализация из server/firebase-service-account.json
// 🎯 Методы:
//   • sendToToken(token, payload) — одному устройству
//   • sendToTokens(tokens, payload) — нескольким
// =====================================================

const path = require('path');
const admin = require('firebase-admin');
const logger = require('./logger');

// =====================================================
// 🚀 ИНИЦИАЛИЗАЦИЯ
// =====================================================
let initialized = false;

function initFirebase() {
    if (initialized) return true;

    try {
        // Путь к JSON-ключу Service Account
        const serviceAccountPath = path.join(
            __dirname,
            '..',
            'firebase-service-account.json',
        );

        // eslint-disable-next-line global-require, import/no-dynamic-require
        const serviceAccount = require(serviceAccountPath);

        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
        });

        initialized = true;
        logger.success('🔥 Firebase Admin SDK инициализирован', {
            projectId: serviceAccount.project_id,
        });

        return true;
    } catch (error) {
        logger.error('❌ Ошибка инициализации Firebase Admin', error);
        return false;
    }
}

// =====================================================
// 📤 ОТПРАВКА PUSH
// =====================================================

/**
 * Отправить push одному устройству по FCM-токену.
 *
 * @param {string} token — FCM-токен получателя
 * @param {object} data — { title, body, chatId?, senderName? }
 * @returns {Promise<boolean>} — true если отправлено
 */
async function sendToToken(token, data) {
    if (!initFirebase()) return false;
    if (!token || typeof token !== 'string') return false;

    try {
        await admin.messaging().send({
            token,
            notification: {
                title: data.title || 'BMSChat',
                body: data.body || 'Новое сообщение',
            },
            data: {
                // data должны быть строками (требование FCM)
                chatId: String(data.chatId || ''),
                senderName: String(data.senderName || ''),
                type: String(data.type || 'message'),
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'messages_channel',
                    color: '#FED100',
                    sound: 'default',
                },
            },
        });

        logger.info('📤 FCM отправлен', {
            token: `${token.substring(0, 20)}...`,
            title: data.title,
        });

        return true;
    } catch (error) {
        // Токен мог устареть/стать невалидным — это нормально
        if (
            error.code === 'messaging/registration-token-not-registered' ||
            error.code === 'messaging/invalid-registration-token'
        ) {
            logger.warn('⚠️ FCM-токен невалиден (устарел)', {
                token: `${token.substring(0, 20)}...`,
            });
        } else {
            logger.error('❌ Ошибка отправки FCM', error);
        }
        return false;
    }
}

/**
 * Отправить push нескольким устройствам.
 *
 * @param {string[]} tokens — массив FCM-токенов
 * @param {object} data — { title, body, chatId? }
 * @returns {Promise<{success: number, failure: number}>}
 */
async function sendToTokens(tokens, data) {
    if (!initFirebase()) return { success: 0, failure: 0 };
    if (!Array.isArray(tokens) || tokens.length === 0) {
        return { success: 0, failure: 0 };
    }

    // Фильтруем пустые
    const validTokens = tokens.filter((t) => t && typeof t === 'string');
    if (validTokens.length === 0) return { success: 0, failure: 0 };

    try {
        const response = await admin.messaging().sendEachForMulticast({
            tokens: validTokens,
            notification: {
                title: data.title || 'BMSChat',
                body: data.body || 'Новое сообщение',
            },
            data: {
                chatId: String(data.chatId || ''),
                senderName: String(data.senderName || ''),
                type: String(data.type || 'message'),
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'messages_channel',
                    color: '#FED100',
                    sound: 'default',
                },
            },
        });

        logger.info('📤 FCM bulk отправлен', {
            success: response.successCount,
            failure: response.failureCount,
        });

        return {
            success: response.successCount,
            failure: response.failureCount,
        };
    } catch (error) {
        logger.error('❌ Ошибка FCM bulk', error);
        return { success: 0, failure: 0 };
    }
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================

module.exports = {
    initFirebase,
    sendToToken,
    sendToTokens,
};