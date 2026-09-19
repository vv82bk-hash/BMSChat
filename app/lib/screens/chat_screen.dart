// =====================================================
// 💬 BMSChat — ЭКРАН ЧАТА
// =====================================================
// 🎯 МИГРАЦИЯ НА reverse: true
// 🎯 ПАГИНАЦИЯ: подгрузка старых сообщений
// 🎯 ОТСТУП ПОД СИСТЕМНУЮ НАВИГАЦИЮ
// 🎯 ШАГ 15: настройки канала + вступление в канал
// =====================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';
import '../widgets/animated_message_wrapper.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_picker.dart';
import 'channel_settings_screen.dart';
import 'users_screen.dart';

class ChatScreen extends StatefulWidget {
    final int chatId;

    const ChatScreen({
        super.key,
        required this.chatId,
    });

    @override
    State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
    final _messageController = TextEditingController();
    final _scrollController = ScrollController();
    final _imagePicker = ImagePicker();
    bool _isTyping = false;

    bool _initialScrollDone = false;
    int _lastMessageCount = 0;
    int _lastReadBeforeOpen = 0;
    final Map<int, GlobalKey> _messageKeys = {};
    bool _showScrollButton = false;

    // 🎯 ПАГИНАЦИЯ
    bool _isLoadingMore = false;
    int _lastSeenLastId = 0;

    // 🎯 ШАГ 15: индикатор вступления в канал
    bool _isJoining = false;

    @override
    void initState() {
        super.initState();

        _scrollController.addListener(_onScroll);

        WidgetsBinding.instance.addPostFrameCallback((_) {
            final chat = Provider.of<ChatProvider>(context, listen: false);
            _lastReadBeforeOpen = chat.myLastReadMessageId;
            chat.addListener(_onChatChanged);
        });
    }

    @override
    void dispose() {
        final chat = Provider.of<ChatProvider>(context, listen: false);
        chat.removeListener(_onChatChanged);
        _scrollController.removeListener(_onScroll);
        _messageController.dispose();
        _scrollController.dispose();
        super.dispose();
    }

    // ============================================
    // 📜 СКРОЛЛ
    // ============================================
    void _onScroll() {
        if (!_scrollController.hasClients) return;

        final position = _scrollController.position;
        final isNearBottom = position.pixels <= 200;

        if (_showScrollButton == isNearBottom) {
            setState(() => _showScrollButton = !isNearBottom);
        }

        final isNearTop = position.pixels >= position.maxScrollExtent - 400;
        if (isNearTop) {
            _triggerLoadMore();
        }
    }

    GlobalKey _getMessageKey(int messageId) {
        return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
    }

    void _onChatChanged() {
        if (!mounted) return;

        final chat = Provider.of<ChatProvider>(context, listen: false);

        if (!_initialScrollDone &&
            !chat.isLoadingMessages &&
            chat.messages.isNotEmpty) {
            _initialScrollDone = true;
            _lastMessageCount = chat.messages.length;
            _lastSeenLastId = chat.messages.last.id;

            if (_lastReadBeforeOpen > 0 &&
                chat.messages.any((m) => m.id > _lastReadBeforeOpen)) {
                _scrollToFirstUnread(_lastReadBeforeOpen);
            }

            chat.markAsRead();
            return;
        }

        if (chat.messages.length > _lastMessageCount) {
            final currentLastId = chat.messages.last.id;
            final isNewAppended = currentLastId > _lastSeenLastId;

            _lastMessageCount = chat.messages.length;

            if (isNewAppended) {
                _lastSeenLastId = currentLastId;

                final position = _scrollController.hasClients
                    ? _scrollController.position
                    : null;
                final isNearBottom =
                    position == null || position.pixels <= 300;

                if (isNearBottom) {
                    _scrollToBottom();
                }

                chat.markAsRead();
            }
        }
    }

