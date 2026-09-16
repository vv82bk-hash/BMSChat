// =====================================================
// ⚙️ BMSChat — КОНФИГУРАЦИЯ ПРИЛОЖЕНИЯ
// =====================================================
// Все константы проекта в одном месте.
//
// ВАЖНО: Dart НЕ поддерживает вложенные классы!
// Поэтому все классы объявлены отдельно (top-level).
//
// ИСПОЛЬЗОВАНИЕ:
//   import 'package:bmschat/config/constants.dart';
//   final url = Constants.apiUrl;
//   final login = ApiEndpoints.login;
//   final typing = SocketEvents.typing;
// =====================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// =====================================================
// 🌐 ОСНОВНЫЕ КОНСТАНТЫ
// =====================================================
class Constants {
    // =====================================================
    // 🌐 URL СЕРВЕРА
    // =====================================================
    // Разные платформы видят "localhost" по-разному:
    //
    //   • Android-эмулятор → 10.0.2.2 (специальный IP хоста)
    //   • iOS-симулятор    → localhost
    //   • Веб (Chrome/Edge)→ localhost
    //   • Реальное устройство → IP компьютера в локальной сети
    // =====================================================

    /// Базовый URL сервера (автоопределение по платформе)
    static String get baseUrl {
        // Веб (Chrome, Edge) — localhost
        if (kIsWeb) {
            return 'http://localhost:5000';
        }

        // Android (эмулятор)
        if (Platform.isAndroid) {
            // ⚠️ 10.0.2.2 — специальный IP для доступа к хосту из эмулятора
            // Для РЕАЛЬНОГО телефона замените на IP компьютера
            return 'http://10.0.2.2:5000';
        }

        // iOS (симулятор) и прочие
        return 'http://localhost:5000';
    }

    /// Базовый URL API
    static String get apiUrl => '$baseUrl/api';

    /// URL Socket.IO
    static String get socketUrl => baseUrl;

    /// URL для файлов (uploads)
    /// Пример: http://10.0.2.2:5000/uploads/123.jpg
    static String get uploadsUrl => '$baseUrl/uploads';

    /// Получить полный URL к файлу по его пути
    /// 
    /// [filePath] — путь из БД, например `/uploads/123.jpg`
    /// Возвращает полный URL: `http://10.0.2.2:5000/uploads/123.jpg`
    static String getFullFileUrl(String filePath) {
        if (filePath.startsWith('http')) return filePath;
        if (filePath.startsWith('/uploads/')) {
            return '$baseUrl$filePath';
        }
        return '$uploadsUrl/$filePath';
    }

    // =====================================================
    // ⏱️ ТАЙМАУТЫ И ЛИМИТЫ
    // =====================================================

    static const Duration httpTimeout = Duration(seconds: 15);
    static const Duration socketTimeout = Duration(seconds: 10);
    static const int typingTimeoutMs = 3000;
    static const int typingThrottleMs = 2000;
    static const int messagePageSize = 50;

    // =====================================================
    // 📏 UI-КОНСТАНТЫ
    // =====================================================

    static const int maxMessageLength = 4000;
    static const int maxUsernameLength = 30;
    static const int minPasswordLength = 6;
    static const int animationDurationMs = 300;

    // =====================================================
    // 📅 ФОРМАТЫ ДАТ
    // =====================================================

    static const String timeFormat = 'HH:mm';
    static const String dateFormat = 'dd.MM.yyyy';
    static const String fullDateTimeFormat = 'dd.MM.yyyy HH:mm';

    // =====================================================
    // 🎯 БИЗНЕС-КОНСТАНТЫ
    // =====================================================

    static const int maxUsers = 100;
    static const String teamName = 'Отряд Боба Марли';
    static const String slogan = 'Двигай. Вдохновляй';
    static const String appVersion = '1.0.0';

    // =====================================================
    // 🐛 РЕЖИМ ОТЛАДКИ
    // =====================================================

    static const bool enableLogs = true;
    static const bool verboseErrors = true;
}

// =====================================================
// 🔗 ЭНДПОИНТЫ API
// =====================================================
// Все роуты сервера. Чтобы не писать вручную в api_service.dart.
//
// Использование:
//   ApiEndpoints.login        → '/auth/login'
//   ApiEndpoints.user(5)      → '/users/5'
// =====================================================

