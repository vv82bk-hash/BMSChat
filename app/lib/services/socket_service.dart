// =====================================================
// 🔌 BMSChat — СЕРВИС SOCKET.IO
// =====================================================
// WebSocket для реального времени:
//   • «Печатает...»
//   • Новые сообщения (мгновенно)
//   • Онлайн-статусы
//   • Галочки прочтения
//   • Реакции, редактирование, удаление
//   • 👑 Уведомления о новых новобранцах
// 🎯 FIX: transports ['websocket', 'polling'] — fallback для мобильных.
// =====================================================

import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/constants.dart';
import '../utils/app_logger.dart';

// =====================================================
// 📊 СТАТУС ПОДКЛЮЧЕНИЯ
// =====================================================

enum SocketStatus {
    disconnected,
    connecting,
    connected,
    error,
}

// =====================================================
// 🔌 СЕРВИС SOCKET.IO
// =====================================================

class SocketService {
    static io.Socket? _socket;
    static SocketStatus _status = SocketStatus.disconnected;
    static String? _authToken;

    static SocketStatus get status => _status;
    static bool get isConnected => _status == SocketStatus.connected;
    static String? get authToken => _authToken;

    // =====================================================
    // 📡 STREAMS
    // =====================================================

    static final _statusController = StreamController<SocketStatus>.broadcast();
    static Stream<SocketStatus> get onStatusChange => _statusController.stream;

    static final _newMessageController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onNewMessage =>
        _newMessageController.stream;

    static final _userTypingController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onUserTyping =>
        _userTypingController.stream;

    static final _userStoppedTypingController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onUserStoppedTyping =>
        _userStoppedTypingController.stream;

    static final _userOnlineController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onUserOnline =>
        _userOnlineController.stream;

    static final _userOfflineController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onUserOffline =>
        _userOfflineController.stream;

    static final _messageReadController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onMessageRead =>
        _messageReadController.stream;

    static final _messageEditedController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onMessageEdited =>
        _messageEditedController.stream;

    static final _messageDeletedController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onMessageDeleted =>
        _messageDeletedController.stream;

    static final _reactionAddedController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onReactionAdded =>
        _reactionAddedController.stream;

    static final _reactionRemovedController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onReactionRemoved =>
        _reactionRemovedController.stream;

    static final _onlineCountController = StreamController<int>.broadcast();
    static Stream<int> get onOnlineCount => _onlineCountController.stream;

    static final _errorController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onError => _errorController.stream;

    // ─────────────────────────────────────────
    // 👑 ЗАЯВКИ
    // ─────────────────────────────────────────

    static final _newRecruitController =
        StreamController<Map<String, dynamic>>.broadcast();
    static Stream<Map<String, dynamic>> get onNewRecruit =>
        _newRecruitController.stream;

    static final _pendingCountController = StreamController<int>.broadcast();
    static Stream<int> get onPendingCount => _pendingCountController.stream;

    // =====================================================
    // 🔌 ПОДКЛЮЧЕНИЕ
    // =====================================================