    Future<void> _triggerLoadMore() async {
        if (_isLoadingMore) return;

        final chat = Provider.of<ChatProvider>(context, listen: false);
        if (!chat.hasMoreOld) return;
        if (chat.isLoadingMore) return;
        if (!_scrollController.hasClients) return;

        _isLoadingMore = true;

        final beforePixels = _scrollController.position.pixels;
        final beforeMax = _scrollController.position.maxScrollExtent;

        final loaded = await chat.loadMoreOld();

        if (!mounted) return;
        if (!_scrollController.hasClients) return;

        if (loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scrollController.hasClients) return;

                final afterMax = _scrollController.position.maxScrollExtent;
                final delta = afterMax - beforeMax;

                _scrollController.jumpTo(beforePixels + delta);
            });
        }

        _isLoadingMore = false;
    }

    // ============================================
    // 📤 ОТПРАВКА
    // ============================================
    Future<void> _sendMessage() async {
        final text = _messageController.text.trim();
        if (text.isEmpty) return;

        final chat = Provider.of<ChatProvider>(context, listen: false);

        final success = chat.replyToMessage != null
            ? await chat.sendReply(text)
            : await chat.sendMessage(text);

        if (!success) {
            _showError('Не удалось отправить сообщение');
            return;
        }

        _messageController.clear();
        setState(() => _isTyping = false);
        _scrollToBottom();
    }

    Future<void> _pickImage() async {
        try {
            final XFile? image = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 50,
                maxWidth: 1280,
                maxHeight: 1280,
            );

            if (image == null) return;
            if (!mounted) return;

            _showInfo('Загрузка фото...');

            final chat = Provider.of<ChatProvider>(context, listen: false);
            final success = await chat.sendFile(image.path, 'image');

            if (!mounted) return;

            if (!success) {
                _showError('Не удалось отправить фото');
            } else {
                _showInfo('Фото отправлено');
                _scrollToBottom();
            }
        } catch (e) {
            if (!mounted) return;
            _showError('Ошибка выбора фото: $e');
        }
    }

    void _onTextChanged(String text) {
        final chat = Provider.of<ChatProvider>(context, listen: false);

        if (text.isEmpty) {
            chat.stopTyping();
            setState(() => _isTyping = false);
            return;
        }

        chat.sendTyping();
        if (!_isTyping) {
            setState(() => _isTyping = true);
        }
    }

    void _scrollToBottom({bool jump = false}) {
        if (!_scrollController.hasClients) return;

        if (jump) {
            _scrollController.jumpTo(0);
        } else {
            _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
            );
        }
    }

    void _scrollToFirstUnread(int lastReadId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            final chat = Provider.of<ChatProvider>(context, listen: false);

            final firstUnread = chat.messages.firstWhere(
                (m) => m.id > lastReadId,
                orElse: () => chat.messages.last,
            );

            final key = _messageKeys[firstUnread.id];

            if (key == null || key.currentContext == null) {
                _scrollToBottom(jump: true);
                return;
            }

            Scrollable.ensureVisible(
                key.currentContext!,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                alignment: 0.3,
            );
        });
    }

    void _showError(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.error,
                behavior: SnackBarBehavior.floating,
            ),
        );
    }

    void _showInfo(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
            ),
        );
    }

    void _openUsers() {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const UsersScreen(),
            ),
        );
    }

    // ============================================
    // 🎯 ШАГ 15: НАСТРОЙКИ КАНАЛА
    // ============================================
    bool _canManageChannel(Chat chat) {
        final me = Provider.of<AuthProvider>(context, listen: false).user;
        if (me == null) return false;

        if (me.isAdmin || me.isCommander) return true;
        if (chat.createdBy == me.id) return true;

        return false;
    }

    Future<void> _openChannelSettings(Chat chat) async {
        final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
                builder: (_) => ChannelSettingsScreen(chat: chat),
            ),
        );

        if (!mounted) return;

        if (result == 'deleted') {
            Navigator.pop(context);
            return;
        }

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.loadChats();
    }

    // ============================================
    // 🎯 ШАГ 15: ВСТУПИТЬ В КАНАЛ
    // ============================================
    Future<void> _joinChannel() async {
        final chat = Provider.of<ChatProvider>(context, listen: false);
        final activeChat = chat.activeChat;
        if (activeChat == null) return;

        setState(() => _isJoining = true);

        final success = await chat.joinChannel(activeChat.id);

        if (!mounted) return;
        setState(() => _isJoining = false);

        if (success) {
            _showInfo('Вы вступили в канал');
            await chat.loadChats();
        } else {
            _showError(chat.chatsError ?? 'Не удалось вступить');
        }
    }

    // ============================================
    // 🎨 UI
    // ============================================
    @override
    Widget build(BuildContext context) {
        final chat = Provider.of<ChatProvider>(context);
        final auth = Provider.of<AuthProvider>(context);

        final activeChat = chat.activeChat;
        final currentUserId = auth.user?.id ?? 0;
        final permissionError = chat.canWriteToActiveChat();
        final canWrite = permissionError == null;

        final navBarHeight = MediaQuery.viewPaddingOf(context).bottom;

        // 🎯 ШАГ 15: канал, где я не участник?
        final isChannelNotMember = activeChat != null &&
            activeChat.isChannel &&
            !activeChat.isMember;

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.5),
                title: Row(
                    children: [
                        if (activeChat != null && activeChat.useLogoImage) ...[
                            Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                        BoxShadow(
                                            color: RastaTheme.rastaYellow
                                                .withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                        ),
                                    ],
                                ),
                                child: ClipOval(
                                    child: Image.asset(
                                        'assets/images/logo.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                                color: RastaTheme.surfaceSecondary,
                                                child: const Center(
                                                    child: Text('🎯',
                                                        style: TextStyle(fontSize: 20)),
                                                ),
                                            );
                                        },
                                    ),
                                ),
                            ),
                            const SizedBox(width: 10),
                        ],

                        // 🎯 ШАГ 15: для канала — эмодзи-аватар
                        if (activeChat != null &&
                            activeChat.isChannel &&
                            !activeChat.useLogoImage) ...[
                            Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                        colors: [
                                            Color(0xFF9C27B0),
                                            RastaTheme.rastaRed,
                                        ],
                                    ),
                                ),
                                child: Center(
                                    child: Text(
                                        activeChat.displayEmoji,
                                        style: const TextStyle(fontSize: 20),
                                    ),
                                ),
                            ),
                            const SizedBox(width: 10),
                        ],

                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Text(
                                        activeChat?.title ?? 'Чат',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                    if (activeChat != null) _buildSubtitle(chat),
                                ],
                            ),
                        ),
                    ],
                ),
                actions: [
                    // 🎯 ШАГ 15: настройки канала
                    if (activeChat != null &&
                        activeChat.isChannel &&
                        _canManageChannel(activeChat))
                        IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 26),
                            tooltip: 'Настройки канала',
                            onPressed: () => _openChannelSettings(activeChat),
                        ),
                    IconButton(
                        icon: const Icon(Icons.people_outline, size: 26),
                        tooltip: 'Участники',
                        onPressed: _openUsers,
                    ),
                ],
            ),
            body: Column(
                children: [
                    Expanded(
                        child: Stack(
                            children: [
                                chat.isLoadingMessages
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                RastaTheme.rastaYellow,
                                            ),
                                        ),
                                    )
                                    : chat.messages.isEmpty
                                        ? _buildEmptyState(activeChat?.useLogoImage ?? false)
                                        : ListView.builder(
                                            controller: _scrollController,
                                            reverse: true,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 0,
                                            ),
                                            itemCount: chat.messages.length,
                                            itemBuilder: (context, index) {
                                                final message = chat.messages[
                                                    chat.messages.length - 1 - index
                                                ];
                                                final isOwn =
                                                    message.senderId == currentUserId;

                                                return AnimatedMessageWrapper(
                                                    key: _getMessageKey(message.id),
                                                    messageId: message.id,
                                                    child: MessageBubble(
                                                        message: message,
                                                        isOwn: isOwn,
                                                        onLongPress: () =>
                                                            _showReactionPicker(
                                                                context,
                                                                message,
                                                                isOwn,
                                                            ),
                                                    ),
                                                );
                                            },
                                        ),

                                if (chat.isLoadingMore)
                                    const Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8,
                                            ),
                                            child: Center(
                                                child: SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<Color>(
                                                                RastaTheme.rastaYellow,
                                                            ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ),

                                Positioned(
                                    right: 16,
                                    bottom: 16,
                                    child: AnimatedScale(
                                        scale: _showScrollButton ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOutBack,
                                        child: AnimatedOpacity(
                                            opacity: _showScrollButton ? 1.0 : 0.0,
                                            duration: const Duration(milliseconds: 200),
                                            child: _buildScrollToBottomButton(),
                                        ),
                                    ),
                                ),
                            ],
                        ),
                    ),

                    // 🎯 ШАГ 15: блок «Вступить в канал»
                    if (isChannelNotMember)
                        _buildJoinChannelBlock(activeChat)
                    else if (canWrite) ...[
                        if (chat.replyToMessage != null)
                            _buildReplyPreview(chat),
                        _buildInputField(),
                    ] else
                        _buildBlockedField(permissionError),

                    SizedBox(height: navBarHeight),
                ],
            ),
        );
    }

    // =====================================================
    // 🎯 ШАГ 15: БЛОК «ВСТУПИТЬ В КАНАЛ»
    // =====================================================
    Widget _buildJoinChannelBlock(Chat chat) {
        if (chat.isPrivate) {
            return Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: RastaTheme.surface,
                    border: Border(
                        top: BorderSide(
                            color: RastaTheme.separator,
                            width: 0.5,
                        ),
                    ),
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(
                            Icons.lock_outline,
                            color: RastaTheme.textMuted,
                            size: 22,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                            child: Text(
                                'Это приватный канал. Нужно приглашение от создателя.',
                                style: TextStyle(
                                    color: RastaTheme.textMuted,
                                    fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                            ),
                        ),
                    ],
                ),
            );
        }

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
                color: RastaTheme.surface,
                border: Border(
                    top: BorderSide(
                        color: RastaTheme.separator,
                        width: 0.5,
                    ),
                ),
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    const Text(
                        'Вы читаете канал. Чтобы писать сообщения — вступите.',
                        style: TextStyle(
                            fontSize: 13,
                            color: RastaTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            onPressed: _isJoining ? null : _joinChannel,
                            icon: _isJoining
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                            ),
                                    ),
                                )
                                : const Icon(Icons.login, size: 20),
                            label: Text(
                                _isJoining ? 'Вступаю...' : 'Вступить в канал',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                ),
                            ),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: RastaTheme.rastaGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                ),
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 🎯 КНОПКА СКРОЛЛА ВНИЗ
    // =====================================================
    Widget _buildScrollToBottomButton() {
        return GestureDetector(
            onTap: () {
                _scrollToBottom();
                setState(() => _showScrollButton = false);
            },
            child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                            RastaTheme.rastaYellow,
                            RastaTheme.rastaGreen,
                        ],
                    ),
                    boxShadow: [
                        BoxShadow(
                            color: RastaTheme.rastaYellow.withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                        ),
                    ],
                ),
                child: const Center(
                    child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black,
                        size: 32,
                    ),
                ),
            ),
        );
    }

    // ============================================
    // 📊 ПОДЗАГОЛОВОК APPBAR
    // ============================================
    Widget _buildSubtitle(ChatProvider chat) {
        if (chat.hasTypingUsers) {
            return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                    '${chat.typingUser} печатает...',
                    key: ValueKey('typing_${chat.typingUser}'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: RastaTheme.rastaYellow,
                    ),
                ),
            );
        }

        final activeChat = chat.activeChat;
        if (activeChat == null) return const SizedBox.shrink();

        if (activeChat.isPrivateChat) {
            return const Text(
                'личный чат',
                style: TextStyle(
                    fontSize: 13,
                    color: RastaTheme.textMuted,
                ),
            );
        }

        // 🎯 ШАГ 15: для каналов — приватость
        if (activeChat.isChannel) {
            return Text(
                activeChat.isPrivate
                    ? 'приватный канал'
                    : '${activeChat.membersCount} участников',
                style: const TextStyle(
                    fontSize: 13,
                    color: RastaTheme.textMuted,
                ),
            );
        }

        final membersCount = activeChat.membersCount;
        final onlineCount = chat.onlineCount;

        return Text(
            '$membersCount участников, $onlineCount онлайн',
            style: const TextStyle(
                fontSize: 13,
                color: RastaTheme.textMuted,
            ),
        );
    }

    // ============================================
    // 📭 НЕТ СООБЩЕНИЙ
    // ============================================
    Widget _buildEmptyState(bool isGeneral) {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    if (isGeneral)
                        Opacity(
                            opacity: 0.7,
                            child: ClipOval(
                                child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                        return const Text(
                                            '💬',
                                            style: TextStyle(fontSize: 64),
                                        );
                                    },
                                ),
                            ),
                        )
                    else
                        const Text('💬', style: TextStyle(fontSize: 64)),

                    const SizedBox(height: 20),

                    const Text(
                        'Нет сообщений',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Начните переписку первым!',
                        style: TextStyle(
                            fontSize: 15,
                            color: RastaTheme.textMuted.withValues(alpha: 0.8),
                        ),
                    ),
                ],
            ),
        );
    }

    // ============================================
    // ↩️ ПРЕВЬЮ ОТВЕТА
    // ============================================
    Widget _buildReplyPreview(ChatProvider chat) {
        final replyTo = chat.replyToMessage;
        if (replyTo == null) return const SizedBox.shrink();

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
                color: RastaTheme.surfaceSecondary,
                border: Border(
                    left: BorderSide(
                        color: RastaTheme.rastaYellow,
                        width: 3,
                    ),
                ),
            ),
            child: Row(
                children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                    'Ответ ${replyTo.senderName ?? ""}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: RastaTheme.rastaYellow,
                                    ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    replyTo.displayText,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: RastaTheme.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                ),
                            ],
                        ),
                    ),
                    IconButton(
                        icon: const Icon(
                            Icons.close,
                            color: RastaTheme.textMuted,
                            size: 22,
                        ),
                        onPressed: () => chat.clearReplyTo(),
                    ),
                ],
            ),
        );
    }

    // ============================================
    // ⌨️ ПОЛЕ ВВОДА
    // ============================================
    Widget _buildInputField() {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: const BoxDecoration(
                color: RastaTheme.surface,
                border: Border(
                    top: BorderSide(color: RastaTheme.separator, width: 0.5),
                ),
            ),
            child: Row(
                children: [
                    IconButton(
                        icon: const Icon(
                            Icons.attach_file,
                            color: RastaTheme.rastaYellow,
                            size: 26,
                        ),
                        onPressed: _pickImage,
                        tooltip: 'Фото',
                    ),

                    Expanded(
                        child: TextField(
                            controller: _messageController,
                            onChanged: _onTextChanged,
                            onSubmitted: (_) => _sendMessage(),
                            maxLines: 4,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            style: const TextStyle(
                                color: RastaTheme.textPrimary,
                                fontSize: 16,
                            ),
                            decoration: InputDecoration(
                                hintText: 'Сообщение...',
                                hintStyle: const TextStyle(
                                    color: RastaTheme.textMuted,
                                    fontSize: 16,
                                ),
                                filled: true,
                                fillColor: RastaTheme.background,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(26),
                                    borderSide: BorderSide.none,
                                ),
                            ),
                        ),
                    ),

                    const SizedBox(width: 6),

                    Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                                BoxShadow(
                                    color: RastaTheme.rastaYellow
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                ),
                            ],
                        ),
                        child: CircleAvatar(
                            radius: 26,
                            backgroundColor: RastaTheme.rastaYellow,
                            child: IconButton(
                                icon: const Icon(
                                    Icons.send,
                                    color: Colors.black,
                                    size: 22,
                                ),
                                onPressed: _sendMessage,
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    // ============================================
    // 🚫 ТОЛЬКО ЧТЕНИЕ
    // ============================================
    Widget _buildBlockedField(String? reason) {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: RastaTheme.surface,
                border: Border(
                    top: BorderSide(color: RastaTheme.separator, width: 0.5),
                ),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Icon(
                        Icons.lock_outline,
                        color: RastaTheme.textMuted,
                        size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(
                            reason ?? 'Только чтение',
                            style: const TextStyle(
                                color: RastaTheme.textMuted,
                                fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                        ),
                    ),
                ],
            ),
        );
    }

    // ============================================
    // 😀 РЕАКЦИИ
    // ============================================
    void _showReactionPicker(
        BuildContext context,
        Message message,
        bool isOwn,
    ) {
        final chat = Provider.of<ChatProvider>(context, listen: false);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final userId = auth.user?.id ?? 0;

        final myReactions = message.reactions
            .where((r) => r.userId == userId)
            .map((r) => r.emoji)
            .toSet();

        showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (bottomSheetContext) {
                return SingleChildScrollView(
                    child: Container(
                        padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: 16 +
                                MediaQuery.of(bottomSheetContext)
                                    .padding
                                    .bottom,
                        ),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                ReactionPicker(
                                    myReactions: myReactions,
                                    onSelect: (emoji) async {
                                        Navigator.pop(bottomSheetContext);

                                        if (myReactions.contains(emoji)) {
                                            await chat.removeReaction(
                                                message.id,
                                                emoji,
                                            );
                                        } else {
                                            await chat.addReaction(
                                                message.id,
                                                emoji,
                                            );
                                        }
                                    },
                                ),

                                const SizedBox(height: 12),

                                Container(
                                    decoration: BoxDecoration(
                                        color: RastaTheme.surface,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                        children: [
                                            ListTile(
                                                leading: const Icon(
                                                    Icons.reply,
                                                    color:
                                                        RastaTheme.rastaYellow,
                                                ),
                                                title: const Text(
                                                    'Ответить',
                                                    style: TextStyle(
                                                        color: RastaTheme
                                                            .textPrimary,
                                                        fontSize: 16,
                                                    ),
                                                ),
                                                onTap: () {
                                                    Navigator.pop(
                                                        bottomSheetContext);
                                                    chat.setReplyTo(message);
                                                },
                                            ),

                                            if (isOwn) ...[
                                                ListTile(
                                                    leading: const Icon(
                                                        Icons.edit,
                                                        color: RastaTheme
                                                            .rastaYellow,
                                                    ),
                                                    title: const Text(
                                                        'Редактировать',
                                                        style: TextStyle(
                                                            color: RastaTheme
                                                                .textPrimary,
                                                            fontSize: 16,
                                                        ),
                                                    ),
                                                    onTap: () {
                                                        Navigator.pop(
                                                            bottomSheetContext);
                                                        _editMessage(message);
                                                    },
                                                ),
                                                ListTile(
                                                    leading: const Icon(
                                                        Icons.delete_outline,
                                                        color:
                                                            RastaTheme.error,
                                                    ),
                                                    title: const Text(
                                                        'Удалить',
                                                        style: TextStyle(
                                                            color:
                                                                RastaTheme.error,
                                                            fontSize: 16,
                                                        ),
                                                    ),
                                                    onTap: () {
                                                        Navigator.pop(
                                                            bottomSheetContext);
                                                        _deleteMessage(
                                                            message);
                                                    },
                                                ),
                                            ],
                                        ],
                                    ),
                                ),
                            ],
                        ),
                    ),
                );
            },
        );
    }

    // ============================================
    // ✏️ РЕДАКТИРОВАНИЕ
    // ============================================
    Future<void> _editMessage(Message message) async {
        final controller = TextEditingController(text: message.text ?? '');

        final newText = await showDialog<String>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Редактировать',
                    style: TextStyle(
                        color: RastaTheme.textPrimary,
                        fontSize: 20,
                    ),
                ),
                content: TextField(
                    controller: controller,
                    maxLines: 5,
                    minLines: 1,
                    autofocus: true,
                    style: const TextStyle(
                        color: RastaTheme.textPrimary,
                        fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                        hintText: 'Новый текст...',
                        hintStyle: TextStyle(color: RastaTheme.textMuted),
                    ),
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                            'Отмена',
                            style: TextStyle(
                                color: RastaTheme.textMuted,
                                fontSize: 16,
                            ),
                        ),
                    ),
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text(
                            'Сохранить',
                            style: TextStyle(
                                color: RastaTheme.rastaYellow,
                                fontSize: 16,
                            ),
                        ),
                    ),
                ],
            ),
        );

        if (newText != null &&
            newText.isNotEmpty &&
            newText != message.text) {
            if (!mounted) return;

            final chat = Provider.of<ChatProvider>(context, listen: false);
            final success = await chat.editMessage(message.id, newText);

            if (!success) {
                _showError('Не удалось отредактировать');
            }
        }
    }

    // ============================================
    // 🗑️ УДАЛЕНИЕ
    // ============================================
    Future<void> _deleteMessage(Message message) async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Удалить сообщение?',
                    style: TextStyle(
                        color: RastaTheme.textPrimary,
                        fontSize: 20,
                    ),
                ),
                content: const Text(
                    'Сообщение будет помечено как удалённое.',
                    style: TextStyle(
                        color: RastaTheme.textSecondary,
                        fontSize: 15,
                    ),
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                            'Отмена',
                            style: TextStyle(
                                color: RastaTheme.textMuted,
                                fontSize: 16,
                            ),
                        ),
                    ),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                            'Удалить',
                            style: TextStyle(
                                color: RastaTheme.error,
                                fontSize: 16,
                            ),
                        ),
                    ),
                ],
            ),
        );

        if (confirmed == true && mounted) {
            final chat = Provider.of<ChatProvider>(context, listen: false);
            final success = await chat.deleteMessage(message.id);

            if (!success) {
                _showError('Не удалось удалить');
            }
        }
    }
}