// =====================================================
// 🌐 BMSChat — СЕРВИС API
// =====================================================
// 🎯 ШАГ 8: методы для управления каналами
// 🎯 FIX (web upload): MultipartFile.fromBytes вместо fromPath
// 🎯 ПРОФИЛЬ: updateProfile() + _patch()
// 🎯 FCM: sendFcmToken() + deleteFcmToken()
// 🎯 MUTE: muteChat() + unmuteChat()
// 🎯 ПОИСК: searchMessages() — поиск по сообщениям в чате
// 🎯 CLEAR: clearChatHistory() — soft-delete истории чата
// 🎯 ПОЛЛЫ: createPoll / getPoll / votePoll / unvotePoll / closePoll
// 🎯 ПИНЫ: pinMessage / unpinMessage — закреплённое сообщение
// =====================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/constants.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/poll.dart';
import '../utils/app_logger.dart';
import 'storage_service.dart';

// =====================================================
// 📦 УНИВЕРСАЛЬНЫЙ ОТВЕТ API
// =====================================================
class ApiResponse<T> {
    final bool isSuccess;
    final T? data;
    final String? error;
    final int statusCode;

    const ApiResponse._({
        required this.isSuccess,
        this.data,
        this.error,
        required this.statusCode,
    });

    factory ApiResponse.success(T data, {int statusCode = 200}) {
        return ApiResponse._(
            isSuccess: true,
            data: data,
            statusCode: statusCode,
        );
    }

    factory ApiResponse.error(String message, {int statusCode = 500}) {
        return ApiResponse._(
            isSuccess: false,
            error: message,
            statusCode: statusCode,
        );
    }
}

// =====================================================
// 📦 РЕЗУЛЬТАТ ЗАГРУЗКИ СООБЩЕНИЙ
// =====================================================
class MessagesResponse {
    final List<Message> messages;
    final bool hasMore;
    final int maxReadId;
    final int myLastReadId;

    const MessagesResponse({
        required this.messages,
        this.hasMore = false,
        this.maxReadId = 0,
        this.myLastReadId = 0,
    });
}

// =====================================================
// 📦 РЕЗУЛЬТАТ ПОИСКА СООБЩЕНИЙ
// =====================================================
class SearchResponse {
    final List<Message> messages;
    final bool hasMore;
    final String query;

    const SearchResponse({
        required this.messages,
        this.hasMore = false,
        this.query = '',
    });
}

// =====================================================
// 🌐 СЕРВИС API
// =====================================================
class ApiService {
    // =====================================================
    // 🔧 БАЗОВЫЕ МЕТОДЫ
    // =====================================================

    static Future<Map<String, String>> _headers({bool withAuth = true}) async {
        final headers = <String, String>{
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
        };

        if (withAuth) {
            final token = await StorageService.getToken();
            if (token != null && token.isNotEmpty) {
                headers['Authorization'] = 'Bearer $token';
            }
        }

        return headers;
    }

    static Future<ApiResponse<dynamic>> _get(
        String endpoint, {
        bool withAuth = true,
    }) async {
        try {
            final url = '${Constants.apiUrl}$endpoint';
            AppLogger.http('GET', url);

            final response = await http
                .get(Uri.parse(url), headers: await _headers(withAuth: withAuth))
                .timeout(Constants.httpTimeout);

            return _handleResponse(response);
        } on TimeoutException {
            AppLogger.error('Таймаут GET $endpoint');
            return ApiResponse.error('Сервер не отвечает', statusCode: 408);
        } on SocketException {
            return ApiResponse.error('Нет соединения с сервером', statusCode: 503);
        } catch (e) {
            AppLogger.error('Ошибка GET $endpoint', e);
            return ApiResponse.error('Ошибка сети: $e');
        }
    }

