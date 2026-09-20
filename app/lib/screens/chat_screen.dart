// =====================================================
// 💬 BMSChat — ЭКРАН ЧАТА
// =====================================================
// 🎯 МИГРАЦИЯ НА reverse: true
// 🎯 ПАГИНАЦИЯ: подгрузка старых сообщений
// 🎯 ОТСТУП ПОД СИСТЕМНУЮ НАВИГАЦИЮ
// 🎯 ШАГ 15: настройки канала + вступление в канал
// 🎯 ЭТАП B.1: меню «⋮» в AppBar + панель быстрых действий
// 🎯 ЭТАП B.2: счётчик новых сообщений на кнопке скролла вниз
// 🎯 ЭТАП B.3: цитата с текстом + свайп для ответа
// 🎯 ЭТАП B.4: разделители дат («Сегодня», «Вчера», ...)
// 🎯 ЭТАП D.4: дебаунс _onScroll + троттлинг _triggerLoadMore
// 🎯 ЭТАП E.1: эмодзи-пикер (emoji_picker_flutter)
// 🎯 ЭМОДЗИ «Потарахтеть» в AppBar
// 🎯 ПАНЕЛЬ 4 КНОПОК — только при фокусе
// 🎯 FIX (web upload): sendFile принимает XFile, а не path
// =====================================================

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

    // 🎯 FocusNode — для управления клавиатурой
    final _inputFocusNode = FocusNode();

    bool _isTyping = false;

    bool _initialScrollDone = false;
    int _lastMessageCount = 0;
    int _lastReadBeforeOpen = 0;
    final Map<int, GlobalKey> _messageKeys = {};
    bool _showScrollButton = false;

    // 🎯 ПАГИНАЦИЯ
    bool _isLoadingMore = false;
    int _lastSeenLastId = 0;

    // 🎯 ЭТАП D.4: троттлинг _triggerLoadMore — не чаще 1 раза в 300 ms
    DateTime? _lastLoadMoreAttempt;

    // 🎯 ШАГ 15: индикатор вступления в канал
    bool _isJoining = false;

    // 🎯 ЭТАП B.2: счётчик новых сообщений ниже видимой области
    int _unreadBelowCount = 0;

    // 🎯 ЭТАП B.3: кэш сообщений по id — для быстрого поиска reply
    final Map<int, Message> _messagesById = {};

    // 🎯 ЭТАП E.1: показывать ли панель эмодзи
    bool _showEmojiPicker = false;

    // 🎯 ПАНЕЛЬ 4 КНОПОК: видна только когда пользователь тапнул в поле
    bool _isInputFocused = false;

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
        _inputFocusNode.dispose();
        super.dispose();
    }

    // ============================================
    // 🎯 ПАНЕЛЬ 4 КНОПОК: показать/скрыть
    // ============================================
    void _showInputPanel() {
        if (_isInputFocused) return;
        setState(() => _isInputFocused = true);
    }

    void _hideInputPanel() {
        if (!_isInputFocused && !_showEmojiPicker) return;
        setState(() {
            _isInputFocused = false;
            _showEmojiPicker = false;
        });
        FocusScope.of(context).unfocus();
    }

    // ============================================
    // 📜 СКРОЛЛ
    // 🎯 ЭТАП D.4: оптимизирован
    // ============================================
    void _onScroll() {
        if (!_scrollController.hasClients) return;

        final position = _scrollController.position;
        final pixels = position.pixels;

        final isNearBottom = pixels <= 200;
        final shouldResetUnread = pixels <= 50;

        final needSetState =
            (_showScrollButton == isNearBottom) ||
            (shouldResetUnread && _unreadBelowCount > 0);

        if (needSetState) {
            setState(() {
                _showScrollButton = !isNearBottom;
                if (shouldResetUnread) _unreadBelowCount = 0;
            });
        }

        final isNearTop = pixels >= position.maxScrollExtent - 400;
        if (!isNearTop) {
            _lastLoadMoreAttempt = null;
            return;
        }

        final now = DateTime.now();
        final lastAttempt = _lastLoadMoreAttempt;

        if (lastAttempt != null &&
            now.difference(lastAttempt).inMilliseconds < 300) {
            return;
        }

        _lastLoadMoreAttempt = now;
        _triggerLoadMore();
    }

    GlobalKey _getMessageKey(int messageId) {
        return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
    }

    /// 🎯 ЭТАП B.3: перестраиваем кэш сообщений по id
    void _rebuildMessagesCache(List<Message> messages) {
        _messagesById.clear();
        for (final m in messages) {
            _messagesById[m.id] = m;
        }
    }

    void _onChatChanged() {
        if (!mounted) return;

        final chat = Provider.of<ChatProvider>(context, listen: false);

        _rebuildMessagesCache(chat.messages);

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
                    _unreadBelowCount = 0;
                } else {
                    _unreadBelowCount++;
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

    // ============================================
    // 📎 ВЫБОР ФАЙЛА
    // 🎯 FIX: передаём XFile (не .path) — работает на web
    // ============================================
    Future<void> _pickFile() async {
        _showInputPanel();

        final source = await showModalBottomSheet<ImageSource>(
            context: context,
            backgroundColor: RastaTheme.surface,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => SafeArea(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        const SizedBox(height: 8),
                        Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color:
                                    RastaTheme.textMuted.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                            ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                            'Отправить',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: RastaTheme.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                            leading: const Icon(
                                Icons.photo_library_outlined,
                                color: RastaTheme.rastaYellow,
                                size: 28,
                            ),
                            title: const Text(
                                'Фото из галереи',
                                style: TextStyle(
                                    color: RastaTheme.textPrimary,
                                    fontSize: 16,
                                ),
                            ),
                            onTap: () =>
                                Navigator.pop(context, ImageSource.gallery),
                        ),
                        ListTile(
                            leading: const Icon(
                                Icons.camera_alt_outlined,
                                color: RastaTheme.rastaYellow,
                                size: 28,
                            ),
                            title: const Text(
                                'Сделать фото',
                                style: TextStyle(
                                    color: RastaTheme.textPrimary,
                                    fontSize: 16,
                                ),
                            ),
                            onTap: () =>
                                Navigator.pop(context, ImageSource.camera),
                        ),
                        ListTile(
                            leading: const Icon(
                                Icons.insert_drive_file_outlined,
                                color: RastaTheme.rastaYellow,
                                size: 28,
                            ),
                            title: const Text(
                                'Документ',
                                style: TextStyle(
                                    color: RastaTheme.textPrimary,
                                    fontSize: 16,
                                ),
                            ),
                            onTap: () {
                                Navigator.pop(context);
                                _showInfo('Отправка документов — скоро');
                            },
                        ),
                        const SizedBox(height: 8),
                    ],
                ),
            ),
        );

        if (source == null || !mounted) return;

        try {
            final XFile? image = await _imagePicker.pickImage(
                source: source,
                imageQuality: 50,
                maxWidth: 1280,
                maxHeight: 1280,
            );

            if (image == null) return;
            if (!mounted) return;

            _showInfo('Загрузка...');

            final chat = Provider.of<ChatProvider>(context, listen: false);
            // 🎯 Передаём XFile напрямую — .path на web не работает
            final success = await chat.sendFile(image, 'image');

            if (!mounted) return;

            if (!success) {
                _showError('Не удалось отправить');
            } else {
                _showInfo('Отправлено');
                _scrollToBottom();
            }
        } catch (e) {
            if (!mounted) return;
            _showError('Ошибка: $e');
        }
    }

    // ============================================
    // 🎤 ГОЛОСОВОЕ (заглушка)
    // ============================================
    void _pickVoice() {
        _showInputPanel();
        _showInfo('🎤 Голосовые сообщения — скоро');
    }

    // ============================================
    // 🎯 ЭТАП E.1: ЭМОДЗИ-ПИКЕР
    // ============================================
    void _pickEmoji() {
        if (!_showEmojiPicker) {
            FocusScope.of(context).unfocus();
        }
        setState(() {
            _showEmojiPicker = !_showEmojiPicker;
            if (_showEmojiPicker) _isInputFocused = true;
        });
    }

    /// 🎯 ЭТАП E.1: вставка эмодзи в позицию курсора
    void _insertEmoji(String emoji) {
        final text = _messageController.text;
        final selection = _messageController.selection;

        final cursorPos = selection.isValid ? selection.start : text.length;

        final newText = text.substring(0, cursorPos) +
            emoji +
            text.substring(cursorPos);

        _messageController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
                offset: cursorPos + emoji.length,
            ),
        );

        _onTextChanged(newText);
    }

    // ============================================
    // 📷 КАМЕРА
    // ============================================
    void _pickCamera() {
        _pickFile();
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

    /// 🎯 ЭТАП B.3: скролл к конкретному сообщению
    void _scrollToMessage(int messageId) {
        final key = _messageKeys[messageId];
        if (key == null || key.currentContext == null) {
            _showInfo('Сообщение не в зоне видимости');
            return;
        }

        Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            alignment: 0.3,
        );
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
    // 🎯 ЭТАП B.4: РАЗДЕЛИТЕЛИ ДАТ
    // ============================================
    bool _isSameDay(DateTime a, DateTime b) {
        return a.year == b.year && a.month == b.month && a.day == b.day;
    }

    String _formatDateHeader(DateTime date) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final messageDay = DateTime(date.year, date.month, date.day);

        if (messageDay == today) return 'Сегодня';
        if (messageDay == yesterday) return 'Вчера';

        final diffDays = today.difference(messageDay).inDays;
        if (diffDays > 1 && diffDays < 7) {
            const weekdays = [
                'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс',
            ];
            return weekdays[date.weekday - 1];
        }

        if (date.year == now.year) {
            const months = [
                'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
                'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
            ];
            return '${date.day} ${months[date.month - 1]}';
        }

        return DateFormat('dd.MM.yyyy').format(date);
    }

    Widget _buildDateDivider(DateTime date) {
        return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                ),
                decoration: BoxDecoration(
                    color: RastaTheme.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: RastaTheme.separator.withValues(alpha: 0.5),
                        width: 0.5,
                    ),
                ),
                child: Text(
                    _formatDateHeader(date),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: RastaTheme.textMuted,
                        letterSpacing: 0.3,
                    ),
                ),
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
    // 🎯 ЭТАП B.1: МЕНЮ «⋮» В APPBAR
    // ============================================
    Future<void> _openChatMenu(Chat chat) async {
        final canManage = _canManageChannel(chat);
        final isMember = chat.isMember;
        final canLeave = (chat.isChannel || chat.type == 'group') && isMember;

        final action = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => Container(
                decoration: const BoxDecoration(
                    color: RastaTheme.surface,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                    ),
                ),
                child: SafeArea(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            const SizedBox(height: 8),
                            Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: RastaTheme.textMuted
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(2),
                                ),
                            ),
                            const SizedBox(height: 8),

                            _menuTile(
                                icon: Icons.people_outline,
                                title: 'Участники',
                                onTap: () =>
                                    Navigator.pop(context, 'members'),
                            ),

                            _menuTile(
                                icon: Icons.info_outline,
                                title: 'Информация о чате',
                                onTap: () =>
                                    Navigator.pop(context, 'info'),
                            ),

                            _menuTile(
                                icon: Icons.search,
                                title: 'Поиск в чате',
                                onTap: () => Navigator.pop(context, 'search'),
                            ),

                            _menuTile(
                                icon: Icons.notifications_off_outlined,
                                title: 'Отключить уведомления',
                                onTap: () =>
                                    Navigator.pop(context, 'mute'),
                            ),

                            _menuTile(
                                icon: Icons.cleaning_services_outlined,
                                title: 'Очистить историю',
                                onTap: () =>
                                    Navigator.pop(context, 'clear'),
                            ),

                            if (chat.isChannel && canManage)
                                _menuTile(
                                    icon: Icons.settings_outlined,
                                    title: 'Настройки канала',
                                    onTap: () =>
                                        Navigator.pop(context, 'settings'),
                                ),

                            if (canLeave)
                                _menuTile(
                                    icon: Icons.logout,
                                    title: 'Покинуть чат',
                                    color: RastaTheme.error,
                                    onTap: () =>
                                        Navigator.pop(context, 'leave'),
                                ),

                            const SizedBox(height: 8),
                        ],
                    ),
                ),
            ),
        );

        if (!mounted || action == null) return;

        switch (action) {
            case 'members':
                _openUsers();
                break;
            case 'info':
                _showInfo('Информация — скоро');
                break;
            case 'search':
                _showInfo('Поиск — скоро');
                break;
            case 'mute':
                _showInfo('Уведомления — скоро');
                break;
            case 'clear':
                _showInfo('Очистка истории — скоро');
                break;
            case 'settings':
                _openChannelSettings(chat);
                break;
            case 'leave':
                _showInfo('Выход из чата — скоро');
                break;
        }
    }

    Widget _menuTile({
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        Color? color,
    }) {
        final tileColor = color ?? RastaTheme.textPrimary;

        return ListTile(
            leading: Icon(icon, color: color ?? RastaTheme.rastaYellow, size: 26),
            title: Text(
                title,
                style: TextStyle(
                    color: tileColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                ),
            ),
            onTap: onTap,
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
                        if (activeChat != null &&
                            activeChat.useLogoImage) ...[
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
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                            return Container(
                                                color: RastaTheme
                                                    .surfaceSecondary,
                                                child: const Center(
                                                    child: Text('🎯',
                                                        style: TextStyle(
                                                            fontSize: 20)),
                                                ),
                                            );
                                        },
                                    ),
                                ),
                            ),
                            const SizedBox(width: 10),
                        ],

                        if (activeChat != null &&
                            !activeChat.useLogoImage) ...[
                            Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: activeChat.isChannel
                                        ? const LinearGradient(
                                            colors: [
                                                Color(0xFF9C27B0),
                                                RastaTheme.rastaRed,
                                            ],
                                        )
                                        : const LinearGradient(
                                            colors: [
                                                RastaTheme.rastaRed,
                                                RastaTheme.rastaYellow,
                                            ],
                                        ),
                                    boxShadow: [
                                        BoxShadow(
                                            color: RastaTheme.rastaYellow
                                                .withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                        ),
                                    ],
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
                                    if (activeChat != null)
                                        _buildSubtitle(chat),
                                ],
                            ),
                        ),
                    ],
                ),
                actions: [
                    if (activeChat != null)
                        IconButton(
                            icon: const Icon(Icons.more_vert, size: 26),
                            tooltip: 'Меню',
                            onPressed: () => _openChatMenu(activeChat),
                        ),
                ],
            ),
            body: Column(
                children: [
                    Expanded(
                        child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _hideInputPanel,
                            child: Stack(
                                children: [
                                    chat.isLoadingMessages
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                    RastaTheme.rastaYellow,
                                                ),
                                            ),
                                        )
                                        : chat.messages.isEmpty
                                            ? _buildEmptyState(activeChat
                                                    ?.useLogoImage ??
                                                false)
                                            : ListView.builder(
                                                controller: _scrollController,
                                                reverse: true,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 0,
                                                ),
                                                itemCount:
                                                    chat.messages.length,
                                                itemBuilder: (context, index) {
                                                    final msgIndex = chat
                                                            .messages.length -
                                                        1 -
                                                        index;
                                                    final message = chat
                                                        .messages[msgIndex];
                                                    final isOwn = message
                                                            .senderId ==
                                                        currentUserId;

                                                    final replyTo = message
                                                                .replyToId !=
                                                            null
                                                        ? _messagesById[message
                                                            .replyToId]
                                                        : null;

                                                    final prevMessage =
                                                        msgIndex > 0
                                                            ? chat.messages[
                                                                msgIndex - 1]
                                                            : null;
                                                    final showDate =
                                                        prevMessage == null ||
                                                            !_isSameDay(
                                                                message
                                                                    .createdAt,
                                                                prevMessage
                                                                    .createdAt,
                                                            );

                                                    return Column(
                                                        key: _getMessageKey(
                                                            message.id),
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                            if (showDate)
                                                                _buildDateDivider(
                                                                    message
                                                                        .createdAt,
                                                                ),
                                                            AnimatedMessageWrapper(
                                                                messageId:
                                                                    message
                                                                        .id,
                                                                child: MessageBubble(
                                                                    message:
                                                                        message,
                                                                    isOwn:
                                                                        isOwn,
                                                                    replyTo:
                                                                        replyTo,
                                                                    onLongPress: () =>
                                                                        _showReactionPicker(
                                                                            context,
                                                                            message,
                                                                            isOwn,
                                                                        ),
                                                                    onReply: () {
                                                                        chat.setReplyTo(
                                                                            message);
                                                                    },
                                                                    onReplyTap: replyTo !=
                                                                            null
                                                                        ? () => _scrollToMessage(
                                                                            replyTo.id)
                                                                        : null,
                                                                ),
                                                            ),
                                                        ],
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
                                                        child:
                                                            CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                    Color>(
                                                                    RastaTheme
                                                                        .rastaYellow,
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
                                            scale:
                                                _showScrollButton ? 1.0 : 0.0,
                                            duration: const Duration(
                                                milliseconds: 200),
                                            curve: Curves.easeOutBack,
                                            child: AnimatedOpacity(
                                                opacity: _showScrollButton
                                                    ? 1.0
                                                    : 0.0,
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                child:
                                                    _buildScrollToBottomButton(),
                                            ),
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ),

                    if (isChannelNotMember)
                        _buildJoinChannelBlock(activeChat)
                    else if (canWrite) ...[
                        if (chat.replyToMessage != null)
                            _buildReplyPreview(chat),

                        AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            height: _isInputFocused ? null : 0,
                            child: ClipRect(
                                child: Align(
                                    alignment: Alignment.bottomCenter,
                                    heightFactor: _isInputFocused ? 1.0 : 0.0,
                                    child: _buildQuickActionsBar(),
                                ),
                            ),
                        ),

                        _buildInputField(),
                        if (_showEmojiPicker) _buildEmojiPicker(),
                    ] else
                        _buildBlockedField(permissionError),

                    SizedBox(height: navBarHeight),
                ],
            ),
        );
    }

    // =====================================================
    // 🎯 ЭТАП E.1: ПАНЕЛЬ ЭМОДЗИ
    // =====================================================
    Widget _buildEmojiPicker() {
        return SizedBox(
            height: 280,
            child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                    _insertEmoji(emoji.emoji);
                },
                config: const Config(
                    height: 280,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                        backgroundColor: RastaTheme.background,
                        emojiSizeMax: 26,
                        verticalSpacing: 0,
                        horizontalSpacing: 0,
                        gridPadding: EdgeInsets.zero,
                        recentsLimit: 28,
                        noRecents: Text(
                            'Нет недавних',
                            style: TextStyle(
                                fontSize: 14,
                                color: RastaTheme.textMuted,
                            ),
                            textAlign: TextAlign.center,
                        ),
                        loadingIndicator:
                            CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                RastaTheme.rastaYellow,
                            ),
                        ),
                        columns: 8,
                        buttonMode: ButtonMode.MATERIAL,
                    ),
                    skinToneConfig: SkinToneConfig(
                        enabled: true,
                        dialogBackgroundColor: RastaTheme.surface,
                        indicatorColor: RastaTheme.rastaYellow,
                    ),
                    categoryViewConfig: CategoryViewConfig(
                        backgroundColor: RastaTheme.surface,
                        indicatorColor: RastaTheme.rastaYellow,
                        iconColor: RastaTheme.textMuted,
                        iconColorSelected: RastaTheme.rastaYellow,
                        backspaceColor: RastaTheme.rastaYellow,
                        categoryIcons: CategoryIcons(),
                        recentTabBehavior: RecentTabBehavior.RECENT,
                        customCategoryView: null,
                    ),
                    bottomActionBarConfig: BottomActionBarConfig(
                        showBackspaceButton: true,
                        showSearchViewButton: false,
                        backgroundColor: RastaTheme.surface,
                        buttonColor: RastaTheme.textMuted,
                        buttonIconColor: RastaTheme.textMuted,
                    ),
                    searchViewConfig: SearchViewConfig(
                        backgroundColor: RastaTheme.surface,
                        buttonIconColor: RastaTheme.rastaYellow,
                        hintText: 'Поиск эмодзи',
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 🎯 ЭТАП B.1: ПАНЕЛЬ БЫСТРЫХ ДЕЙСТВИЙ
    // =====================================================
    Widget _buildQuickActionsBar() {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                border: Border(
                    top: BorderSide(
                        color: RastaTheme.separator.withValues(alpha: 0.5),
                        width: 0.5,
                    ),
                ),
            ),
            child: Row(
                children: [
                    _quickAction(
                        icon: Icons.attach_file,
                        tooltip: 'Прикрепить',
                        onTap: _pickFile,
                    ),
                    _quickAction(
                        icon: Icons.camera_alt_outlined,
                        tooltip: 'Камера',
                        onTap: _pickCamera,
                    ),
                    _quickAction(
                        icon: Icons.mic_none,
                        tooltip: 'Голосовое',
                        onTap: _pickVoice,
                    ),
                    _quickAction(
                        icon: _showEmojiPicker
                            ? Icons.keyboard_alt_outlined
                            : Icons.emoji_emotions_outlined,
                        tooltip: _showEmojiPicker
                            ? 'Клавиатура'
                            : 'Эмодзи',
                        onTap: _pickEmoji,
                    ),
                ],
            ),
        );
    }

    Widget _quickAction({
        required IconData icon,
        required String tooltip,
        required VoidCallback onTap,
    }) {
        return Tooltip(
            message: tooltip,
            child: IconButton(
                icon: Icon(icon, size: 24),
                color: RastaTheme.rastaYellow,
                onPressed: onTap,
                splashRadius: 22,
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
    // 🎯 ЭТАП B.2: КНОПКА СКРОЛЛА ВНИЗ С БЕЙДЖЕМ
    // =====================================================
    Widget _buildScrollToBottomButton() {
        return GestureDetector(
            onTap: () {
                _scrollToBottom();
                setState(() {
                    _showScrollButton = false;
                    _unreadBelowCount = 0;
                });
            },
            child: Stack(
                clipBehavior: Clip.none,
                children: [
                    Container(
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
                                    color: RastaTheme.rastaYellow
                                        .withValues(alpha: 0.5),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.3),
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

                    if (_unreadBelowCount > 0)
                        Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 22,
                                    minHeight: 22,
                                ),
                                decoration: BoxDecoration(
                                    color: RastaTheme.error,
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                        color: RastaTheme.background,
                                        width: 2,
                                    ),
                                    boxShadow: [
                                        BoxShadow(
                                            color: RastaTheme.error
                                                .withValues(alpha: 0.6),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                        ),
                                    ],
                                ),
                                child: Text(
                                    _unreadBelowCount > 99
                                        ? '99+'
                                        : '$_unreadBelowCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                    ),
                                ),
                            ),
                        ),
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

        if (activeChat.isPrivateChat) {
            return const Text(
                'личный чат',
                style: TextStyle(
                    fontSize: 13,
                    color: RastaTheme.textMuted,
                ),
            );
        }

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
                                    errorBuilder:
                                        (context, error, stackTrace) {
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
                                    replyTo.displayPreview,
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
                    Expanded(
                        child: TextField(
                            controller: _messageController,
                            focusNode: _inputFocusNode,
                            onChanged: _onTextChanged,
                            onSubmitted: (_) => _sendMessage(),
                            onTap: () {
                                if (_showEmojiPicker) {
                                    setState(() => _showEmojiPicker = false);
                                }
                                _showInputPanel();
                            },
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