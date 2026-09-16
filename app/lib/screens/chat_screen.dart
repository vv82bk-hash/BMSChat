import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_picker.dart';
import '../widgets/typing_indicator.dart';

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

    @override
    void dispose() {
        _messageController.dispose();
        _scrollController.dispose();
        super.dispose();
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
                imageQuality: 70,
                maxWidth: 1920,
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
    void _scrollToBottom() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
                _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                );
            }
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
                title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                            activeChat?.displayName ?? 'Чат',
                            style: const TextStyle(fontSize: 16),
                        ),
                        if (activeChat != null) _buildSubtitle(chat),
                    ],
                ),
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
                                ? _buildEmptyState()
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                    ),
                                    itemCount: chat.messages.length +
                                        (chat.hasTypingUsers ? 1 : 0),
                                    itemBuilder: (context, index) {
                                        if (chat.hasTypingUsers &&
                                            index == chat.messages.length) {
                                            return TypingIndicator(
                                                userName: chat.typingUser ?? '',
                                            );
                                        }

                                        final message = chat.messages[index];
                                        final isOwn =
                                            message.senderId == currentUserId;

                                        return MessageBubble(
                                            message: message,
                                            isOwn: isOwn,
                                            onLongPress: () =>
                                                _showReactionPicker(
                                                    context,
                                                    message,
                                                    isOwn,
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
        final activeChat = chat.activeChat;
        if (activeChat == null) return const SizedBox.shrink();

        if (activeChat.isPrivate) {
            return const Text(
                'личный чат',
                style: TextStyle(
                    fontSize: 11,
                    color: RastaTheme.textMuted,
                ),
            );
        }

        final membersCount = activeChat.membersCount;
        final onlineCount = chat.onlineCount;

        return Text(
            '$membersCount участников, $onlineCount онлайн',
            style: const TextStyle(
                fontSize: 11,
                color: RastaTheme.textMuted,
            ),
        );
    }

    // ============================================
    // 📭 НЕТ СООБЩЕНИЙ
    // ============================================
    Widget _buildEmptyState() {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Text('💬', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                        'Нет сообщений',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Начните переписку первым!',
                        style: TextStyle(
                            fontSize: 14,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: RastaTheme.rastaYellow,
                                    ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    replyTo.displayText,
                                    style: const TextStyle(
                                        fontSize: 13,
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
                            size: 20,
                        ),
                        onPressed: () => chat.clearReplyTo(),
                    ),
                ],
            ),
        );
    }

    // ============================================
    // ⌨️ ПОЛЕ ВВОДА С КНОПКОЙ 📎
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
                    // 📎 Кнопка выбора фото
                    IconButton(
                        icon: const Icon(
                            Icons.attach_file,
                            color: RastaTheme.rastaYellow,
                        ),
                        onPressed: _pickImage,
                        tooltip: 'Фото',
                    ),

                    // Поле ввода
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
                                fontSize: 15,
                            ),
                            decoration: InputDecoration(
                                hintText: 'Сообщение...',
                                hintStyle: const TextStyle(
                                    color: RastaTheme.textMuted,
                                ),
                                filled: true,
                                fillColor: RastaTheme.background,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                ),
                            ),
                        ),
                    ),

                    const SizedBox(width: 4),

                    // ⭕ Отправить
                    CircleAvatar(
                        radius: 24,
                        backgroundColor: RastaTheme.rastaYellow,
                        child: IconButton(
                            icon: const Icon(
                                Icons.send,
                                color: Colors.black,
                                size: 20,
                            ),
                            onPressed: _sendMessage,
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
                        size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(
                            reason ?? 'Только чтение',
                            style: const TextStyle(
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

    // ============================================
    // 😀 ВЫБОР РЕАКЦИИ / ДЕЙСТВИЯ
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
            builder: (bottomSheetContext) {
                return Container(
                    padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 32,
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
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: TextField(
                    controller: controller,
                    maxLines: 5,
                    minLines: 1,
                    autofocus: true,
                    style: const TextStyle(color: RastaTheme.textPrimary),
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
                            style: TextStyle(color: RastaTheme.textMuted),
                        ),
                    ),
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text(
                            'Сохранить',
                            style: TextStyle(color: RastaTheme.rastaYellow),
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
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: const Text(
                    'Сообщение будет помечено как удалённое.',
                    style: TextStyle(color: RastaTheme.textSecondary),
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                            'Отмена',
                            style: TextStyle(color: RastaTheme.textMuted),
                        ),
                    ),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                            'Удалить',
                            style: TextStyle(color: RastaTheme.error),
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