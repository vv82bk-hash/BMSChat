// =====================================================
// 💬 BMSChat — ЭКРАН СПИСКА ЧАТОВ
// =====================================================
// 🎯 ШАГ 14: управление каналами
// 🎯 ЗАГОЛОВОК: ⚔️ Bob Marley Squad ✌️
// 🎯 ЭТАП A: экран стал вкладкой в MainScreen
// 🎯 ЭТАП C.3: Telegram-стиль списка
// 🎯 ЭТАП C.4: Search bar + секция «📌 Закреплённые»
// 🎯 ЭТАП C.5: долгий тап → меню + свайп влево → удалить
//   • Долгий тап → bottom sheet (Закрепить / Уведомления / Удалить)
//   • Свайп влево → удалить (только админам)
//   • Удаление — локальное (hideChatLocally)
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';
import '../utils/app_logger.dart';
import 'chat_screen.dart';
import 'create_channel_screen.dart';

class ChatsScreen extends StatefulWidget {
    const ChatsScreen({super.key});

    @override
    State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
    bool _initialLoadDone = false;

    // 🎯 ЭТАП C.4: поиск
    final _searchController = TextEditingController();
    final _searchFocusNode = FocusNode();
    String _searchQuery = '';
    bool _isSearching = false;

    @override
    void initState() {
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadChats();
        });
    }

    @override
    void dispose() {
        _searchController.dispose();
        _searchFocusNode.dispose();
        super.dispose();
    }

    Future<void> _loadChats() async {
        final chat = Provider.of<ChatProvider>(context, listen: false);
        await chat.loadChats();

        if (mounted) {
            setState(() => _initialLoadDone = true);
        }
    }

    Future<void> _onRefresh() async {
        final chat = Provider.of<ChatProvider>(context, listen: false);
        await chat.loadChats();
    }

    // 🎯 ЭТАП C.4: переключение поиска
    void _toggleSearch() {
        setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) {
                _searchController.clear();
                _searchQuery = '';
                _searchFocusNode.unfocus();
            }
        });

        if (_isSearching) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
                _searchFocusNode.requestFocus();
            });
        }
    }

    // 🎯 ЭТАП C.4: фильтрация чатов по поиску
    List<Chat> _filterChats(List<Chat> chats) {
        if (_searchQuery.isEmpty) return chats;
        final q = _searchQuery.toLowerCase().trim();
        return chats.where((c) {
            return c.title.toLowerCase().contains(q);
        }).toList();
    }

    // ============================================
    // 📂 ОТКРЫТИЕ ЧАТА
    // ============================================
    Future<void> _openChat(Chat chat) async {
        AppLogger.info('📂 Открытие: ${chat.title}');

        if (chat.isChannel && !chat.isMember) {
            if (chat.isPrivate) {
                _showInfo('Это приватный канал — нужно приглашение');
                return;
            }

            final shouldJoin = await _confirmJoin(chat);
            if (shouldJoin != true) return;
            if (!mounted) return;

            final chatProvider =
                Provider.of<ChatProvider>(context, listen: false);
            final joined = await chatProvider.joinChannel(chat.id);

            if (!mounted) return;

            if (!joined) {
                final reason = chatProvider.chatsError ?? 'неизвестная ошибка';
                _showInfo('Не удалось вступить: $reason');
                return;
            }

            _showInfo('Вы вступили в канал');
        }

        if (!mounted) return;

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.openChat(chat.id);

        if (!mounted) return;

        if (_isSearching) {
            _toggleSearch();
        }

        Navigator.of(context).push(
            PageRouteBuilder(
                pageBuilder: (_, __, ___) => ChatScreen(chatId: chat.id),
                transitionsBuilder: (_, animation, __, child) {
                    final curvedAnimation = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                    );

                    return SlideTransition(
                        position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                        ).animate(curvedAnimation),
                        child: FadeTransition(
                            opacity: curvedAnimation,
                            child: child,
                        ),
                    );
                },
                transitionDuration: const Duration(milliseconds: 300),
            ),
        );
    }

    // ============================================
    // 📢 СОЗДАНИЕ КАНАЛА
    // ============================================
    Future<void> _openCreateChannel() async {
        final created = await Navigator.push<Chat>(
            context,
            MaterialPageRoute(
                builder: (_) => const CreateChannelScreen(),
            ),
        );

        if (!mounted) return;

        if (created != null) {
            final chatProvider =
                Provider.of<ChatProvider>(context, listen: false);
            await chatProvider.loadChats();

            if (!mounted) return;

            await _openChat(created);
        }
    }

    // ============================================
    // 🎯 ПОДТВЕРЖДЕНИЕ ВСТУПЛЕНИЯ
    // ============================================
    Future<bool?> _confirmJoin(Chat chat) {
        return showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Вступить в канал?',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: Text(
                    'Вы станете участником канала «${chat.title}» '
                    'и сможете писать сообщения.',
                    style: const TextStyle(color: RastaTheme.textSecondary),
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
                            'Вступить',
                            style: TextStyle(
                                color: RastaTheme.rastaYellow,
                                fontWeight: FontWeight.w600,
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 🎯 ЭТАП C.5: КОНТЕКСТНОЕ МЕНЮ (долгий тап)
    // =====================================================
    Future<void> _showChatContextMenu(Chat chat, ChatProvider provider) async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isAdmin = auth.user?.isAdmin ?? false;
        final isPinned = provider.isPinned(chat.id);

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
                            const SizedBox(height: 12),

                            // Заголовок — название чата
                            Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 6,
                                ),
                                child: Text(
                                    chat.title,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: RastaTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                ),
                            ),
                            const SizedBox(height: 4),

                            // 📌 Закрепить / Открепить
                            _menuTile(
                                icon: isPinned
                                    ? Icons.push_pin_outlined
                                    : Icons.push_pin,
                                title: isPinned
                                    ? 'Открепить'
                                    : 'Закрепить',
                                onTap: () =>
                                    Navigator.pop(context, 'toggle_pin'),
                            ),

                            // 🔕 Отключить уведомления
                            _menuTile(
                                icon: Icons.notifications_off_outlined,
                                title: 'Отключить уведомления',
                                onTap: () =>
                                    Navigator.pop(context, 'mute'),
                            ),

                            // 🗑 Удалить (только админам)
                            if (isAdmin)
                                _menuTile(
                                    icon: Icons.delete_outline,
                                    title: 'Удалить',
                                    color: RastaTheme.error,
                                    onTap: () =>
                                        Navigator.pop(context, 'delete'),
                                ),

                            const SizedBox(height: 8),
                        ],
                    ),
                ),
            ),
        );

        if (!mounted || action == null) return;

        switch (action) {
            case 'toggle_pin':
                await provider.togglePin(chat.id);
                _showInfo(
                    provider.isPinned(chat.id)
                        ? '📌 Закреплено'
                        : '📌 Откреплено',
                );
                break;
            case 'mute':
                _showInfo('🔕 Уведомления — скоро');
                break;
            case 'delete':
                await _confirmDeleteChat(chat);
                break;
        }
    }

    // =====================================================
    // 🎯 ЭТАП C.5: ПОДТВЕРЖДЕНИЕ УДАЛЕНИЯ
    // =====================================================
    Future<void> _confirmDeleteChat(Chat chat) async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Удалить чат?',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: Text(
                    'Чат «${chat.title}» будет скрыт из списка. '
                    'При следующей загрузке он может вернуться.',
                    style: const TextStyle(color: RastaTheme.textSecondary),
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
            final provider = Provider.of<ChatProvider>(context, listen: false);
            provider.hideChatLocally(chat.id);
            _showInfo('Чат скрыт из списка');
        }
    }

    // =====================================================
    // 🎯 ЭТАП C.5: ПОДТВЕРЖДЕНИЕ СВАЙПА
    // =====================================================
    Future<bool> _confirmSwipeDelete(Chat chat) async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Удалить чат?',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: Text(
                    'Чат «${chat.title}» будет скрыт из списка.',
                    style: const TextStyle(color: RastaTheme.textSecondary),
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

        return confirmed == true;
    }

    // =====================================================
    // 🎯 ЕДИНЫЙ МЕНЮ-ТАЙЛ
    // =====================================================
    Widget _menuTile({
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        Color? color,
    }) {
        final tileColor = color ?? RastaTheme.textPrimary;

        return ListTile(
            leading: Icon(
                icon,
                color: color ?? RastaTheme.rastaYellow,
                size: 24,
            ),
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

    @override
    Widget build(BuildContext context) {
        final auth = Provider.of<AuthProvider>(context);

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                automaticallyImplyLeading: false,
                title: _isSearching
                    ? _buildSearchField()
                    : const Row(
                        children: [
                            Text('⚔️', style: TextStyle(fontSize: 26)),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    'Bob Marley Squad',
                                    style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                ),
                            ),
                            Text('✌️', style: TextStyle(fontSize: 24)),
                        ],
                    ),
                actions: [
                    IconButton(
                        icon: Icon(
                            _isSearching ? Icons.close : Icons.search,
                            size: 26,
                        ),
                        tooltip: _isSearching ? 'Закрыть поиск' : 'Поиск',
                        onPressed: _toggleSearch,
                    ),
                    if (auth.canCreateFeed && !_isSearching)
                        _buildCreateChannelButton(),
                ],
            ),
            body: Consumer<ChatProvider>(
                builder: (context, chat, child) {
                    if (chat.isLoadingChats && !_initialLoadDone) {
                        return const Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                RastaTheme.rastaYellow,
                                            ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                        'Загрузка чатов...',
                                        style: TextStyle(
                                            color: RastaTheme.textMuted,
                                            fontSize: 16,
                                        ),
                                    ),
                                ],
                            ),
                        );
                    }

                    if (chat.chatsError != null) {
                        return _buildErrorState(chat.chatsError!);
                    }

                    if (chat.chats.isEmpty) {
                        return _buildEmptyState();
                    }

                    return Stack(
                        children: [
                            RefreshIndicator(
                                onRefresh: _onRefresh,
                                color: RastaTheme.rastaYellow,
                                backgroundColor: RastaTheme.surface,
                                child: _buildChatsList(chat),
                            ),

                            Positioned(
                                bottom: -40,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                    child: Center(
                                        child: Opacity(
                                            opacity: 0.16,
                                            child: ClipOval(
                                                child: Image.asset(
                                                    'assets/images/logo.png',
                                                    width: 320,
                                                    height: 320,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                        return const SizedBox
                                                            .shrink();
                                                    },
                                                ),
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                        ],
                    );
                },
            ),
        );
    }

    // =====================================================
    // 🎯 ЭТАП C.4: ПОЛЕ ПОИСКА (в AppBar)
    // =====================================================
    Widget _buildSearchField() {
        return TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (value) {
                setState(() => _searchQuery = value);
            },
            style: const TextStyle(
                color: RastaTheme.textPrimary,
                fontSize: 16,
            ),
            decoration: InputDecoration(
                hintText: 'Поиск по чатам...',
                hintStyle: const TextStyle(
                    color: RastaTheme.textMuted,
                    fontSize: 16,
                ),
                filled: true,
                fillColor: RastaTheme.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                ),
            ),
        );
    }

    // =====================================================
    // 🎯 ЭТАП C.4: СПИСОК ЧАТОВ (с секциями)
    // =====================================================
    Widget _buildChatsList(ChatProvider provider) {
        if (_isSearching && _searchQuery.isNotEmpty) {
            return _buildSearchResults(provider);
        }

        final pinned = provider.pinnedChats;
        final regular = provider.regularChats;

        if (pinned.isEmpty && regular.isEmpty) {
            return _buildEmptyState();
        }

        final List<Widget> items = [];

        if (pinned.isNotEmpty) {
            items.add(_buildSectionHeader('📌 Закреплённые'));
            for (final chat in pinned) {
                items.add(_buildChatTile(chat, provider));
            }
            items.add(const SizedBox(height: 6));
        }

        if (regular.isNotEmpty) {
            if (pinned.isNotEmpty) {
                items.add(_buildSectionHeader('Чаты'));
            }
            for (final chat in regular) {
                items.add(_buildChatTile(chat, provider));
            }
        }

        return ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: items,
        );
    }

    // =====================================================
    // 🎯 ЭТАП C.4: РЕЗУЛЬТАТЫ ПОИСКА
    // =====================================================
    Widget _buildSearchResults(ChatProvider provider) {
        final allChats = [...provider.pinnedChats, ...provider.regularChats];
        final results = _filterChats(allChats);

        if (results.isEmpty) {
            return _buildNoResults();
        }

        return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: results.length,
            itemBuilder: (context, index) {
                return _buildChatTile(results[index], provider);
            },
        );
    }

    // =====================================================
    // 🎯 ЭТАП C.4: ЗАГОЛОВОК СЕКЦИИ
    // =====================================================
    Widget _buildSectionHeader(String title) {
        return Padding(
            padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 6,
            ),
            child: Text(
                title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RastaTheme.textMuted,
                    letterSpacing: 0.5,
                ),
            ),
        );
    }

    // =====================================================
    // 🎯 ЭТАП C.4: НИЧЕГО НЕ НАЙДЕНО
    // =====================================================
    Widget _buildNoResults() {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Text('🔍', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                        'Ничего не найдено',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Попробуйте другой запрос',
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
    // ➕ КНОПКА «СОЗДАТЬ КАНАЛ»
    // ============================================
    Widget _buildCreateChannelButton() {
        return IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 26),
            tooltip: 'Создать канал',
            onPressed: _openCreateChannel,
        );
    }

    // =====================================================
    // 🎴 КАРТОЧКА ЧАТА
    // =====================================================
    Widget _buildChatTile(Chat chat, ChatProvider provider) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isAdmin = auth.user?.isAdmin ?? false;

        // 🎯 ЭТАП C.5: tile в Dismissible (свайп влево)
        final tile = _buildChatTileContent(chat, provider);

        // Только админам разрешён свайп-удалить
        if (!isAdmin) {
            return tile;
        }

        return Dismissible(
            key: ValueKey('chat_${chat.id}'),
            direction: DismissDirection.endToStart,
            background: _buildSwipeBackground(),
            confirmDismiss: (_) => _confirmSwipeDelete(chat),
            onDismissed: (_) {
                provider.hideChatLocally(chat.id);
                _showInfo('Чат скрыт из списка');
            },
            child: tile,
        );
    }

    // =====================================================
    // 🎯 ЭТАП C.5: ФОН СВАЙПА
    // =====================================================
    Widget _buildSwipeBackground() {
        return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: RastaTheme.error.withValues(alpha: 0.15),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: RastaTheme.error.withValues(alpha: 0.2),
                            border: Border.all(
                                color: RastaTheme.error,
                                width: 1.5,
                            ),
                        ),
                        child: const Center(
                            child: Icon(
                                Icons.delete_outline,
                                color: RastaTheme.error,
                                size: 22,
                            ),
                        ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                        'Удалить',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.error,
                        ),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 🎴 КОНТЕНТ КАРТОЧКИ ЧАТА — вынесен из _buildChatTile
    // =====================================================
    Widget _buildChatTileContent(Chat chat, ChatProvider provider) {
        final onlineInfo = _getOnlineInfo(chat, provider);

        final hasUnread = provider.getUnreadCount(chat) > 0;
        final unreadCount = provider.getUnreadCount(chat);

        final isNotMember = chat.isChannel && !chat.isMember;

        return InkWell(
            onTap: () => _openChat(chat),
            onLongPress: () => _showChatContextMenu(chat, provider),
            child: Column(
                children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                        ),
                        child: Row(
                            children: [
                                // ─────────────────────────────
                                // АВАТАР 54×54 + рамка при непрочитанных
                                // ─────────────────────────────
                                Stack(
                                    children: [
                                        Container(
                                            width: hasUnread ? 58 : 54,
                                            height: hasUnread ? 58 : 54,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: hasUnread
                                                    ? Border.all(
                                                        color: RastaTheme
                                                            .rastaYellow,
                                                        width: 2.5,
                                                    )
                                                    : null,
                                            ),
                                            child: Center(
                                                child: Container(
                                                    width: 54,
                                                    height: 54,
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        gradient:
                                                            _getChatGradient(
                                                                chat.type),
                                                        boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.25),
                                                                blurRadius: 6,
                                                                offset:
                                                                    const Offset(
                                                                        0, 2),
                                                            ),
                                                        ],
                                                    ),
                                                    child: Center(
                                                        child:
                                                            _buildChatIcon(
                                                                chat),
                                                    ),
                                                ),
                                            ),
                                        ),

                                        if (onlineInfo.showDot)
                                            Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: onlineInfo
                                                                .isOnline
                                                            ? RastaTheme.online
                                                            : RastaTheme
                                                                .offline,
                                                        border: Border.all(
                                                            color: RastaTheme
                                                                .background,
                                                            width: 2,
                                                        ),
                                                    ),
                                                ),
                                            ),

                                        if (isNotMember && chat.isPrivate)
                                            Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: RastaTheme
                                                            .surface,
                                                        border: Border.all(
                                                            color: RastaTheme
                                                                .background,
                                                            width: 1.5,
                                                        ),
                                                    ),
                                                    child: const Icon(
                                                        Icons.lock,
                                                        size: 10,
                                                        color: RastaTheme
                                                            .textMuted,
                                                    ),
                                                ),
                                            ),

                                        if (provider.isPinned(chat.id))
                                            Positioned(
                                                left: 0,
                                                top: 0,
                                                child: Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: RastaTheme
                                                            .surface,
                                                        border: Border.all(
                                                            color: RastaTheme
                                                                .background,
                                                            width: 1.5,
                                                        ),
                                                    ),
                                                    child: const Center(
                                                        child: Text(
                                                            '📌',
                                                            style:
                                                                TextStyle(
                                                                    fontSize:
                                                                        10),
                                                        ),
                                                    ),
                                                ),
                                            ),
                                    ],
                                ),

                                const SizedBox(width: 12),

                                // ─────────────────────────────
                                // ТЕКСТ
                                // ─────────────────────────────
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                            Row(
                                                children: [
                                                    Expanded(
                                                        child: Text(
                                                            chat.title,
                                                            style: TextStyle(
                                                                fontSize: 17,
                                                                fontWeight:
                                                                    hasUnread
                                                                        ? FontWeight
                                                                            .w700
                                                                        : FontWeight
                                                                            .w600,
                                                                color: RastaTheme
                                                                    .textPrimary,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                        ),
                                                    ),
                                                    if (chat.lastMessageTime
                                                        .isNotEmpty) ...[
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                            chat
                                                                .lastMessageTime,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: hasUnread
                                                                    ? RastaTheme
                                                                        .rastaYellow
                                                                    : RastaTheme
                                                                        .textMuted,
                                                            ),
                                                        ),
                                                    ],
                                                ],
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                                children: [
                                                    Expanded(
                                                        child: Text(
                                                            chat
                                                                .lastMessagePreview,
                                                            style: TextStyle(
                                                                fontSize: 15,
                                                                color: hasUnread
                                                                    ? RastaTheme
                                                                        .textPrimary
                                                                    : RastaTheme
                                                                        .textSecondary,
                                                                fontWeight:
                                                                    hasUnread
                                                                        ? FontWeight
                                                                            .w600
                                                                        : FontWeight
                                                                            .w400,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                        ),
                                                    ),
                                                    if (onlineInfo.text !=
                                                        null) ...[
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                            onlineInfo.text!,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: onlineInfo
                                                                        .isOnline
                                                                    ? RastaTheme
                                                                        .online
                                                                    : RastaTheme
                                                                        .textMuted,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                            ),
                                                        ),
                                                    ],
                                                ],
                                            ),
                                        ],
                                    ),
                                ),

                                // ─────────────────────────────
                                // БЕЙДЖИ / ЗВЁЗДЫ
                                // ─────────────────────────────
                                if (hasUnread) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                            color: RastaTheme.rastaYellow,
                                            borderRadius:
                                                BorderRadius.circular(11),
                                            boxShadow: [
                                                BoxShadow(
                                                    color: RastaTheme
                                                        .rastaYellow
                                                        .withValues(alpha: 0.5),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                ),
                                            ],
                                        ),
                                        constraints: const BoxConstraints(
                                            minWidth: 22,
                                            minHeight: 22,
                                        ),
                                        child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                            ),
                                            textAlign: TextAlign.center,
                                        ),
                                    ),
                                ] else if (isNotMember) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                            color: RastaTheme.rastaGreen
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(9),
                                        ),
                                        child: const Text(
                                            'Вступить',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: RastaTheme.rastaGreen,
                                                fontWeight: FontWeight.w700,
                                            ),
                                        ),
                                    ),
                                ] else if (chat.isAdmin) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                        Icons.star,
                                        size: 16,
                                        color: RastaTheme.rastaYellow,
                                    ),
                                ],
                            ],
                        ),
                    ),

                    // РАЗДЕЛИТЕЛЬ
                    Padding(
                        padding: const EdgeInsets.only(left: 80),
                        child: Container(
                            height: 0.5,
                            color: RastaTheme.separator.withValues(alpha: 0.5),
                        ),
                    ),
                ],
            ),
        );
    }

    // ============================================
    // 🎨 ИКОНКА ЧАТА
    // ============================================
    Widget _buildChatIcon(Chat chat) {
        final icon = chat.isChannel ? chat.displayEmoji : chat.icon;

        return Text(
            icon,
            style: const TextStyle(fontSize: 26),
        );
    }

    _OnlineInfo _getOnlineInfo(Chat chat, ChatProvider provider) {
        switch (chat.type) {
            case 'private':
                return const _OnlineInfo(showDot: true, isOnline: false);

            case 'general':
            case 'group':
                if (provider.onlineCount == 0) {
                    return const _OnlineInfo(showDot: false);
                }
                return _OnlineInfo(
                    showDot: false,
                    isOnline: true,
                    text: '${provider.onlineCount} онлайн',
                );

            case 'channel':
            default:
                return const _OnlineInfo(showDot: false);
        }
    }

    LinearGradient _getChatGradient(String type) {
        switch (type) {
            case 'general':
                return const LinearGradient(
                    colors: [RastaTheme.rastaRed, RastaTheme.rastaYellow],
                );
            case 'group':
                return const LinearGradient(
                    colors: [RastaTheme.rastaGreen, RastaTheme.rastaYellow],
                );
            case 'channel':
                return const LinearGradient(
                    colors: [Color(0xFF9C27B0), RastaTheme.rastaRed],
                );
            case 'private':
            default:
                return const LinearGradient(
                    colors: [RastaTheme.rastaYellow, RastaTheme.rastaGreen],
                );
        }
    }

    // =====================================================
    // 📭 ПУСТО
    // =====================================================
    Widget _buildEmptyState() {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    Opacity(
                        opacity: 0.15,
                        child: ClipOval(
                            child: Image.asset(
                                'assets/images/logo.png',
                                width: 180,
                                height: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                    return const Text(
                                        '📭',
                                        style: TextStyle(fontSize: 96),
                                    );
                                },
                            ),
                        ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                        'Нет чатов',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                        'Начните общение с командой',
                        style: TextStyle(
                            fontSize: 16,
                            color: RastaTheme.textMuted.withValues(alpha: 0.8),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildErrorState(String error) {
        return Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Icon(
                            Icons.error_outline,
                            size: 72,
                            color: RastaTheme.error,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                            'Ошибка загрузки',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: RastaTheme.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            error,
                            style: const TextStyle(
                                fontSize: 15,
                                color: RastaTheme.textMuted,
                            ),
                            textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                            onPressed: _loadChats,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Повторить'),
                        ),
                    ],
                ),
            ),
        );
    }

    // ============================================
    // 🔔 SNACKBAR
    // ============================================
    void _showInfo(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.surfaceSecondary,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
            ),
        );
    }
}

class _OnlineInfo {
    final bool showDot;
    final bool isOnline;
    final String? text;

    const _OnlineInfo({
        required this.showDot,
        this.isOnline = false,
        this.text,
    });
}