// =====================================================
// 💬 BMSChat — ЭКРАН ЧАТА (С ОТМЕТКОЙ ПРОЧТЕНИЯ)
// =====================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';
import '../widgets/animated_message_wrapper.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_picker.dart';
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

    /// 🎯 ID последнего прочитанного ДО открытия чата
    int _lastReadBeforeOpen = 0;

    @override
    void initState() {
        super.initState();

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
        _messageController.dispose();
        _scrollController.dispose();
        super.dispose();
    }

    // ============================================
    // 📜 ОТСЛЕЖИВАНИЕ ИЗМЕНЕНИЙ ЧАТА
    // ============================================
    void _onChatChanged() {
        if (!mounted) return;

        final chat = Provider.of<ChatProvider>(context, listen: false);

        // 1️⃣ Первый скролл после загрузки сообщений
        if (!_initialScrollDone &&
            !chat.isLoadingMessages &&
            chat.messages.isNotEmpty) {
            _initialScrollDone = true;
            _lastMessageCount = chat.messages.length;

            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_lastReadBeforeOpen > 0 &&
                    chat.messages.any((m) => m.id > _lastReadBeforeOpen)) {
                    _scrollToFirstUnread(_lastReadBeforeOpen);
                } else {
                    _scrollToBottom(jump: true);
                }
            });

            chat.markAsRead();
            return;
        }

        // 2️⃣ Новое сообщение
        if (chat.messages.length > _lastMessageCount) {
            final position = _scrollController.hasClients
                ? _scrollController.position
                : null;
            final isNearBottom = position == null ||
                position.pixels >= position.maxScrollExtent - 300;

            _lastMessageCount = chat.messages.length;

            if (isNearBottom) {
                _scrollToBottom();
            }

            chat.markAsRead();
        }
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

    // ============================================
    // 📎 ВЫБОР ФОТО
    // ============================================
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

    // ============================================
    // ⌨️ ПЕЧАТАЕТ
    // ============================================
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

    // ============================================
    // 📜 АВТОСКРОЛЛ
    // ============================================
    void _scrollToBottom({bool jump = false}) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients) return;

            final maxExtent = _scrollController.position.maxScrollExtent;

            if (jump) {
                _scrollController.jumpTo(maxExtent);
            } else {
                _scrollController.animateTo(
                    maxExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                );
            }
        });
    }

    /// 🎯 Скролл к первому непрочитанному сообщению
    void _scrollToFirstUnread(int lastReadId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients) return;

            final chat = Provider.of<ChatProvider>(context, listen: false);

            final firstUnreadIndex = chat.messages.indexWhere(
                (m) => m.id > lastReadId,
            );

            if (firstUnreadIndex < 0) {
                _scrollToBottom(jump: true);
                return;
            }

            const estimatedHeight = 80.0;
            final targetOffset = firstUnreadIndex * estimatedHeight;

            _scrollController.animateTo(
                targetOffset.clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
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

    // ============================================
    // 👥 ОТКРЫТЬ УЧАСТНИКОВ
    // ============================================
    void _openUsers() {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const UsersScreen(),
            ),
        );
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
                        child: chat.isLoadingMessages
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                    ),
                                    itemCount: chat.messages.length,
                                    itemBuilder: (context, index) {
                                        final message = chat.messages[index];
                                        final isOwn =
                                            message.senderId == currentUserId;

                                        return AnimatedMessageWrapper(
                                            key: ValueKey(message.id),
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
                    ),

                    if (canWrite) ...[
                        if (chat.replyToMessage != null)
                            _buildReplyPreview(chat),
                        _buildInputField(),
                    ] else
                        _buildBlockedField(permissionError),
                ],
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

        if (activeChat.isPrivate) {
            return const Text(
                'личный чат',
                style: TextStyle(
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
    // 😀 ВЫБОР РЕАКЦИИ / ДЕЙСТВИЯ
    // ============================================
    // ✅ ИСПРАВЛЕНО: isScrollControlled + SingleChildScrollView
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
            isScrollControlled: true,   // ✅ разрешает панели быть выше половины экрана
            builder: (bottomSheetContext) {
                return SingleChildScrollView(   // ✅ включает прокрутку
                    child: Container(
                        padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            // ✅ учитывает системную навигацию
                            bottom: 16 + MediaQuery.of(bottomSheetContext).padding.bottom,
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
                                        borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                        children: [
                                            ListTile(
                                                leading: const Icon(
                                                    Icons.reply,
                                                    color: RastaTheme.rastaYellow,
                                                ),
                                                title: const Text(
                                                    'Ответить',
                                                    style: TextStyle(
                                                        color: RastaTheme.textPrimary,
                                                        fontSize: 16,
                                                    ),
                                                ),
                                                onTap: () {
                                                    Navigator.pop(bottomSheetContext);
                                                    chat.setReplyTo(message);
                                                },
                                            ),

                                            if (isOwn) ...[
                                                ListTile(
                                                    leading: const Icon(
                                                        Icons.edit,
                                                        color: RastaTheme.rastaYellow,
                                                    ),
                                                    title: const Text(
                                                        'Редактировать',
                                                        style: TextStyle(
                                                            color: RastaTheme.textPrimary,
                                                            fontSize: 16,
                                                        ),
                                                    ),
                                                    onTap: () {
                                                        Navigator.pop(bottomSheetContext);
                                                        _editMessage(message);
                                                    },
                                                ),
                                                ListTile(
                                                    leading: const Icon(
                                                        Icons.delete_outline,
                                                        color: RastaTheme.error,
                                                    ),
                                                    title: const Text(
                                                        'Удалить',
                                                        style: TextStyle(
                                                            color: RastaTheme.error,
                                                            fontSize: 16,
                                                        ),
                                                    ),
                                                    onTap: () {
                                                        Navigator.pop(bottomSheetContext);
                                                        _deleteMessage(message);
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

        if (newText != null && newText.isNotEmpty && newText != message.text) {
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