    static Future<ApiResponse<dynamic>> _post(
        String endpoint, {
        Map<String, dynamic>? body,
        bool withAuth = true,
    }) async {
        try {
            final url = '${Constants.apiUrl}$endpoint';
            AppLogger.http('POST', url, data: body != null ? '${body.keys}' : null);

            final response = await http
                .post(
                    Uri.parse(url),
                    headers: await _headers(withAuth: withAuth),
                    body: body != null ? jsonEncode(body) : null,
                )
                .timeout(Constants.httpTimeout);

            return _handleResponse(response);
        } on TimeoutException {
            return ApiResponse.error('Сервер не отвечает', statusCode: 408);
        } on SocketException {
            return ApiResponse.error('Нет соединения с сервером', statusCode: 503);
        } catch (e) {
            AppLogger.error('Ошибка POST $endpoint', e);
            return ApiResponse.error('Ошибка сети: $e');
        }
    }

    static Future<ApiResponse<dynamic>> _put(
        String endpoint, {
        Map<String, dynamic>? body,
    }) async {
        try {
            final url = '${Constants.apiUrl}$endpoint';
            AppLogger.http('PUT', url);

            final response = await http
                .put(
                    Uri.parse(url),
                    headers: await _headers(),
                    body: body != null ? jsonEncode(body) : null,
                )
                .timeout(Constants.httpTimeout);

            return _handleResponse(response);
        } catch (e) {
            AppLogger.error('Ошибка PUT $endpoint', e);
            return ApiResponse.error('Ошибка сети: $e');
        }
    }

    static Future<ApiResponse<dynamic>> _patch(
        String endpoint, {
        Map<String, dynamic>? body,
    }) async {
        try {
            final url = '${Constants.apiUrl}$endpoint';
            AppLogger.http('PATCH', url);

            final response = await http
                .patch(
                    Uri.parse(url),
                    headers: await _headers(),
                    body: body != null ? jsonEncode(body) : null,
                )
                .timeout(Constants.httpTimeout);

            return _handleResponse(response);
        } catch (e) {
            AppLogger.error('Ошибка PATCH $endpoint', e);
            return ApiResponse.error('Ошибка сети: $e');
        }
    }

    static Future<ApiResponse<dynamic>> _delete(String endpoint) async {
        try {
            final url = '${Constants.apiUrl}$endpoint';
            AppLogger.http('DELETE', url);

            final response = await http
                .delete(Uri.parse(url), headers: await _headers())
                .timeout(Constants.httpTimeout);

            return _handleResponse(response);
        } catch (e) {
            AppLogger.error('Ошибка DELETE $endpoint', e);
            return ApiResponse.error('Ошибка сети: $e');
        }
    }

    static ApiResponse<dynamic> _handleResponse(http.Response response) {
        AppLogger.http('←', '${response.statusCode}',
            statusCode: response.statusCode);

        dynamic data;
        try {
            if (response.body.isNotEmpty) {
                data = jsonDecode(utf8.decode(response.bodyBytes));
            }
        } catch (e) {
            AppLogger.error('Ошибка парсинга JSON', e);
            return ApiResponse.error('Ошибка парсинга ответа',
                statusCode: response.statusCode);
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
            return ApiResponse.success(data, statusCode: response.statusCode);
        }

        String errorMessage = 'Ошибка ${response.statusCode}';
        if (data is Map) {
            errorMessage = data['error'] as String? ??
                data['message'] as String? ??
                errorMessage;
        }

        return ApiResponse.error(errorMessage, statusCode: response.statusCode);
    }

    // =====================================================
    // 🔐 АВТОРИЗАЦИЯ
    // =====================================================

