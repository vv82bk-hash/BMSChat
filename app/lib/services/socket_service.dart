// =====================================================
// 🔌 BMSChat — СЕРВИС SOCKET.IO
// =====================================================
// WebSocket для реального времени:
//   • «Печатает...»
//   • Новые сообщения (мгновенно)
//   • Онлайн-статусы
//   • Галочки прочтения
//   • Реакции, редактирование, удаление
//
// ИСПОЛЬЗОВАНИЕ:
//   await SocketService.connect(token);
//   SocketService.onNewMessage.listen((msg) { ... });
//   SocketService.sendTyping(chatId);
// =====================================================

import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/constants.dart';
import '../utils/app_logger.dart';

// =====================================================
// 📊 СТАТУС ПОДКЛЮЧЕНИЯ
// =====================================================

enum SocketStatus {
    disconnected,   // Не подключён
    connecting,     // Подключается
    connected,      // Подключён
    error,          // Ошибка
}

// =====================================================
// 🔌 СЕРВИС SOCKET.IO
// =====================================================

class SocketService {
    // =====================================================
    // 🔧 СОСТОЯНИЕ
    // =====================================================

    static io.Socket? _socket;
    static SocketStatus _status = SocketStatus.disconnected;
    static String? _authToken;

    /// Текущий статус подключения
    static SocketStatus get status => _status;

    /// Подключён?
    static bool get isConnected => _status == SocketStatus.connected;

    /// Текущий токен (для отладки)
    static String? get authToken => _authToken;

    // =====================================================
    // 📡 STREAMS (потоки событий)
    // =====================================================
    // UI подписывается на эти потоки через StreamBuilder
    // или .listen()

    /// Статус подключения
    static final _statusController = StreamController<SocketStatus>.broadcast();
    static Stream<SocketStatus> get onStatusChange => _statusController.stream;

    /// Новое сообщение
    static final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

    /// Кто-то печатает: { chatId, userId, displayName }
    static final _userTypingController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

    /// Кто-то перестал печатать: { chatId, userId }
    static final _userStoppedTypingController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onUserStoppedTyping => _userStoppedTypingController.stream;

    /// Пользователь онлайн: { userId, displayName }
    static final _userOnlineController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onUserOnline => _userOnlineController.stream;

    /// Пользователь офлайн: { userId, lastSeen }
    static final _userOfflineController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onUserOffline => _userOfflineController.stream;

    /// Сообщение прочитано: { chatId, userId, messageId }
    static final _messageReadController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onMessageRead => _messageReadController.stream;

    /// Сообщение отредактировано: { messageId, chatId, text }
    static final _messageEditedController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onMessageEdited => _messageEditedController.stream;

    /// Сообщение удалено: { messageId, chatId }
    static final _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;

    /// Реакция добавлена: { messageId, chatId, userId, emoji }
    static final _reactionAddedController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onReactionAdded => _reactionAddedController.stream;

    /// Реакция удалена: { messageId, chatId, userId, emoji }
    static final _reactionRemovedController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onReactionRemoved => _reactionRemovedController.stream;

    /// Количество онлайн: int
    static final _onlineCountController = StreamController<int>.broadcast();
    static Stream<int> get onOnlineCount => _onlineCountController.stream;

    /// Ошибка от сервера: { message }
    static final _errorController = StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onError => _errorController.stream;

    // =====================================================
    // 🔌 ПОДКЛЮЧЕНИЕ
    // =====================================================

    /// Подключиться к серверу
    static Future<bool> connect(String token) async {
        // Отключаемся от предыдущего соединения
        if (_socket != null) {
            disconnect();
        }

        _authToken = token;
        _setStatus(SocketStatus.connecting);

        AppLogger.socket('Подключение к ${Constants.socketUrl}');

        try {
            _socket = io.io(
                Constants.socketUrl,
                io.OptionBuilder()
                    .setTransports(['websocket'])
                    .setAuth({'token': token})
                    .enableForceNew()
                    .enableReconnection()
                    .setReconnectionAttempts(5)
                    .setReconnectionDelay(1000)
                    .build(),
            );

            _registerHandlers();

            return true;
        } catch (e) {
            AppLogger.error('Ошибка подключения Socket', e);
            _setStatus(SocketStatus.error);
            return false;
        }
    }

    /// Отключиться от сервера
    static void disconnect() {
        AppLogger.socket('Отключение Socket');

        _socket?.disconnect();
        _socket?.dispose();
        _socket = null;
        _authToken = null;
        _setStatus(SocketStatus.disconnected);
    }

    // =====================================================
    // 🎯 РЕГИСТРАЦИЯ ОБРАБОТЧИКОВ
    // =====================================================

