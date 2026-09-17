import 'dart:async';

import 'package:flutter/material.dart';

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

    // Онлайн-статусы
    final Set<int> _onlineUserIds = {};
    int _onlineCount = 0;

    // Ответ на сообщение
    Message? _replyToMessage;

    bool _isLoadingChats = false;
    bool _isLoadingMessages = false;
    bool _isSendingMessage = false;

    String? _chatsError;
    String? _messagesError;

    // Подписки
    StreamSubscription? _newMessageSub;
    StreamSubscription? _userTypingSub;
    StreamSubscription? _userStoppedTypingSub;
    StreamSubscription? _messageEditedSub;
    StreamSubscription? _messageDeletedSub;
    StreamSubscription? _reactionAddedSub;
    StreamSubscription? _reactionRemovedSub;
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
    // 🔧 ИНИЦИАЛИЗАЦИЯ
    // =====================================================

    void setAuthProvider(AuthProvider auth) {
        _authProvider = auth;
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

        _isLoadingChats = true;
        _chatsError = null;
        notifyListeners();

        try {
            final response = await ApiService.getChats();

            if (response.isSuccess) {
                _chats = response.data ?? [];
                AppLogger.success('Загружено ${_chats.length} чатов');
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

    Future<void> openChat(int chatId) async {
        AppLogger.info('🎯 Открытие чата $chatId');

        try {
            final chat = _chats.firstWhere((c) => c.id == chatId);
            _activeChat = chat;
            _messages = [];
            _typingUsers.clear();
            _replyToMessage = null;
            _messagesError = null;
            notifyListeners();

            await _loadMessages(chatId);
        } catch (e) {
            AppLogger.error('Чат не найден', e);
        }
    }

    void closeChat() {
        _activeChat = null;
        _messages = [];
        _typingUsers.clear();
        _replyToMessage = null;
        notifyListeners();
    }

    // =====================================================
    // 💬 СООБЩЕНИЯ
    // =====================================================

    Future<void> _loadMessages(int chatId) async {
        _isLoadingMessages = true;
        _messagesError = null;
        notifyListeners();

        try {
            final response = await ApiService.getMessages(chatId);

            if (response.isSuccess) {
                _messages = response.data ?? [];
                AppLogger.success('Загружено ${_messages.length} сообщений');
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
            if (user.canCreateFeed || user.canManageRoles) return null;
            return 'В канале могут писать только админы';
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

    // =====================================================
    // 📤 ЗАГРУЗКА ФАЙЛОВ
    // =====================================================

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

            AppLogger.success('Файл загружен: $uploadedPath');

            SocketService.sendMessage(
                chatId: _activeChat!.id,
                text: uploadedPath,
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

    // =====================================================
    // ↩️ ОТВЕТЫ
    // =====================================================

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

    /// Добавить реакцию (оптимистично + API)
    Future<bool> addReaction(int messageId, String emoji) async {
        if (_authProvider?.user == null) return false;
        final userId = _authProvider!.user!.id;
        final displayName = _authProvider!.user!.displayName;

        // 1. Оптимистичное обновление локально
        _applyReactionLocally(messageId, userId, emoji, displayName);

        try {
            // 2. Отправляем на сервер
            final response = await ApiService.addReaction(messageId, emoji);

            if (response.isSuccess) {
                AppLogger.success('Реакция $emoji добавлена');
                return true;
            }

            // 3. Если ошибка — откатываем локально
            AppLogger.warn('Ошибка реакции: ${response.error}');
            _removeReactionLocally(messageId, userId, emoji);
            return false;
        } catch (e) {
            AppLogger.error('Ошибка реакции', e);
            _removeReactionLocally(messageId, userId, emoji);
            return false;
        }
    }

    /// Убрать реакцию (оптимистично + API)
    Future<bool> removeReaction(int messageId, String emoji) async {
        if (_authProvider?.user == null) return false;
        final userId = _authProvider!.user!.id;
        final displayName = _authProvider!.user!.displayName;

        // 1. Оптимистичное обновление локально
        _removeReactionLocally(messageId, userId, emoji);

        try {
            // 2. Отправляем на сервер
            final response = await ApiService.removeReaction(messageId, emoji);

            if (response.isSuccess) {
                AppLogger.success('Реакция $emoji убрана');
                return true;
            }

            // 3. Если ошибка — откатываем локально
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

    // =====================================================
    // 🛠️ ВСПОМОГАТЕЛЬНЫЕ ДЛЯ РЕАКЦИЙ
    // =====================================================

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

            if (_activeChat?.id == chatId) {
                final exists = _messages.any((m) => m.id == message.id);
                if (!exists) {
                    _messages.add(message);
                    notifyListeners();
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

        // Используем helper с защитой от дубликатов
        _applyReactionLocally(messageId, userId, emoji, displayName);
    }

    void _handleReactionRemoved(Map<String, dynamic> data) {
        final messageId = data['messageId'] as int?;
        final userId = data['userId'] as int?;
        final emoji = data['emoji'] as String?;

        if (messageId == null || userId == null || emoji == null) return;

        // Используем helper
        _removeReactionLocally(messageId, userId, emoji);
    }

    // =====================================================
    // 🔄 ПРЕВЬЮ
    // =====================================================

    void _updateChatPreview(int chatId, Message message) {
        final index = _chats.indexWhere((c) => c.id == chatId);
        if (index >= 0) {
            _chats[index] = _chats[index].copyWith(
                lastMessageId: message.id,
                lastMessageText: message.text,
                lastMessageAt: message.createdAt,
            );

            _chats.sort((a, b) {
                final aTime = a.lastMessageAt ?? a.createdAt ?? DateTime(2000);
                final bTime = b.lastMessageAt ?? b.createdAt ?? DateTime(2000);
                return bTime.compareTo(aTime);
            });

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
        _replyToMessage = null;
        _chatsError = null;
        _messagesError = null;
        _isLoadingChats = false;
        _isLoadingMessages = false;
        _isSendingMessage = false;

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