class ApiEndpoints {
    // ═══════════════════════════════════════════════════
    // 🔐 АВТОРИЗАЦИЯ
    // ═══════════════════════════════════════════════════
    static const String register = '/auth/register';
    static const String login = '/auth/login';
    static const String me = '/auth/me';
    static const String logout = '/auth/logout';
    static const String changePassword = '/auth/change-password';

    // ═══════════════════════════════════════════════════
    // 👥 ПОЛЬЗОВАТЕЛИ
    // ═══════════════════════════════════════════════════
    static const String users = '/users';
    static String user(int id) => '/users/$id';
    static String approveUser(int id) => '/users/$id/approve';
    static String rejectUser(int id) => '/users/$id/reject';
    static const String pendingUsers = '/users/pending/list';
    static const String rolesList = '/users/roles/list';
    static String assignRole(int userId, int roleId) => '/users/$userId/roles/$roleId';

    // ═══════════════════════════════════════════════════
    // 💬 ЧАТЫ
    // ═══════════════════════════════════════════════════
    static const String chats = '/chats';
    static String chat(int id) => '/chats/$id';
    static String chatMembers(int id) => '/chats/$id/members';
    static String removeChatMember(int chatId, int userId) => '/chats/$chatId/members/$userId';
    static String privateChat(int userId) => '/chats/private/$userId';

    // ═══════════════════════════════════════════════════
    // 📝 СООБЩЕНИЯ
    // ═══════════════════════════════════════════════════
    static String messages(int chatId) => '/messages/$chatId';
    static String message(int id) => '/messages/$id';
    static String messageReactions(int id) => '/messages/$id/reactions';
    static String removeReaction(int messageId, String emoji) =>
        '/messages/$messageId/reactions/$emoji';
    static String markRead(int chatId) => '/messages/$chatId/read';
    // ═══════════════════════════════════════════════════
    // 📤 ЗАГРУЗКА ФАЙЛОВ
    // ═══════════════════════════════════════════════════
    static const String upload = '/upload';
}

// =====================================================
// 🎯 СОБЫТИЯ SOCKET.IO
// =====================================================
// Названия событий для реального времени.
// Должны совпадать с серверными (socket/handlers.js).
// =====================================================

class SocketEvents {
    // ═══════════════════════════════════════════════════
    // КЛИЕНТ → СЕРВЕР (отправляем)
    // ═══════════════════════════════════════════════════

    /// Присоединиться ко всем своим чатам
    static const String joinChats = 'join_chats';

    /// Печатает в чате
    static const String typing = 'typing';

    /// Перестал печатать
    static const String stopTyping = 'stop_typing';

    /// Отправить сообщение
    static const String sendMessage = 'send_message';

    /// Отметить как прочитанное
    static const String markRead = 'mark_read';

    // ═══════════════════════════════════════════════════
    // СЕРВЕР → КЛИЕНТ (получаем)
    // ═══════════════════════════════════════════════════

    /// Успешно присоединился к чатам
    static const String joinedChats = 'joined_chats';

    /// Новое сообщение
    static const String newMessage = 'new_message';

    /// Кто-то печатает
    static const String userTyping = 'user_typing';

    /// Кто-то перестал печатать
    static const String userStoppedTyping = 'user_stopped_typing';

    /// Пользователь онлайн
    static const String userOnline = 'user_online';

    /// Пользователь офлайн
    static const String userOffline = 'user_offline';

    /// Прочитано
    static const String messageRead = 'message_read';

    /// Сообщение отредактировано
    static const String messageEdited = 'message_edited';

    /// Сообщение удалено
    static const String messageDeleted = 'message_deleted';

    /// Добавлена реакция
    static const String reactionAdded = 'reaction_added';

    /// Удалена реакция
    static const String reactionRemoved = 'reaction_removed';

    /// Количество онлайн
    static const String onlineCount = 'online_count';

    /// Ошибка
    static const String error = 'error';
}

// =====================================================
// 💾 КЛЮЧИ ХРАНИЛИЩА (SharedPreferences)
// =====================================================
// Ключи для сохранения данных локально.
// =====================================================

class StorageKeys {
    /// JWT-токен авторизации
    static const String authToken = 'auth_token';

    /// Данные текущего пользователя (JSON)
    static const String currentUser = 'current_user';

    /// Последний открытый чат
    static const String lastChatId = 'last_chat_id';
}