    /// 🎯 Подключение к Socket.IO.
    /// 
    /// transports: ['websocket', 'polling'] — если WebSocket блокируется
    /// (мобильные операторы, корпоративные firewall), автоматически
    /// переключается на polling через HTTP.
    static Future<bool> connect(String token) async {
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
                    // 🎯 FIX: WebSocket + polling fallback.
                    // Polling — через HTTP, мобильный оператор НЕ блокирует.
                    .setTransports(['websocket', 'polling'])
                    .setAuth({'token': token})
                    .enableForceNew()
                    .enableReconnection()
                    .setReconnectionAttempts(20)     // 🎯 было 5
                    .setReconnectionDelay(1000)      // 🎯 1 сек
                    .setReconnectionDelayMax(5000)   // 🎯 до 5 сек
                    .setTimeout(20000)               // 🎯 20 сек
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

    static void disconnect() {
        AppLogger.socket('Отключение Socket');

        _socket?.disconnect();
        _socket?.dispose();
        _socket = null;
        _authToken = null;
        _setStatus(SocketStatus.disconnected);
    }

    // =====================================================
    // 🎧 РЕГИСТРАЦИЯ ОБРАБОТЧИКОВ
    // =====================================================

    static void _registerHandlers() {
        if (_socket == null) return;

        // ✅ Подключён
        _socket!.onConnect((_) {
            AppLogger.success('Socket подключён: ${_socket!.id}');
            _setStatus(SocketStatus.connected);

            _socket!.emit(SocketEvents.joinChats);
            _socket!.emit(SocketEvents.joinAdmins);
        });

        // ❌ Ошибка подключения
        _socket!.onConnectError((error) {
            AppLogger.error('Socket ошибка подключения', error);
            _setStatus(SocketStatus.error);
        });

        // 🔌 Отключён
        _socket!.onDisconnect((reason) {
            AppLogger.socket('Socket отключён: $reason');
            _setStatus(SocketStatus.disconnected);
        });

        // 📥 Присоединился к чатам
        _socket!.on(SocketEvents.joinedChats, (data) {
            AppLogger.socket('Присоединился к чатам', data);
        });

        // 📨 Новое сообщение
        _socket!.on(SocketEvents.newMessage, (data) {
            if (data is Map) {
                AppLogger.socket('📨 Новое сообщение', data['id']);
                _newMessageController.add(Map<String, dynamic>.from(data));
            }
        });

        // ⌨️ Кто-то печатает
        _socket!.on(SocketEvents.userTyping, (data) {
            if (data is Map) {
                _userTypingController.add(Map<String, dynamic>.from(data));
            }
        });

        // ⏹ Перестал печатать
        _socket!.on(SocketEvents.userStoppedTyping, (data) {
            if (data is Map) {
                _userStoppedTypingController
                    .add(Map<String, dynamic>.from(data));
            }
        });

        // 🟢 Пользователь онлайн
        _socket!.on(SocketEvents.userOnline, (data) {
            if (data is Map) {
                _userOnlineController.add(Map<String, dynamic>.from(data));
            }
        });

        // ⚫ Пользователь офлайн
        _socket!.on(SocketEvents.userOffline, (data) {
            if (data is Map) {
                _userOfflineController.add(Map<String, dynamic>.from(data));
            }
        });

        // ✅ Прочитано
        _socket!.on(SocketEvents.messageRead, (data) {
            if (data is Map) {
                _messageReadController.add(Map<String, dynamic>.from(data));
            }
        });

        // ✏️ Отредактировано
        _socket!.on(SocketEvents.messageEdited, (data) {
            if (data is Map) {
                _messageEditedController.add(Map<String, dynamic>.from(data));
            }
        });

        // 🗑️ Удалено
        _socket!.on(SocketEvents.messageDeleted, (data) {
            if (data is Map) {
                _messageDeletedController.add(Map<String, dynamic>.from(data));
            }
        });

        // 😀 Реакция добавлена
        _socket!.on(SocketEvents.reactionAdded, (data) {
            if (data is Map) {
                _reactionAddedController.add(Map<String, dynamic>.from(data));
            }
        });

        // 😀 Реакция убрана
        _socket!.on(SocketEvents.reactionRemoved, (data) {
            if (data is Map) {
                _reactionRemovedController.add(Map<String, dynamic>.from(data));
            }
        });

        // 👥 Счётчик онлайна
        _socket!.on(SocketEvents.onlineCount, (data) {
            if (data is int) {
                _onlineCountController.add(data);
            } else if (data is Map && data['count'] is int) {
                _onlineCountController.add(data['count'] as int);
            }
        });

        // 👑 Новый новобранец
        _socket!.on(SocketEvents.newRecruit, (data) {
            if (data is Map) {
                AppLogger.success('🔔 Новый новобранец');
                _newRecruitController.add(Map<String, dynamic>.from(data));
            }
        });

        // 📊 Счётчик заявок
        _socket!.on(SocketEvents.pendingCount, (data) {
            if (data is int) {
                _pendingCountController.add(data);
            } else if (data is Map && data['count'] is int) {
                _pendingCountController.add(data['count'] as int);
            }
        });

        // ❌ Ошибка от сервера
        _socket!.on(SocketEvents.error, (data) {
            if (data is Map) {
                AppLogger.warn('Socket ошибка сервера', data);
                _errorController.add(Map<String, dynamic>.from(data));
            }
        });
    }

    // =====================================================
    // 📤 ОТПРАВКА СОБЫТИЙ
    // =====================================================

    static void sendMessage({
        required int chatId,
        required String text,
        int? replyToId,
        int? tempId,
    }) {
        if (_socket == null || !isConnected) {
            AppLogger.warn('Socket не подключён — сообщение не отправлено');
            return;
        }

        _socket!.emit(SocketEvents.sendMessage, {
            'chatId': chatId,
            'text': text,
            if (replyToId != null) 'replyToId': replyToId,
            if (tempId != null) 'tempId': tempId,
        });

        AppLogger.socket('📤 Отправлено в чат $chatId', text);
    }

    static void sendTyping(int chatId) {
        if (_socket == null || !isConnected) return;
        _socket!.emit(SocketEvents.typing, {'chatId': chatId});
    }

    static void sendStopTyping(int chatId) {
        if (_socket == null || !isConnected) return;
        _socket!.emit(SocketEvents.stopTyping, {'chatId': chatId});
    }

    static void markRead(int chatId, int messageId) {
        if (_socket == null || !isConnected) return;
        _socket!.emit(SocketEvents.markRead, {
            'chatId': chatId,
            'messageId': messageId,
        });
    }

    // =====================================================
    // 🛠️ СЛУЖЕБНЫЕ
    // =====================================================

    static void _setStatus(SocketStatus status) {
        if (_status == status) return;
        _status = status;
        _statusController.add(status);
    }

    static void dispose() {
        disconnect();
        _statusController.close();
        _newMessageController.close();
        _userTypingController.close();
        _userStoppedTypingController.close();
        _userOnlineController.close();
        _userOfflineController.close();
        _messageReadController.close();
        _messageEditedController.close();
        _messageDeletedController.close();
        _reactionAddedController.close();
        _reactionRemovedController.close();
        _onlineCountController.close();
        _errorController.close();
        _newRecruitController.close();
        _pendingCountController.close();
    }
}