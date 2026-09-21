// =====================================================
// 🌐 BMSChat — КОНСТАНТЫ ПРИЛОЖЕНИЯ
// =====================================================
// Здесь задаются базовые URL для API и WebSocket,
// таймауты, лимиты и другие константы.
//
// ⚠️ ВАЖНО: при смене сервера менять только:
//   • _prodUrl
//   • _localUrlAndroid (для теста на реальном телефоне)
//
// ⚠️ Backend (Node.js) — это ОТДЕЛЬНЫЙ сервер от Supabase.
// Supabase — это только база данных. Flutter общается
// с backend'ом, а backend — с Supabase.
//
// Схема:
//   Flutter → Backend (Node.js, облако) → Supabase (PostgreSQL)
// =====================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class Constants {
    // =====================================================
    // 🌍 БАЗОВЫЙ URL СЕРВЕРА
    // =====================================================
    // ⚠️ Backend развёрнут в облаке (Рег.облако).
    // Публичный IP: 194.226.123.103
    // Порт: 5000
    //
    // 🎯 APK подключается с любой сети (сотовая, Wi-Fi).
    // 🎯 Web на компьютере использует localhost:5000
    //     для локальной разработки.
    // =====================================================

    /// Продакшн — облачный backend на сервере Рег.облака.
    /// 🎯 Доступен из любой сети (сотовая, Wi-Fi).
    static const String _prodUrl = 'http://194.226.123.103:5000';

    /// Debug-сборка — тот же облачный backend.
    /// 🎯 Работает с любого телефона, в любой сети.
    static const String _localUrlAndroid = 'http://194.226.123.103:5000';

    /// Локальная разработка (iOS-симулятор / web)
    /// 🎯 Для web-тестирования на компьютере.
    static const String _localUrlDefault = 'http://localhost:5000';

    /// Автоматический выбор URL
    static String get baseUrl {
        if (kIsWeb) return _localUrlDefault;

        // В release-сборке всегда продакшн
        if (!kDebugMode) return _prodUrl;

        try {
            if (Platform.isAndroid) return _localUrlAndroid;
            if (Platform.isIOS) return _localUrlDefault;
        } catch (_) {
            // Platform недоступен — возвращаем продакшн
        }

        return _prodUrl;
    }

    /// Базовый URL API (с /api на конце)
    static String get apiUrl => '$baseUrl/api';

    /// URL для WebSocket (Socket.IO)
    static String get socketUrl => baseUrl;

    // =====================================================
    // ⏱️ ТАЙМАУТЫ
    // =====================================================
    static const Duration httpTimeout = Duration(seconds: 30);
    static const Duration socketTimeout = Duration(seconds: 20);
    static const Duration connectTimeout = Duration(seconds: 15);

    // =====================================================
    // 📦 ЛИМИТЫ
    // =====================================================
    static const int maxFileSize = 10 * 1024 * 1024; // 10 MB
    static const int maxMessageLength = 5000;
    static const int messagesPageSize = 50;
    static const int maxImageWidth = 1920;
    static const int maxImageHeight = 1920;
    static const int imageQuality = 85;

    // =====================================================
    // 🔐 АВТОРИЗАЦИЯ
    // =====================================================
    static const int minUsernameLength = 3;
    static const int maxUsernameLength = 30;
    static const int minPasswordLength = 6;
    static const int maxPasswordLength = 100;

    // =====================================================
    // 💬 ЧАТЫ
    // =====================================================
    static const String chatTypePrivate = 'private';
    static const String chatTypeGeneral = 'general';
    static const String chatTypeGroup = 'group';
    static const String chatTypeChannel = 'channel';

    // =====================================================
    // 📝 СООБЩЕНИЯ
    // =====================================================
    static const String messageTypeText = 'text';
    static const String messageTypeImage = 'image';
    static const String messageTypeVoice = 'voice';
    static const String messageTypeFile = 'file';

    // =====================================================
    // 🎭 РОЛИ
    // =====================================================
    static const String roleAdmin = 'Администратор';
    static const String roleCommander = 'Командир';
    static const String roleSoldier = 'Боец';
    static const String roleRecruit = 'Новобранец';

    // =====================================================
    // 🎨 UI
    // =====================================================
    static const Duration animationFast = Duration(milliseconds: 150);
    static const Duration animationNormal = Duration(milliseconds: 300);
    static const Duration animationSlow = Duration(milliseconds: 500);

    static const double paddingSmall = 8.0;
    static const double paddingMedium = 16.0;
    static const double paddingLarge = 24.0;

    static const double radiusSmall = 8.0;
    static const double radiusMedium = 12.0;
    static const double radiusLarge = 20.0;

    // =====================================================
    // 🔔 УВЕДОМЛЕНИЯ
    // =====================================================
    static const String channelIdMessages = 'messages_channel';
    static const String channelNameMessages = 'Сообщения';
    static const String channelDescriptionMessages = 'Уведомления о новых сообщениях';

    // =====================================================
    // 📋 ПРОЧЕЕ
    // =====================================================
    static const String appName = 'BMSChat';
    static const String appVersion = '1.0.0';
    static const String teamName = 'Отряд Боба Марли';
    static const String teamMotto = 'One Love! ✌️';

    // =====================================================
    // 🐞 ЛОГИРОВАНИЕ
    // =====================================================
    static bool get enableLogs => kDebugMode;
    static bool get verboseErrors => kDebugMode;

    // =====================================================
    // 📁 ФАЙЛЫ
    // =====================================================
    static String getFullFileUrl(String? filePath) {
        if (filePath == null || filePath.isEmpty) return '';
        if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
            return filePath;
        }
        final path = filePath.startsWith('/') ? filePath : '/$filePath';
        return '$baseUrl$path';
    }
}

