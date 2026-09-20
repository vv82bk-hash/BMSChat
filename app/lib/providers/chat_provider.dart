// =====================================================
// 💬 BMSChat — ПРОВАЙДЕР ЧАТОВ
// =====================================================
// 🎯 ПАГИНАЦИЯ: подгрузка старых сообщений
// 🎯 СЧЁТЧИК НЕПРОЧИТАННЫХ: unreadCount живёт в Chat
// 🎯 ШАГ 9: управление каналами
// 🎯 ФИКС (гонка создания/открытия):
//   • createChannel — формирует Chat из ответа сервера
//   • openChat — fallback: грузит с сервера, если нет в _chats
// 🎯 ЭТАП A: добавлен totalUnreadCount для бейджа на BottomNav
// 🎯 ЭТАП C.2: закреплённые чаты
//   • _pinnedChatIds хранится в SharedPreferences
//   • pinnedChats — закреплённые сверху
//   • regularChats — все остальные
//   • pinChat / unpinChat / isPinned
// =====================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/app_logger.dart';
import 'auth_provider.dart';

class ChatProvider extends ChangeNotifier {
    // =====================================================
    // 📊 СОСТОЯНИЕ
    // =====================================================

    AuthProvider? _authProvider;

    List<Chat> _chats = [];
    Chat? _activeChat;
    List<Message> _messages = [];

    final Map<int, String> _typingUsers = {};
    final Map<int, Timer> _typingTimers = {};

    final Set<int> _onlineUserIds = {};
    int _onlineCount = 0;

    int _maxReadMessageId = 0;
    int _myLastReadMessageId = 0;

    Message? _replyToMessage;

    bool _isLoadingChats = false;
    bool _isLoadingMessages = false;
    bool _isSendingMessage = false;

    String? _chatsError;
    String? _messagesError;

    bool _hasMoreOld = true;
    bool _isLoadingMore = false;

    // 🎯 ЭТАП C.2: закреплённые чаты
    static const String _pinnedKey = 'bmschat_pinned_chat_ids';
    final List<int> _pinnedChatIds = [];
    bool _pinnedLoaded = false;

    StreamSubscription? _newMessageSub;
    StreamSubscription? _userTypingSub;
    StreamSubscription? _userStoppedTypingSub;
    StreamSubscription? _messageEditedSub;
    StreamSubscription? _messageDeletedSub;
    StreamSubscription? _reactionAddedSub;
    StreamSubscription? _reactionRemovedSub;
    StreamSubscription? _messageReadSub;
    StreamSubscription? _userOnlineSub;
    StreamSubscription? _userOfflineSub;
    StreamSubscription? _onlineCountSub;

    Timer? _myTypingTimer;
    Timer? _myTypingThrottleTimer;
    int? _myTypingChatId;

    // =====================================================
    // 📤 ГЕТТЕРЫ
    // =====================================================

    List<Chat> get chats => _chats;
    Chat? get activeChat => _activeChat;
    List<Message> get messages => _messages;
    bool get isLoadingChats => _isLoadingChats;
    bool get isLoadingMessages => _isLoadingMessages;
    bool get isSendingMessage => _isSendingMessage;
    String? get chatsError => _chatsError;
    String? get messagesError => _messagesError;
    Message? get replyToMessage => _replyToMessage;

    int get maxReadMessageId => _maxReadMessageId;
    int get myLastReadMessageId => _myLastReadMessageId;

    bool get hasMoreOld => _hasMoreOld;
    bool get isLoadingMore => _isLoadingMore;

    String? get typingUser {
        if (_typingUsers.isEmpty) return null;
        return _typingUsers.values.first;
    }

    bool get hasTypingUsers => _typingUsers.isNotEmpty;

    Set<int> get onlineUserIds => Set.unmodifiable(_onlineUserIds);
    int get onlineCount => _onlineCount;
    bool isUserOnline(int userId) => _onlineUserIds.contains(userId);

    int getOnlineCountForMembers(List<int> memberIds) {
        if (memberIds.isEmpty) return 0;
        return memberIds.where((id) => _onlineUserIds.contains(id)).length;
    }

    // =====================================================
    // 🎯 ЭТАП C.2: ЗАКРЕПЛЁННЫЕ ЧАТЫ
    // =====================================================

    /// Закреплён ли чат?
    bool isPinned(int chatId) => _pinnedChatIds.contains(chatId);

    /// Закреплённые чаты (в порядке _chats, уже отсортированных).
    List<Chat> get pinnedChats =>
        _chats.where((c) => _pinnedChatIds.contains(c.id)).toList();

    /// Обычные чаты (все, кроме закреплённых).
    List<Chat> get regularChats =>
        _chats.where((c) => !_pinnedChatIds.contains(c.id)).toList();

    /// Количество закреплённых.
    int get pinnedCount => _pinnedChatIds.length;

    // =====================================================
    // 🔧 ИНИЦИАЛИЗАЦИЯ
    // =====================================================

    void setAuthProvider(AuthProvider auth) {
        _authProvider = auth;
    }