    static Future<ApiResponse<Map<String, dynamic>>> login(
        String username,
        String password,
    ) async {
        final response = await _post(
            ApiEndpoints.login,
            body: {'username': username, 'password': password},
            withAuth: false,
        );

        if (response.isSuccess) {
            return ApiResponse.success(
                response.data as Map<String, dynamic>,
                statusCode: response.statusCode,
            );
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<Map<String, dynamic>>> register(
        String username,
        String password,
        String displayName,
    ) async {
        final response = await _post(
            ApiEndpoints.register,
            body: {
                'username': username,
                'password': password,
                'display_name': displayName,
            },
            withAuth: false,
        );

        if (response.isSuccess) {
            return ApiResponse.success(
                response.data as Map<String, dynamic>,
                statusCode: response.statusCode,
            );
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<User>> getMe() async {
        final response = await _get(ApiEndpoints.me);

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final userJson = data['user'] as Map<String, dynamic>;
            return ApiResponse.success(User.fromJson(userJson));
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> logout() async {
        final response = await _post(ApiEndpoints.logout);
        await StorageService.clearAll();

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 👤 ОБНОВЛЕНИЕ ПРОФИЛЯ
    // =====================================================
    static Future<ApiResponse<User>> updateProfile({
        String? displayName,
        String? avatar,
    }) async {
        final body = <String, dynamic>{};
        if (displayName != null) body['display_name'] = displayName;
        if (avatar != null) body['avatar'] = avatar;

        if (body.isEmpty) {
            return ApiResponse.error('Нечего обновлять', statusCode: 400);
        }

        final response = await _patch('/users/me', body: body);

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final userJson = data['user'] as Map<String, dynamic>;
            return ApiResponse.success(User.fromJson(userJson));
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 🔔 ОТПРАВКА FCM-ТОКЕНА НА СЕРВЕР
    // =====================================================
    static Future<ApiResponse<void>> sendFcmToken(String token) async {
        if (token.isEmpty) {
            return ApiResponse.error('Пустой FCM-токен', statusCode: 400);
        }

        final response = await _post(
            '/users/me/fcm-token',
            body: {'token': token},
        );

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 🔕 УДАЛЕНИЕ FCM-ТОКЕНА НА СЕРВЕРЕ
    // =====================================================
    static Future<ApiResponse<void>> deleteFcmToken() async {
        final response = await _delete('/users/me/fcm-token');

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 👥 ПОЛЬЗОВАТЕЛИ
    // =====================================================

    static Future<ApiResponse<List<User>>> getUsers() async {
        final response = await _get(ApiEndpoints.users);

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final usersJson = data['users'] as List<dynamic>;
            final users = usersJson
                .map((u) => User.fromJson(u as Map<String, dynamic>))
                .toList();
            return ApiResponse.success(users);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<User>> getUser(int userId) async {
        final response = await _get(ApiEndpoints.user(userId));

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final userJson = data['user'] as Map<String, dynamic>;
            return ApiResponse.success(User.fromJson(userJson));
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<List<User>>> getPendingUsers() async {
        final response = await _get(ApiEndpoints.pendingUsers);

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final usersJson = data['pending'] as List<dynamic>? ?? [];
            final users = usersJson
                .map((u) => User.fromJson(u as Map<String, dynamic>))
                .toList();
            return ApiResponse.success(users);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> approveUser(int userId) async {
        final response = await _post(ApiEndpoints.approveUser(userId));

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> rejectUser(int userId) async {
        final response = await _post(ApiEndpoints.rejectUser(userId));

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> assignCommander(int userId) async {
        final response = await _post(ApiEndpoints.assignCommander(userId));

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> removeCommander(int userId) async {
        final response = await _post(ApiEndpoints.removeCommander(userId));

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> makeRecruit(int userId) async {
        final response = await _post(ApiEndpoints.makeRecruit(userId));

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> setRole(int userId, String roleName) async {
        final response = await _post(
            ApiEndpoints.setRole(userId),
            body: {'roleName': roleName},
        );

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<List<dynamic>>> getRoles() async {
        final response = await _get(ApiEndpoints.rolesList);

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final roles = data['roles'] as List<dynamic>? ?? [];
            return ApiResponse.success(roles);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 💬 ЧАТЫ
    // =====================================================

    static Future<ApiResponse<List<Chat>>> getChats() async {
        final response = await _get(ApiEndpoints.chats);

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final chatsJson = data['chats'] as List<dynamic>;
            final chats = chatsJson
                .map((c) => Chat.fromJson(c as Map<String, dynamic>))
                .toList();
            return ApiResponse.success(chats);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<Map<String, dynamic>>> getChat(int chatId) async {
        final response = await _get(ApiEndpoints.chat(chatId));

        if (response.isSuccess) {
            return ApiResponse.success(response.data as Map<String, dynamic>);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<Map<String, dynamic>>> createPrivateChat(int userId) async {
        final response = await _post(ApiEndpoints.privateChat(userId));

        if (response.isSuccess) {
            return ApiResponse.success(response.data as Map<String, dynamic>);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<Map<String, dynamic>>> createChat({
        required String type,
        required String name,
        String? description,
        bool isPrivate = false,
        String? emoji,
        List<int>? members,
    }) async {
        final response = await _post(
            ApiEndpoints.chats,
            body: {
                'type': type,
                'name': name,
                if (description != null) 'description': description,
                'isPrivate': isPrivate,
                if (emoji != null) 'emoji': emoji,
                if (members != null) 'members': members,
            },
        );

        if (response.isSuccess) {
            return ApiResponse.success(response.data as Map<String, dynamic>);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> updateChat(
        int chatId, {
        String? name,
        String? description,
        String? emoji,
        bool? isPrivate,
    }) async {
        final response = await _put(
            ApiEndpoints.chat(chatId),
            body: {
                if (name != null) 'name': name,
                if (description != null) 'description': description,
                if (emoji != null) 'emoji': emoji,
                if (isPrivate != null) 'isPrivate': isPrivate,
            },
        );

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> deleteChat(int chatId) async {
        final response = await _delete(ApiEndpoints.chat(chatId));

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> joinChannel(int chatId) async {
        final response = await _post('${ApiEndpoints.chat(chatId)}/join');

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<Map<String, dynamic>>> addChatMembersBulk(
        int chatId,
        List<int> userIds,
    ) async {
        final response = await _post(
            '${ApiEndpoints.chat(chatId)}/members/bulk',
            body: {'userIds': userIds},
        );

        if (response.isSuccess) {
            return ApiResponse.success(response.data as Map<String, dynamic>);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> removeChatMember(
        int chatId,
        int userId,
    ) async {
        final response = await _delete(
            '${ApiEndpoints.chat(chatId)}/members/$userId',
        );

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 🔕 MUTE УВЕДОМЛЕНИЙ ПО ЧАТУ
    // =====================================================
    static Future<ApiResponse<void>> muteChat(int chatId) async {
        final response = await _post('/chats/$chatId/mute');

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 🔔 UNMUTE УВЕДОМЛЕНИЙ ПО ЧАТУ
    // =====================================================
    static Future<ApiResponse<void>> unmuteChat(int chatId) async {
        final response = await _delete('/chats/$chatId/mute');

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 📌 ЗАКРЕПЛЁННЫЕ СООБЩЕНИЯ
    // =====================================================

    /// Закрепить сообщение в чате.
    /// POST /api/chats/:chatId/pin
    /// Возвращает id закреплённого сообщения.
    static Future<ApiResponse<int>> pinMessage(
        int chatId,
        int messageId,
    ) async {
        final response = await _post(
            '/chats/$chatId/pin',
            body: {'message_id': messageId},
        );

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>?;
            final pinnedId =
                data?['pinned_message_id'] as int? ?? messageId;
            return ApiResponse.success(pinnedId);
        }

        return ApiResponse.error(
            response.error!,
            statusCode: response.statusCode,
        );
    }

    /// Открепить сообщение.
    /// DELETE /api/chats/:chatId/pin
    static Future<ApiResponse<void>> unpinMessage(int chatId) async {
        final response = await _delete('/chats/$chatId/pin');

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }

        return ApiResponse.error(
            response.error!,
            statusCode: response.statusCode,
        );
    }

    // =====================================================
    // 📝 СООБЩЕНИЯ
    // =====================================================

    static Future<ApiResponse<MessagesResponse>> getMessages(
        int chatId, {
        int limit = 50,
        int? before,
    }) async {
        String endpoint = '${ApiEndpoints.messages(chatId)}?limit=$limit';
        if (before != null) {
            endpoint += '&before=$before';
        }

        final response = await _get(endpoint);

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final messagesJson = data['messages'] as List<dynamic>;
            final messages = messagesJson
                .map((m) => Message.fromJson(m as Map<String, dynamic>))
                .toList();

            return ApiResponse.success(MessagesResponse(
                messages: messages,
                hasMore: data['hasMore'] as bool? ?? false,
                maxReadId: data['maxReadId'] as int? ?? 0,
                myLastReadId: data['myLastReadId'] as int? ?? 0,
            ));
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 🔎 ПОИСК СООБЩЕНИЙ В ЧАТЕ
    // =====================================================
    static Future<ApiResponse<SearchResponse>> searchMessages(
        int chatId,
        String query, {
        int limit = 30,
        int? before,
    }) async {
        final trimmed = query.trim();
        if (trimmed.length < 2) {
            return ApiResponse.error('Минимум 2 символа для поиска',
                statusCode: 400);
        }

        String endpoint =
            '${ApiEndpoints.messages(chatId)}/search?q=${Uri.encodeQueryComponent(trimmed)}&limit=$limit';
        if (before != null) {
            endpoint += '&before=$before';
        }

        final response = await _get(endpoint);

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final messagesJson = data['messages'] as List<dynamic>? ?? [];
            final messages = messagesJson
                .map((m) => Message.fromJson(m as Map<String, dynamic>))
                .toList();

            return ApiResponse.success(SearchResponse(
                messages: messages,
                hasMore: data['hasMore'] as bool? ?? false,
                query: data['query'] as String? ?? trimmed,
            ));
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 🧹 ОЧИСТКА ИСТОРИИ ЧАТА (soft-delete)
    // =====================================================
    static Future<ApiResponse<int>> clearChatHistory(int chatId) async {
        final response = await _post('/chats/$chatId/clear');

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>?;
            final cleared = data?['cleared'] as int? ?? 0;
            return ApiResponse.success(cleared);
        }

        return ApiResponse.error(
            response.error!,
            statusCode: response.statusCode,
        );
    }

    static Future<ApiResponse<Message>> sendMessage(
        int chatId,
        String text, {
        int? replyToId,
    }) async {
        final response = await _post(
            ApiEndpoints.messages(chatId),
            body: {
                'text': text,
                if (replyToId != null) 'reply_to_id': replyToId,
            },
        );

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final messageJson = data['data'] as Map<String, dynamic>;
            return ApiResponse.success(Message.fromJson(messageJson));
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> editMessage(int messageId, String text) async {
        final response = await _put(
            ApiEndpoints.message(messageId),
            body: {'text': text},
        );

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> deleteMessage(int messageId) async {
        final response = await _delete(ApiEndpoints.message(messageId));

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> markChatRead(int chatId, int messageId) async {
        final response = await _post(
            ApiEndpoints.markRead(chatId),
            body: {'messageId': messageId},
        );

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 😀 РЕАКЦИИ
    // =====================================================

    static Future<ApiResponse<void>> addReaction(int messageId, String emoji) async {
        final response = await _post(
            ApiEndpoints.messageReactions(messageId),
            body: {'emoji': emoji},
        );

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    static Future<ApiResponse<void>> removeReaction(int messageId, String emoji) async {
        final encodedEmoji = Uri.encodeComponent(emoji);
        final response = await _delete(
            ApiEndpoints.removeReaction(messageId, encodedEmoji),
        );

        if (response.isSuccess) {
            return ApiResponse.success(null);
        }
        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 📊 ГОЛОСОВАНИЯ
    // =====================================================

    /// Создать голосование в чате.
    /// POST /api/chats/:chatId/polls
    static Future<ApiResponse<Poll>> createPoll(
        int chatId, {
        required String question,
        required List<String> options,
        bool isMultiple = false,
        bool isAnonymous = false,
    }) async {
        final response = await _post(
            '/chats/$chatId/polls',
            body: {
                'question': question,
                'options': options,
                'is_multiple': isMultiple,
                'is_anonymous': isAnonymous,
            },
        );

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final pollJson = data['poll'] as Map<String, dynamic>?;
            if (pollJson == null) {
                return ApiResponse.error('Некорректный ответ сервера',
                    statusCode: response.statusCode);
            }
            return ApiResponse.success(
                Poll.fromJson(pollJson),
                statusCode: response.statusCode,
            );
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    /// Получить голосование с результатами.
    /// GET /api/polls/:id
    static Future<ApiResponse<Poll>> getPoll(int pollId) async {
        final response = await _get('/polls/$pollId');

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final pollJson = data['poll'] as Map<String, dynamic>?;
            if (pollJson == null) {
                return ApiResponse.error('Некорректный ответ сервера',
                    statusCode: response.statusCode);
            }
            return ApiResponse.success(Poll.fromJson(pollJson));
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    /// Проголосовать.
    /// POST /api/polls/:id/vote
    /// [optionIds] — массив, даже если один вариант.
    static Future<ApiResponse<Poll>> votePoll(
        int pollId,
        List<int> optionIds,
    ) async {
        final response = await _post(
            '/polls/$pollId/vote',
            body: {'option_ids': optionIds},
        );

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final pollJson = data['poll'] as Map<String, dynamic>?;
            if (pollJson == null) {
                return ApiResponse.error('Некорректный ответ сервера',
                    statusCode: response.statusCode);
            }
            return ApiResponse.success(Poll.fromJson(pollJson));
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    /// Убрать свой голос.
    /// DELETE /api/polls/:id/vote
    static Future<ApiResponse<Poll>> unvotePoll(int pollId) async {
        final response = await _delete('/polls/$pollId/vote');

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final pollJson = data['poll'] as Map<String, dynamic>?;
            if (pollJson == null) {
                return ApiResponse.error('Некорректный ответ сервера',
                    statusCode: response.statusCode);
            }
            return ApiResponse.success(Poll.fromJson(pollJson));
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    /// Закрыть голосование.
    /// POST /api/polls/:id/close
    static Future<ApiResponse<Poll>> closePoll(int pollId) async {
        final response = await _post('/polls/$pollId/close');

        if (response.isSuccess) {
            final data = response.data as Map<String, dynamic>;
            final pollJson = data['poll'] as Map<String, dynamic>?;
            if (pollJson == null) {
                return ApiResponse.error('Некорректный ответ сервера',
                    statusCode: response.statusCode);
            }
            return ApiResponse.success(Poll.fromJson(pollJson));
        }

        return ApiResponse.error(response.error!, statusCode: response.statusCode);
    }

    // =====================================================
    // 📤 ЗАГРУЗКА ФАЙЛОВ
    // =====================================================

    static Future<ApiResponse<Map<String, dynamic>>> uploadFile(
        XFile file,
        String type,
    ) async {
        try {
            final url = '${Constants.apiUrl}${ApiEndpoints.upload}';
            AppLogger.http('POST', url, data: {'type': type});

            final request = http.MultipartRequest('POST', Uri.parse(url));

            final token = await StorageService.getToken();
            if (token != null && token.isNotEmpty) {
                request.headers['Authorization'] = 'Bearer $token';
            }

            final bytes = await file.readAsBytes();

            request.files.add(
                http.MultipartFile.fromBytes(
                    'file',
                    bytes,
                    filename: file.name,
                ),
            );

            request.fields['type'] = type;

            final streamedResponse = await request.send().timeout(
                const Duration(seconds: 60),
            );
            final response = await http.Response.fromStream(streamedResponse);

            AppLogger.http('←', '${response.statusCode}',
                statusCode: response.statusCode);

            dynamic data;
            try {
                if (response.body.isNotEmpty) {
                    data = jsonDecode(utf8.decode(response.bodyBytes));
                }
            } catch (e) {
                AppLogger.error('Ошибка парсинга ответа upload', e);
                return ApiResponse.error('Ошибка парсинга ответа',
                    statusCode: response.statusCode);
            }

            if (response.statusCode >= 200 && response.statusCode < 300) {
                return ApiResponse.success(
                    data as Map<String, dynamic>,
                    statusCode: response.statusCode,
                );
            }

            String errorMessage = 'Ошибка ${response.statusCode}';
            if (data is Map) {
                errorMessage = data['error'] as String? ??
                    data['message'] as String? ??
                    errorMessage;
            }

            return ApiResponse.error(errorMessage,
                statusCode: response.statusCode);
        } on TimeoutException {
            AppLogger.error('Таймаут загрузки файла');
            return ApiResponse.error('Сервер не отвечает (таймаут)',
                statusCode: 408);
        } catch (e) {
            AppLogger.error('Ошибка загрузки файла', e);
            return ApiResponse.error('Ошибка загрузки: $e');
        }
    }

    // =====================================================
    // 🩺 ПРОВЕРКА СОЕДИНЕНИЯ
    // =====================================================

    static Future<bool> ping() async {
        try {
            final url = '${Constants.baseUrl}/api/health';
            final response = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 5));
            return response.statusCode == 200;
        } catch (e) {
            AppLogger.error('Ping ошибка', e);
            return false;
        }
    }
}