// =====================================================
// 🌐 ЭНДПОИНТЫ API
// =====================================================
// ВАЖНО: не добавляй сюда /api — он уже в Constants.apiUrl
// =====================================================

class ApiEndpoints {
    // ─────────────────────────────────────────
    // 🔐 АВТОРИЗАЦИЯ
    // ─────────────────────────────────────────
    static const String login = '/auth/login';
    static const String register = '/auth/register';
    static const String logout = '/auth/logout';
    static const String me = '/auth/me';

    // ─────────────────────────────────────────
    // 👥 ПОЛЬЗОВАТЕЛИ
    // ─────────────────────────────────────────
    static const String users = '/users';
    static const String pendingUsers = '/users/pending/list';
    static String approveUser(int userId) => '/users/$userId/approve';
    static String rejectUser(int userId) => '/users/$userId/reject';
    static String user(int userId) => '/users/$userId';

    // ─────────────────────────────────────────
    // 🎭 УПРАВЛЕНИЕ РОЛЯМИ
    // ─────────────────────────────────────────
    static String assignCommander(int userId) =>
        '/users/$userId/assign-commander';
    static String removeCommander(int userId) =>
        '/users/$userId/remove-commander';
    static String makeRecruit(int userId) =>
        '/users/$userId/make-recruit';
    static String setRole(int userId) =>
        '/users/$userId/set-role';
    static const String rolesList = '/users/roles/list';

    // ─────────────────────────────────────────
    // 💬 ЧАТЫ
    // ─────────────────────────────────────────
    static const String chats = '/chats';
    static String chat(int chatId) => '/chats/$chatId';
    static String privateChat(int userId) => '/chats/private/$userId';
    static String chatMembers(int chatId) => '/chats/$chatId/members';
    static String markRead(int chatId) => '/chats/$chatId/read';

    // ─────────────────────────────────────────
    // 📝 СООБЩЕНИЯ
    // ─────────────────────────────────────────
    static String messages(int chatId) => '/messages/$chatId';
    static String message(int messageId) => '/messages/$messageId';
    static String messageReactions(int messageId) =>
        '/messages/$messageId/reactions';
    static String removeReaction(int messageId, String emoji) =>
        '/messages/$messageId/reactions/$emoji';

    // ─────────────────────────────────────────
    // 📤 ЗАГРУЗКА
    // ─────────────────────────────────────────
    static const String upload = '/upload';

    // ─────────────────────────────────────────
    // 🩺 HEALTH
    // ─────────────────────────────────────────
    static const String health = '/health';
}

// =====================================================
// 💾 КЛЮЧИ ХРАНИЛИЩА (SharedPreferences)
// =====================================================

class StorageKeys {
    static const String token = 'auth_token';
    static const String userId = 'user_id';
    static const String username = 'username';
    static const String displayName = 'display_name';
    static const String userJson = 'user_json';
    static const String lastChatId = 'last_chat_id';
    static const String theme = 'app_theme';
    static const String locale = 'app_locale';

    static const String authToken = token;
    static const String currentUser = userJson;
}

// =====================================================
// 🔌 СОБЫТИЯ SOCKET.IO
// =====================================================

class SocketEvents {
    // 📥 ВХОДЯЩИЕ (сервер → клиент)
    static const String newMessage = 'new_message';
    static const String userTyping = 'user_typing';
    static const String userStoppedTyping = 'user_stopped_typing';
    static const String userOnline = 'user_online';
    static const String userOffline = 'user_offline';
    static const String messageRead = 'message_read';
    static const String onlineCount = 'online_count';
    static const String joinedChats = 'joined_chats';
    static const String error = 'error';

    // 📥 ЗАПЛАНИРОВАННЫЕ
    static const String messageEdited = 'message_edited';
    static const String messageDeleted = 'message_deleted';
    static const String reactionAdded = 'reaction_added';
    static const String reactionRemoved = 'reaction_removed';

    // 👑 ЗАЯВКИ
    static const String newRecruit = 'new_recruit';
    static const String pendingCount = 'pending_count';

    // 📤 ИСХОДЯЩИЕ (клиент → сервер)
    static const String joinChats = 'join_chats';
    static const String joinAdmins = 'join_admins';
    static const String typing = 'typing';
    static const String stopTyping = 'stop_typing';
    static const String sendMessage = 'send_message';
    static const String markRead = 'mark_read';
}