    /// 🎯 ЭТАП C.2: загрузка закреплений из SharedPreferences.
    /// Вызывается при старте приложения (например, из main()).
    Future<void> loadPinnedChats() async {
        if (_pinnedLoaded) return;

        try {
            final prefs = await SharedPreferences.getInstance();
            final stored = prefs.getStringList(_pinnedKey);
            if (stored != null) {
                _pinnedChatIds
                    .clear();
                _pinnedChatIds.addAll(
                    stored.map((s) => int.tryParse(s)).whereType<int>(),
                );
                AppLogger.info('📌 Загружено закреплений: ${_pinnedChatIds.length}');
            }
            _pinnedLoaded = true;
            notifyListeners();
        } catch (e) {
            AppLogger.error('Ошибка загрузки закреплений', e);
        }
    }

    /// 🎯 ЭТАП C.2: сохранение закреплений в SharedPreferences.
    Future<void> _savePinnedChats() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(
                _pinnedKey,
                _pinnedChatIds.map((id) => id.toString()).toList(),
            );
        } catch (e) {
            AppLogger.error('Ошибка сохранения закреплений', e);
        }
    }

    /// 🎯 ЭТАП C.2: закрепить чат.
    Future<void> pinChat(int chatId) async {
        if (_pinnedChatIds.contains(chatId)) return;

        _pinnedChatIds.add(chatId);
        _sortChats();
        notifyListeners();
        await _savePinnedChats();

        AppLogger.info('📌 Чат #$chatId закреплён');
    }

    /// 🎯 ЭТАП C.2: открепить чат.
    Future<void> unpinChat(int chatId) async {
        if (!_pinnedChatIds.contains(chatId)) return;

        _pinnedChatIds.remove(chatId);
        _sortChats();
        notifyListeners();
        await _savePinnedChats();

        AppLogger.info('📌 Чат #$chatId откреплён');
    }

    /// 🎯 ЭТАП C.2: переключить закрепление.
    Future<void> togglePin(int chatId) async {
        if (isPinned(chatId)) {
            await unpinChat(chatId);
        } else {
            await pinChat(chatId);
        }
    }

    /// 🎯 ЭТАП C.5: локально скрыть чат из списка.
    /// Сервер не трогаем — при следующем loadChats() чат вернётся.
    /// Используется для «Удалить» из контекстного меню и свайпа.
    void hideChatLocally(int chatId) {
        _chats.removeWhere((c) => c.id == chatId);

        if (_activeChat?.id == chatId) {
            closeChat();
        }

        notifyListeners();
        AppLogger.info('👁️ Чат #$chatId скрыт локально');
    }
    /// 🎯 ЭТАП C.2: сортировка чатов с учётом закрепления.
    ///   • Закреплённые — сверху (между собой по lastMessageAt).
    ///   • Обычные — под ними (по lastMessageAt).
    void _sortChats() {
        _chats.sort((a, b) {
            final aPinned = _pinnedChatIds.contains(a.id);
            final bPinned = _pinnedChatIds.contains(b.id);

            // Закреплённые всегда выше
            if (aPinned != bPinned) {
                return aPinned ? -1 : 1;
            }

            // Внутри группы — по lastMessageAt
            final aTime = a.lastMessageAt ?? a.createdAt ?? DateTime(2000);
            final bTime = b.lastMessageAt ?? b.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
        });
    }

    void initSocketListeners() {
        AppLogger.info('💬 Инициализация Socket-слушателей');

        _newMessageSub?.cancel();
        _newMessageSub = SocketService.onNewMessage.listen(_handleNewMessage);

        _userTypingSub?.cancel();
        _userTypingSub = SocketService.onUserTyping.listen(_handleUserTyping);

        _userStoppedTypingSub?.cancel();
        _userStoppedTypingSub =
            SocketService.onUserStoppedTyping.listen(_handleUserStoppedTyping);

        _messageEditedSub?.cancel();
        _messageEditedSub =
            SocketService.onMessageEdited.listen(_handleMessageEdited);

        _messageDeletedSub?.cancel();
        _messageDeletedSub =
            SocketService.onMessageDeleted.listen(_handleMessageDeleted);

        _reactionAddedSub?.cancel();
        _reactionAddedSub =
            SocketService.onReactionAdded.listen(_handleReactionAdded);

        _reactionRemovedSub?.cancel();
        _reactionRemovedSub =
            SocketService.onReactionRemoved.listen(_handleReactionRemoved);

        _messageReadSub?.cancel();
        _messageReadSub =
            SocketService.onMessageRead.listen(_handleMessageRead);

        _userOnlineSub?.cancel();
        _userOnlineSub = SocketService.onUserOnline.listen((data) {
            final userId = data['userId'] as int?;
            if (userId != null) {
                _onlineUserIds.add(userId);
                AppLogger.debug('🟢 Онлайн: $userId');
                notifyListeners();
            }
        });

        _userOfflineSub?.cancel();
        _userOfflineSub = SocketService.onUserOffline.listen((data) {
            final userId = data['userId'] as int?;
            if (userId != null) {
                _onlineUserIds.remove(userId);
                AppLogger.debug('⚫ Офлайн: $userId');
                notifyListeners();
            }
        });

        _onlineCountSub?.cancel();
        _onlineCountSub = SocketService.onOnlineCount.listen((count) {
            _onlineCount = count;
            notifyListeners();
        });
    }

    // =====================================================
    // 📋 ЧАТЫ
    // =====================================================

    Future<void> loadChats() async {
        AppLogger.info('📋 Загрузка чатов...');

        // 🎯 ЭТАП C.2: при первой загрузке — подтягиваем закрепления
        if (!_pinnedLoaded) {
            await loadPinnedChats();
        }

        _isLoadingChats = true;
        _chatsError = null;
        notifyListeners();

        try {
            final response = await ApiService.getChats();

            if (response.isSuccess) {
                _chats = response.data ?? [];

                // 🎯 ФИКС: после перезагрузки — обновляем _activeChat
                if (_activeChat != null) {
                    final updated = _chats.firstWhere(
                        (c) => c.id == _activeChat!.id,
                        orElse: () => _activeChat!,
                    );
                    _activeChat = updated;
                }

                // 🎯 ЭТАП C.2: сортируем с учётом закреплений
                _sortChats();

                AppLogger.success(
                    'Загружено ${_chats.length} чатов '
                    '(непрочитанных: ${_chats.where((c) => c.hasUnread).length}, '
                    'каналов: ${_chats.where((c) => c.isChannel).length}, '
                    'закреплено: ${_pinnedChatIds.length})'
                );
                _chatsError = null;
            } else {
                _chatsError = response.error ?? 'Ошибка загрузки';
                AppLogger.warn('Ошибка чатов: $_chatsError');
            }
        } catch (e) {
            AppLogger.error('Ошибка загрузки чатов', e);
            _chatsError = 'Ошибка сети';
        }

        _isLoadingChats = false;
        notifyListeners();
    }

    /// 🎯 ФИКС: защита от гонки — если чат не найден в `_chats`,
    /// загружаем его с сервера через `GET /api/chats/:id`.
    Future<void> openChat(int chatId) async {
        AppLogger.info('🎯 Открытие чата $chatId');

        try {
            // 1. Пытаемся найти в локальном списке
            Chat? chat;
            try {
                chat = _chats.firstWhere((c) => c.id == chatId);
            } catch (_) {
                chat = null;
            }

            // 2. 🎯 Fallback: если нет — грузим с сервера
            if (chat == null) {
                AppLogger.warn(
                    'Чат #$chatId не найден в _chats — загружаем с сервера'
                );
                final response = await ApiService.getChat(chatId);

                if (response.isSuccess && response.data != null) {
                    final chatJson =
                        response.data!['chat'] as Map<String, dynamic>?;

                    if (chatJson != null) {
                        chat = Chat.fromJson({
                            ...chatJson,
                            'is_member': true,
                        });
                        _chats.add(chat);
                        _sortChats();
                        AppLogger.success(
                            'Чат #$chatId загружен с сервера: '
                            'isMember=${chat.isMember}, '
                            'myRole=${chat.myRole}'
                        );
                    }
                }
            }

            if (chat == null) {
                AppLogger.error('Чат #$chatId не найден нигде');
                _chatsError = 'Чат не найден';
                notifyListeners();
                return;
            }

            // 3. Устанавливаем активный чат
            _activeChat = chat;
            _messages = [];
            _typingUsers.clear();
            _replyToMessage = null;
            _messagesError = null;
            _maxReadMessageId = 0;
            _myLastReadMessageId = 0;
            _hasMoreOld = true;
            _isLoadingMore = false;

            // 4. Обнуляем unreadCount
            final idx = _chats.indexWhere((c) => c.id == chatId);
            if (idx >= 0 && _chats[idx].unreadCount > 0) {
                _chats[idx] = _chats[idx].copyWith(unreadCount: 0);
            }

            notifyListeners();

            // 5. Грузим сообщения
            await _loadMessages(chatId);
        } catch (e) {
            AppLogger.error('Ошибка открытия чата', e);
            _chatsError = 'Ошибка сети';
            notifyListeners();
        }
    }

    void closeChat() {
        _activeChat = null;
        _messages = [];
        _typingUsers.clear();
        _replyToMessage = null;
        _maxReadMessageId = 0;
        _myLastReadMessageId = 0;
        _hasMoreOld = true;
        _isLoadingMore = false;
        notifyListeners();
    }

    // =====================================================
    // 🎯 ШАГ 9: УПРАВЛЕНИЕ КАНАЛАМИ
    // =====================================================

    /// 🎯 ФИКС: формируем Chat напрямую из ответа сервера,
    /// не полагаясь на loadChats() — избегаем гонки.
    Future<Chat?> createChannel({
        required String name,
        String? description,
        bool isPrivate = false,
        String? emoji,
        List<int> members = const [],
    }) async {
        AppLogger.info('📢 Создание канала: $name');

        try {
            final response = await ApiService.createChat(
                type: 'channel',
                name: name,
                description: description,
                isPrivate: isPrivate,
                emoji: emoji,
                members: members,
            );

            if (!response.isSuccess || response.data == null) {
                AppLogger.warn('Ошибка создания канала: ${response.error}');
                _chatsError = response.error ?? 'Ошибка создания';
                notifyListeners();
                return null;
            }

            final chatJson = response.data!['chat'] as Map<String, dynamic>?;
            if (chatJson == null) {
                AppLogger.warn('Ошибка: нет chat в ответе сервера');
                _chatsError = 'Некорректный ответ сервера';
                notifyListeners();
                return null;
            }

            final created = Chat.fromJson({
                ...chatJson,
                'is_member': true,
                'my_role': 'admin',
                'members_count': members.length + 1,
                'unread_count': 0,
            });

            // Добавляем в _chats и сортируем
            _chats.removeWhere((c) => c.id == created.id);
            _chats.insert(0, created);
            _sortChats();
            notifyListeners();

            // ignore: unawaited_futures
            loadChats();

            AppLogger.success(
                'Канал создан: #${created.id} '
                '(isMember=${created.isMember}, '
                'isPrivate=${created.isPrivate}, '
                'emoji=${created.emoji})'
            );
            return created;
        } catch (e) {
            AppLogger.error('Ошибка создания канала', e);
            _chatsError = 'Ошибка сети';
            notifyListeners();
            return null;
        }
    }

    /// 🎯 Редактировать канал
    Future<bool> updateChannel(
        int chatId, {
        String? name,
        String? description,
        String? emoji,
        bool? isPrivate,
    }) async {
        AppLogger.info('✏️ Редактирование канала #$chatId');

        try {
            final response = await ApiService.updateChat(
                chatId,
                name: name,
                description: description,
                emoji: emoji,
                isPrivate: isPrivate,
            );

            if (!response.isSuccess) {
                AppLogger.warn('Ошибка редактирования: ${response.error}');
                _chatsError = response.error ?? 'Ошибка редактирования';
                notifyListeners();
                return false;
            }

            final idx = _chats.indexWhere((c) => c.id == chatId);
            if (idx >= 0) {
                _chats[idx] = _chats[idx].copyWith(
                    name: name,
                    description: description,
                    emoji: emoji,
                    isPrivate: isPrivate,
                );
            }

            if (_activeChat?.id == chatId) {
                _activeChat = _activeChat!.copyWith(
                    name: name,
                    description: description,
                    emoji: emoji,
                    isPrivate: isPrivate,
                );
            }

            _chatsError = null;
            notifyListeners();
            AppLogger.success('Канал отредактирован');
            return true;
        } catch (e) {
            AppLogger.error('Ошибка редактирования канала', e);
            _chatsError = 'Ошибка сети';
            notifyListeners();
            return false;
        }
    }

    /// 🎯 Удалить канал
    Future<bool> deleteChannel(int chatId) async {
        AppLogger.info('🗑️ Удаление канала #$chatId');

        try {
            final response = await ApiService.deleteChat(chatId);

            if (!response.isSuccess) {
                AppLogger.warn('Ошибка удаления: ${response.error}');
                _chatsError = response.error ?? 'Ошибка удаления';
                notifyListeners();
                return false;
            }

            _chats.removeWhere((c) => c.id == chatId);

            // 🎯 ЭТАП C.2: убираем из закреплённых, если был закреплён
            if (_pinnedChatIds.contains(chatId)) {
                _pinnedChatIds.remove(chatId);
                await _savePinnedChats();
            }

            if (_activeChat?.id == chatId) {
                closeChat();
            }

            _chatsError = null;
            notifyListeners();
            AppLogger.success('Канал удалён');
            return true;
        } catch (e) {
            AppLogger.error('Ошибка удаления канала', e);
            _chatsError = 'Ошибка сети';
            notifyListeners();
            return false;
        }
    }

    /// 🎯 Вступить в публичный канал
    Future<bool> joinChannel(int chatId) async {
        AppLogger.info('🚪 Вступление в канал #$chatId');

        try {
            final response = await ApiService.joinChannel(chatId);

            if (!response.isSuccess) {
                AppLogger.warn('Ошибка вступления: ${response.error}');
                _chatsError = response.error ?? 'Ошибка вступления';
                notifyListeners();
                return false;
            }

            final idx = _chats.indexWhere((c) => c.id == chatId);
            if (idx >= 0) {
                _chats[idx] = _chats[idx].copyWith(
                    isMember: true,
                    myRole: 'member',
                );
            }

            if (_activeChat?.id == chatId) {
                _activeChat = _activeChat!.copyWith(
                    isMember: true,
                    myRole: 'member',
                );
            }

            _chatsError = null;
            notifyListeners();
            AppLogger.success('Вступил в канал #$chatId');
            return true;
        } catch (e) {
            AppLogger.error('Ошибка вступления в канал', e);
            _chatsError = 'Ошибка сети';
            notifyListeners();
            return false;
        }
    }

    /// 🎯 Массовое добавление участников
    Future<Map<String, int>?> addChannelMembers(
        int chatId,
        List<int> userIds,
    ) async {
        AppLogger.info('👥 Добавление участников в #$chatId: ${userIds.length}');

        try {
            final response =
                await ApiService.addChatMembersBulk(chatId, userIds);

            if (!response.isSuccess || response.data == null) {
                AppLogger.warn('Ошибка добавления: ${response.error}');
                _chatsError = response.error ?? 'Ошибка добавления';
                notifyListeners();
                return null;
            }

            final data = response.data!;
            final added = data['added'] as int? ?? 0;
            final filtered = data['filtered'] as int? ?? 0;

            AppLogger.success('Добавлено: $added, отфильтровано: $filtered');

            final idx = _chats.indexWhere((c) => c.id == chatId);
            if (idx >= 0) {
                _chats[idx] = _chats[idx].copyWith(
                    membersCount: _chats[idx].membersCount + added,
                );
            }

            if (_activeChat?.id == chatId) {
                _activeChat = _activeChat!.copyWith(
                    membersCount: _activeChat!.membersCount + added,
                );
            }

            _chatsError = null;
            notifyListeners();
            return {'added': added, 'filtered': filtered};
        } catch (e) {
            AppLogger.error('Ошибка добавления участников', e);
            _chatsError = 'Ошибка сети';
            notifyListeners();
            return null;
        }
    }

    /// 🎯 Удалить участника из канала
    Future<bool> removeChannelMember(int chatId, int userId) async {
        AppLogger.info('🗑️ Удаление участника #$userId из #$chatId');

        try {
            final response =
                await ApiService.removeChatMember(chatId, userId);

            if (!response.isSuccess) {
                AppLogger.warn('Ошибка удаления: ${response.error}');
                _chatsError = response.error ?? 'Ошибка удаления';
                notifyListeners();
                return false;
            }

            final idx = _chats.indexWhere((c) => c.id == chatId);
            if (idx >= 0 && _chats[idx].membersCount > 0) {
                _chats[idx] = _chats[idx].copyWith(
                    membersCount: _chats[idx].membersCount - 1,
                );
            }

            if (_activeChat?.id == chatId &&
                _activeChat!.membersCount > 0) {
                _activeChat = _activeChat!.copyWith(
                    membersCount: _activeChat!.membersCount - 1,
                );
            }

            _chatsError = null;
            notifyListeners();
            AppLogger.success('Участник удалён');
            return true;
        } catch (e) {
            AppLogger.error('Ошибка удаления участника', e);
            _chatsError = 'Ошибка сети';
            notifyListeners();
            return false;
        }
    }

    // =====================================================
    // 💬 СООБЩЕНИЯ
    // =====================================================

    Future<void> _loadMessages(int chatId) async {
        _isLoadingMessages = true;
        _messagesError = null;
        _hasMoreOld = true;
        _isLoadingMore = false;
        notifyListeners();

        try {
            final response = await ApiService.getMessages(
                chatId,
                limit: Constants.messagesPageSize,
            );

            if (response.isSuccess && response.data != null) {
                final result = response.data!;

                _maxReadMessageId = result.maxReadId;
                _myLastReadMessageId = result.myLastReadId;
                _hasMoreOld = result.hasMore;

                final myId = _authProvider?.user?.id;
                _messages = result.messages.map((msg) {
                    final isOwn = msg.senderId == myId;
                    final isRead = isOwn && msg.id <= result.maxReadId;
                    return msg.copyWith(isRead: isRead);
                }).toList();

                AppLogger.success(
                    'Загружено ${_messages.length} сообщений '
                    '(hasMore: $_hasMoreOld, '
                    'maxRead: ${result.maxReadId}, '
                    'myLastRead: ${result.myLastReadId})'
                );
            } else {
                _messagesError = response.error ?? 'Ошибка загрузки';
            }
        } catch (e) {
            AppLogger.error('Ошибка сообщений', e);
            _messagesError = 'Ошибка сети';
        }

        _isLoadingMessages = false;
        notifyListeners();
    }

    Future<void> refreshMessages() async {
        if (_activeChat == null) return;
        await _loadMessages(_activeChat!.id);
    }

    Future<bool> loadMoreOld() async {
        if (_activeChat == null) return false;
        if (!_hasMoreOld) return false;
        if (_isLoadingMore) return false;
        if (_messages.isEmpty) return false;

        _isLoadingMore = true;
        notifyListeners();

        try {
            final oldestId = _messages.first.id;

            final response = await ApiService.getMessages(
                _activeChat!.id,
                limit: Constants.messagesPageSize,
                before: oldestId,
            );

            if (response.isSuccess && response.data != null) {
                final result = response.data!;

                _hasMoreOld = result.hasMore;

                final myId = _authProvider?.user?.id;
                final older = result.messages.map((msg) {
                    final isOwn = msg.senderId == myId;
                    final isRead = isOwn && msg.id <= result.maxReadId;
                    return msg.copyWith(isRead: isRead);
                }).toList();

                final existingIds = _messages.map((m) => m.id).toSet();
                final fresh =
                    older.where((m) => !existingIds.contains(m.id)).toList();

                if (fresh.isEmpty) {
                    AppLogger.warn(
                        '🛡️ Пагинация: пустая порция '
                        '(raw: ${older.length}, '
                        'дубликатов: ${older.length - fresh.length}). '
                        'Ставим hasMore = false.'
                    );
                    _hasMoreOld = false;

                    _isLoadingMore = false;
                    notifyListeners();
                    return false;
                }

                _messages = [...fresh, ..._messages];

                AppLogger.success(
                    'Подгружено ${fresh.length} старых сообщений '
                    '(hasMore: $_hasMoreOld)'
                );

                _isLoadingMore = false;
                notifyListeners();
                return true;
            } else {
                AppLogger.warn('Ошибка подгрузки: ${response.error}');
                _isLoadingMore = false;
                notifyListeners();
                return false;
            }
        } catch (e) {
            AppLogger.error('Ошибка подгрузки старых', e);
            _isLoadingMore = false;
            notifyListeners();
            return false;
        }
    }

    Future<void> markAsRead() async {
        if (_activeChat == null) return;
        if (_messages.isEmpty) return;

        final lastMessageId = _messages.last.id;

        if (_myLastReadMessageId >= lastMessageId) return;

        _myLastReadMessageId = lastMessageId;

        final idx = _chats.indexWhere((c) => c.id == _activeChat!.id);
        if (idx >= 0 && _chats[idx].unreadCount > 0) {
            _chats[idx] = _chats[idx].copyWith(unreadCount: 0);
        }

        notifyListeners();

        try {
            await ApiService.markChatRead(_activeChat!.id, lastMessageId);
            SocketService.markRead(_activeChat!.id, lastMessageId);
        } catch (e) {
            AppLogger.error('Ошибка отметки прочтения', e);
        }
    }

    int getUnreadCount(Chat chat) => chat.unreadCount;

    /// 🎯 ЭТАП A: сумма непрочитанных по всем чатам — для бейджа
    int get totalUnreadCount {
        return _chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
    }

    // =====================================================
    // 📤 ОТПРАВКА
    // =====================================================

    String? canWriteToActiveChat() {
        if (_activeChat == null || _authProvider == null) {
            return 'Чат не открыт';
        }

        final user = _authProvider!.user;
        if (user == null) return 'Не авторизован';

        final chatType = _activeChat!.type;

        if (chatType == 'general') {
            if (user.canWriteGeneral) return null;
            return 'В общем чате можно только читать';
        }

        if (chatType == 'channel') {
            if (!_activeChat!.isMember) {
                return 'Вы не участник канала';
            }
            if (user.canWriteGeneral) return null;
            return 'В канале могут писать только бойцы';
        }

        if (chatType == 'group') {
            if (user.canWriteGeneral) return null;
            return 'Нет права писать в группы';
        }

        if (chatType == 'private') {
            if (user.canWritePrivate) return null;
            if (user.canWriteToCommander) return null;
            return 'Нет права писать в личные чаты';
        }

        return 'Неизвестный тип чата';
    }

    Future<bool> sendMessage(String text, {int? replyToId}) async {
        if (_activeChat == null) return false;
        if (text.trim().isEmpty) return false;

        final permissionError = canWriteToActiveChat();
        if (permissionError != null) {
            AppLogger.warn('Нет прав: $permissionError');
            return false;
        }

        _isSendingMessage = true;
        notifyListeners();

        try {
            final tempId = DateTime.now().millisecondsSinceEpoch;
            SocketService.sendMessage(
                chatId: _activeChat!.id,
                text: text.trim(),
                replyToId: replyToId,
                tempId: tempId,
            );

            stopTyping();
            _isSendingMessage = false;
            notifyListeners();
            return true;
        } catch (e) {
            AppLogger.error('Ошибка отправки', e);
            _isSendingMessage = false;
            notifyListeners();
            return false;
        }
    }

    Future<bool> sendFile(String localPath, String type) async {
        if (_activeChat == null) {
            AppLogger.warn('Нет активного чата');
            return false;
        }

        final permissionError = canWriteToActiveChat();
        if (permissionError != null) {
            AppLogger.warn('Нет прав: $permissionError');
            return false;
        }

        _isSendingMessage = true;
        notifyListeners();

        try {
            AppLogger.info('📤 Загрузка файла: $type');

            final uploadResponse = await ApiService.uploadFile(localPath, type);

            if (!uploadResponse.isSuccess || uploadResponse.data == null) {
                AppLogger.error('Ошибка загрузки: ${uploadResponse.error}');
                _isSendingMessage = false;
                notifyListeners();
                return false;
            }

            final fileData = uploadResponse.data!;
            final uploadedPath = fileData['file_path'] as String;
            final fileType = fileData['file_type'] as String? ?? type;

            AppLogger.success('Файл загружен: $uploadedPath (тип: $fileType)');

            String prefix;
            switch (fileType) {
                case 'image':
                    prefix = 'IMG:';
                    break;
                case 'voice':
                    prefix = 'VOICE:';
                    break;
                default:
                    prefix = 'FILE:';
            }

            final textWithPrefix = '$prefix$uploadedPath';

            SocketService.sendMessage(
                chatId: _activeChat!.id,
                text: textWithPrefix,
                tempId: DateTime.now().millisecondsSinceEpoch,
            );

            _isSendingMessage = false;
            notifyListeners();
            return true;
        } catch (e) {
            AppLogger.error('Ошибка отправки файла', e);
            _isSendingMessage = false;
            notifyListeners();
            return false;
        }
    }

    void setReplyTo(Message message) {
        _replyToMessage = message;
        notifyListeners();
    }

    void clearReplyTo() {
        _replyToMessage = null;
        notifyListeners();
    }

    Future<bool> sendReply(String text) async {
        if (_replyToMessage == null) return false;

        final result = await sendMessage(
            text,
            replyToId: _replyToMessage!.id,
        );

        if (result) {
            clearReplyTo();
        }

        return result;
    }

    // =====================================================
    // 😀 РЕАКЦИИ
    // =====================================================

    Future<bool> addReaction(int messageId, String emoji) async {
        if (_authProvider?.user == null) return false;
        final userId = _authProvider!.user!.id;
        final displayName = _authProvider!.user!.displayName;

        _applyReactionLocally(messageId, userId, emoji, displayName);

        try {
            final response = await ApiService.addReaction(messageId, emoji);

            if (response.isSuccess) {
                AppLogger.success('Реакция $emoji добавлена');
                return true;
            }

            AppLogger.warn('Ошибка реакции: ${response.error}');
            _removeReactionLocally(messageId, userId, emoji);
            return false;
        } catch (e) {
            AppLogger.error('Ошибка реакции', e);
            _removeReactionLocally(messageId, userId, emoji);
            return false;
        }
    }

    Future<bool> removeReaction(int messageId, String emoji) async {
        if (_authProvider?.user == null) return false;
        final userId = _authProvider!.user!.id;
        final displayName = _authProvider!.user!.displayName;

        _removeReactionLocally(messageId, userId, emoji);

        try {
            final response = await ApiService.removeReaction(messageId, emoji);

            if (response.isSuccess) {
                AppLogger.success('Реакция $emoji убрана');
                return true;
            }

            _applyReactionLocally(messageId, userId, emoji, displayName);
            return false;
        } catch (e) {
            AppLogger.error('Ошибка удаления реакции', e);
            _applyReactionLocally(messageId, userId, emoji, displayName);
            return false;
        }
    }

    bool hasMyReaction(int messageId, String emoji, int userId) {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index < 0) return false;

        return _messages[index].reactions
            .any((r) => r.userId == userId && r.emoji == emoji);
    }

    void _applyReactionLocally(
        int messageId,
        int userId,
        String emoji,
        String? displayName,
    ) {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index < 0) return;

        final msg = _messages[index];
        final newReactions = List<Reaction>.from(msg.reactions);

        final exists = newReactions.any(
            (r) => r.userId == userId && r.emoji == emoji,
        );
        if (exists) return;

        newReactions.add(Reaction(
            emoji: emoji,
            userId: userId,
            displayName: displayName,
        ));

        _messages[index] = msg.copyWith(reactions: newReactions);
        notifyListeners();
    }

    void _removeReactionLocally(int messageId, int userId, String emoji) {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index < 0) return;

        final msg = _messages[index];
        final newReactions = msg.reactions
            .where((r) => !(r.userId == userId && r.emoji == emoji))
            .toList();

        if (newReactions.length == msg.reactions.length) return;

        _messages[index] = msg.copyWith(reactions: newReactions);
        notifyListeners();
    }

    // =====================================================
    // ✏️ РЕДАКТИРОВАНИЕ
    // =====================================================

    Future<bool> editMessage(int messageId, String newText) async {
        try {
            final response = await ApiService.editMessage(messageId, newText);
            if (response.isSuccess) {
                final index = _messages.indexWhere((m) => m.id == messageId);
                if (index >= 0) {
                    _messages[index] = _messages[index].copyWith(
                        text: newText,
                        isEdited: true,
                    );
                    notifyListeners();
                }
                AppLogger.success('Сообщение отредактировано');
                return true;
            }
            return false;
        } catch (e) {
            AppLogger.error('Ошибка редактирования', e);
            return false;
        }
    }

    // =====================================================
    // 🗑️ УДАЛЕНИЕ
    // =====================================================

    Future<bool> deleteMessage(int messageId) async {
        try {
            final response = await ApiService.deleteMessage(messageId);
            if (response.isSuccess) {
                final index = _messages.indexWhere((m) => m.id == messageId);
                if (index >= 0) {
                    _messages[index] = _messages[index].copyWith(
                        text: null,
                        isDeleted: true,
                    );
                    notifyListeners();
                }
                AppLogger.success('Сообщение удалено');
                return true;
            }
            return false;
        } catch (e) {
            AppLogger.error('Ошибка удаления', e);
            return false;
        }
    }

    // =====================================================
    // ⌨️ ПЕЧАТАЕТ
    // =====================================================

    void sendTyping() {
        if (_activeChat == null) return;

        final chatId = _activeChat!.id;

        SocketService.sendTyping(chatId);
        _myTypingChatId = chatId;

        _myTypingTimer?.cancel();
        _myTypingTimer = Timer(
            const Duration(milliseconds: 3000),
            stopTyping,
        );

        if (_myTypingThrottleTimer == null ||
            !_myTypingThrottleTimer!.isActive) {
            _myTypingThrottleTimer = Timer(
                const Duration(milliseconds: 2000),
                () {
                    if (_activeChat != null &&
                        _myTypingChatId == _activeChat!.id) {
                        SocketService.sendTyping(_activeChat!.id);
                    }
                },
            );
        }
    }

    void stopTyping() {
        if (_myTypingChatId != null) {
            SocketService.sendStopTyping(_myTypingChatId!);
            _myTypingChatId = null;
        }
        _myTypingTimer?.cancel();
        _myTypingTimer = null;
        _myTypingThrottleTimer?.cancel();
        _myTypingThrottleTimer = null;
    }

    // =====================================================
    // 📥 ОБРАБОТКА СОБЫТИЙ
    // =====================================================

    void _handleNewMessage(Map<String, dynamic> data) {
        try {
            final message = Message.fromJson(data);
            final chatId = message.chatId;
            final isActive = _activeChat?.id == chatId;

            if (isActive) {
                final exists = _messages.any((m) => m.id == message.id);
                if (!exists) {
                    _messages.add(message);
                    notifyListeners();
                    markAsRead();
                }
            } else {
                final idx = _chats.indexWhere((c) => c.id == chatId);
                if (idx >= 0) {
                    final chat = _chats[idx];

                    if (chat.isChannel && !chat.isMember) {
                        AppLogger.debug(
                            '🔔 Пропускаю +1: я не участник канала ${chat.title}'
                        );
                    } else {
                        final updated = chat.copyWith(
                            unreadCount: chat.unreadCount + 1,
                        );
                        _chats[idx] = updated;
                        AppLogger.debug(
                            '🔔 +1 непрочитанное в чате ${updated.title} '
                            '(всего: ${updated.unreadCount})'
                        );
                    }
                }
            }

            _updateChatPreview(chatId, message);
        } catch (e) {
            AppLogger.error('Ошибка обработки сообщения', e);
        }
    }

    void _handleUserTyping(Map<String, dynamic> data) {
        final chatId = data['chatId'] as int?;
        final userId = data['userId'] as int?;
        final displayName = data['displayName'] as String?;

        if (chatId == null || userId == null || displayName == null) return;
        if (_activeChat?.id != chatId) return;

        _typingUsers[userId] = displayName;

        _typingTimers[userId]?.cancel();
        _typingTimers[userId] = Timer(
            const Duration(milliseconds: 3000),
            () {
                _typingUsers.remove(userId);
                _typingTimers.remove(userId);
                notifyListeners();
            },
        );

        notifyListeners();
    }

    void _handleUserStoppedTyping(Map<String, dynamic> data) {
        final userId = data['userId'] as int?;
        if (userId == null) return;

        _typingUsers.remove(userId);
        _typingTimers[userId]?.cancel();
        _typingTimers.remove(userId);
        notifyListeners();
    }

    void _handleMessageEdited(Map<String, dynamic> data) {
        final messageId = data['messageId'] as int?;
        final newText = data['text'] as String?;
        if (messageId == null) return;

        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
            _messages[index] = _messages[index].copyWith(
                text: newText,
                isEdited: true,
            );
            notifyListeners();
        }
    }

    void _handleMessageDeleted(Map<String, dynamic> data) {
        final messageId = data['messageId'] as int?;
        if (messageId == null) return;

        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
            _messages[index] = _messages[index].copyWith(
                text: null,
                isDeleted: true,
            );
            notifyListeners();
        }
    }

    void _handleReactionAdded(Map<String, dynamic> data) {
        final messageId = data['messageId'] as int?;
        final userId = data['userId'] as int?;
        final emoji = data['emoji'] as String?;
        final displayName = data['displayName'] as String?;

        if (messageId == null || userId == null || emoji == null) return;

        _applyReactionLocally(messageId, userId, emoji, displayName);
    }

    void _handleReactionRemoved(Map<String, dynamic> data) {
        final messageId = data['messageId'] as int?;
        final userId = data['userId'] as int?;
        final emoji = data['emoji'] as String?;

        if (messageId == null || userId == null || emoji == null) return;

        _removeReactionLocally(messageId, userId, emoji);
    }

    void _handleMessageRead(Map<String, dynamic> data) {
        final chatId = data['chatId'] as int?;
        final userId = data['userId'] as int?;
        final messageId = data['messageId'] as int?;

        if (chatId == null || userId == null || messageId == null) return;

        if (_activeChat?.id == chatId) {
            if (messageId > _maxReadMessageId) {
                _maxReadMessageId = messageId;

                final myId = _authProvider?.user?.id;
                if (myId != null) {
                    for (int i = 0; i < _messages.length; i++) {
                        final m = _messages[i];
                        if (m.senderId == myId &&
                            m.id <= messageId &&
                            !m.isRead) {
                            _messages[i] = m.copyWith(isRead: true);
                        }
                    }
                }

                notifyListeners();
            }
        }
    }

    void _updateChatPreview(int chatId, Message message) {
        final index = _chats.indexWhere((c) => c.id == chatId);
        if (index >= 0) {
            _chats[index] = _chats[index].copyWith(
                lastMessageId: message.id,
                lastMessageText: message.text,
                lastMessageAt: message.createdAt,
            );

            // 🎯 ЭТАП C.2: используем _sortChats вместо своего sort
            _sortChats();

            notifyListeners();
        }
    }

    // =====================================================
    // 🛠️ ОЧИСТКА
    // =====================================================

    Future<void> clear() async {
        await _newMessageSub?.cancel();
        await _userTypingSub?.cancel();
        await _userStoppedTypingSub?.cancel();
        await _messageEditedSub?.cancel();
        await _messageDeletedSub?.cancel();
        await _reactionAddedSub?.cancel();
        await _reactionRemovedSub?.cancel();
        await _messageReadSub?.cancel();
        await _userOnlineSub?.cancel();
        await _userOfflineSub?.cancel();
        await _onlineCountSub?.cancel();

        _myTypingTimer?.cancel();
        _myTypingThrottleTimer?.cancel();
        for (final timer in _typingTimers.values) {
            timer.cancel();
        }

        _chats = [];
        _activeChat = null;
        _messages = [];
        _typingUsers.clear();
        _typingTimers.clear();
        _onlineUserIds.clear();
        _onlineCount = 0;
        _maxReadMessageId = 0;
        _myLastReadMessageId = 0;
        _replyToMessage = null;
        _chatsError = null;
        _messagesError = null;
        _isLoadingChats = false;
        _isLoadingMessages = false;
        _isSendingMessage = false;
        _hasMoreOld = true;
        _isLoadingMore = false;

        // 🎯 ЭТАП C.2: НЕ очищаем _pinnedChatIds —
        // закрепления пользовательские, живут между сессиями.
        // Они загрузятся заново через loadPinnedChats().

        notifyListeners();
    }

    @override
    void dispose() {
        _newMessageSub?.cancel();
        _userTypingSub?.cancel();
        _userStoppedTypingSub?.cancel();
        _messageEditedSub?.cancel();
        _messageDeletedSub?.cancel();
        _reactionAddedSub?.cancel();
        _reactionRemovedSub?.cancel();
        _messageReadSub?.cancel();
        _userOnlineSub?.cancel();
        _userOfflineSub?.cancel();
        _onlineCountSub?.cancel();

        _myTypingTimer?.cancel();
        _myTypingThrottleTimer?.cancel();
        for (final timer in _typingTimers.values) {
            timer.cancel();
        }

        super.dispose();
    }
}