    static void _registerHandlers() {
        if (_socket == null) return;

        // ─────────────────────────────────────────
        // ✅ Подключён
        // ─────────────────────────────────────────
        _socket!.onConnect((_) {
            AppLogger.success('Socket подключён: ${_socket!.id}');
            _setStatus(SocketStatus.connected);

            // Присоединяемся ко всем чатам
            _socket!.emit(SocketEvents.joinChats);
        });

        // ─────────────────────────────────────────
        // ❌ Ошибка подключения
        // ─────────────────────────────────────────
        _socket!.onConnectError((error) {
            AppLogger.error('Socket ошибка подключения', error);
            _setStatus(SocketStatus.error);
        });

        // ─────────────────────────────────────────
        // 🔌 Отключён
        // ─────────────────────────────────────────
        _socket!.onDisconnect((reason) {
            AppLogger.socket('Socket отключён: $reason');
            _setStatus(SocketStatus.disconnected);
        });

        // ─────────────────────────────────────────
        // 📥 Присоединился к чатам
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.joinedChats, (data) {
            AppLogger.socket('Присоединился к чатам', data);
        });

        // ─────────────────────────────────────────
        // 📨 Новое сообщение
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.newMessage, (data) {
            if (data is Map) {
                AppLogger.socket('📨 Новое сообщение', data['id']);
                _newMessageController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // ⌨️ Кто-то печатает
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.userTyping, (data) {
            if (data is Map) {
                _userTypingController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // ⏹️ Перестал печатать
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.userStoppedTyping, (data) {
            if (data is Map) {
                _userStoppedTypingController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // 🟢 Пользователь онлайн
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.userOnline, (data) {
            if (data is Map) {
                _userOnlineController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // ⚫ Пользователь офлайн
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.userOffline, (data) {
            if (data is Map) {
                _userOfflineController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // ✓✓ Сообщение прочитано
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.messageRead, (data) {
            if (data is Map) {
                _messageReadController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // ✏️ Сообщение отредактировано
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.messageEdited, (data) {
            if (data is Map) {
                _messageEditedController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // 🗑️ Сообщение удалено
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.messageDeleted, (data) {
            if (data is Map) {
                _messageDeletedController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // 😀 Реакция добавлена
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.reactionAdded, (data) {
            if (data is Map) {
                _reactionAddedController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // 🗑️ Реакция удалена
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.reactionRemoved, (data) {
            if (data is Map) {
                _reactionRemovedController.add(Map<String, dynamic>.from(data));
            }
        });

        // ─────────────────────────────────────────
        // 📊 Количество онлайн
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.onlineCount, (count) {
            if (count is int) {
                _onlineCountController.add(count);
            }
        });

        // ─────────────────────────────────────────
        // ❌ Ошибка от сервера
        // ─────────────────────────────────────────
        _socket!.on(SocketEvents.error, (data) {
            if (data is Map) {
                AppLogger.warn('Socket ошибка от сервера', data);
                _errorController.add(Map<String, dynamic>.from(data));
            }
        });
    }

    // =====================================================
    // 📤 ОТПРАВКА СОБЫТИЙ
    // =====================================================

    /// Присоединиться ко всем чатам
    static void joinChats() {
        _socket?.emit(SocketEvents.joinChats);
    }

    /// Отправить «печатает...»
    static void sendTyping(int chatId) {
        if (!isConnected) return;
        _socket?.emit(SocketEvents.typing, {'chatId': chatId});
    }

    /// Отправить «перестал печатать»
    static void sendStopTyping(int chatId) {
        if (!isConnected) return;
        _socket?.emit(SocketEvents.stopTyping, {'chatId': chatId});
    }

    /// Отправить сообщение через Socket.IO
    static void sendMessage({
        required int chatId,
        required String text,
        int? replyToId,
        int? tempId,
    }) {
        if (!isConnected) {
            AppLogger.warn('Socket не подключён — сообщение не отправлено');
            return;
        }

        _socket?.emit(SocketEvents.sendMessage, {
            'chatId': chatId,
            'text': text,
            if (replyToId != null) 'replyToId': replyToId,
            if (tempId != null) 'tempId': tempId,
        });
    }

    /// Отметить чат как прочитанный
    static void markRead(int chatId, int messageId) {
        if (!isConnected) return;
        _socket?.emit(SocketEvents.markRead, {
            'chatId': chatId,
            'messageId': messageId,
        });
    }

    // =====================================================
    // 🛠️ ВСПОМОГАТЕЛЬНЫЕ
    // =====================================================

    static void _setStatus(SocketStatus status) {
        _status = status;
        if (!_statusController.isClosed) {
            _statusController.add(status);
        }
    }

    /// Очистить все потоки (при выходе из аккаунта)
    static Future<void> disposeAll() async {
        disconnect();

        // Не закрываем StreamController — они ещё могут понадобиться
        // Просто отключаемся от сокета
    }
}