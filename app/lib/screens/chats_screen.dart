// =====================================================
// 💬 BMSChat — ЭКРАН СПИСКА ЧАТОВ
// =====================================================
// 🎯 ШАГ 14: управление каналами
//   • Кнопка «+» в AppBar (для canCreateFeed)
//   • Тап на публичный канал без участия → «Вступить?»
//   • Иконка канала через displayEmoji
//   • Бейдж «Вступить» для публичных без участия
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/users_provider.dart';
import '../themes/rasta_theme.dart';
import '../utils/app_logger.dart';
import 'chat_screen.dart';
import 'create_channel_screen.dart';
import 'profile_screen.dart';
import 'users_screen.dart';

class ChatsScreen extends StatefulWidget {
    const ChatsScreen({super.key});

    @override
    State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
    bool _initialLoadDone = false;

    @override
    void initState() {
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadChats();
        });
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

    // ============================================
    // 📂 ОТКРЫТИЕ ЧАТА
    // ============================================
    Future<void> _openChat(Chat chat) async {
        AppLogger.info('📂 Открытие: ${chat.title}');

        // 🎯 ШАГ 14: если это канал, где я НЕ участник — предложить вступить
        if (chat.isChannel && !chat.isMember) {
            if (chat.isPrivate) {
                _showInfo('Это приватный канал — нужно приглашение');
                return;
            }

            final shouldJoin = await _confirmJoin(chat);
            if (shouldJoin != true) return;
            if (!mounted) return;   // 🎯 защита от async gap

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

        if (!mounted) return;   // 🎯 защита от async gap

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.openChat(chat.id);

        if (!mounted) return;

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

    Future<void> _logout() async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Выход',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: const Text(
                    'Вы уверены, что хотите выйти?',
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
                            'Выйти',
                            style: TextStyle(color: RastaTheme.error),
                        ),
                    ),
                ],
            ),
        );

        if (confirmed == true && mounted) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final chat = Provider.of<ChatProvider>(context, listen: false);
            final users = Provider.of<UsersProvider>(context, listen: false);

            await chat.clear();
            users.clear();
            await auth.logout();

            if (!mounted) return;

            Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
            );
        }
    }

    @override
    Widget build(BuildContext context) {
        final auth = Provider.of<AuthProvider>(context);

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Row(
                    children: [
                        Text('🎯', style: TextStyle(fontSize: 28)),
                        SizedBox(width: 10),
                        Text(
                            'Чаты',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                            ),
                        ),
                    ],
                ),
                actions: [
                    // 🎯 ШАГ 14: кнопка «+» для создания канала
                    if (auth.canCreateFeed) _buildCreateChannelButton(),
                    _buildUsersButton(),
                    IconButton(
                        icon: const Icon(Icons.person_outline, size: 26),
                        onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                ),
                            );
                        },
                        tooltip: 'Профиль',
                    ),
                    IconButton(
                        icon: const Icon(Icons.logout, size: 26),
                        onPressed: _logout,
                        tooltip: 'Выйти',
                    ),
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
                                child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                    ),
                                    itemCount: chat.chats.length,
                                    itemBuilder: (context, index) {
                                        return _buildChatTile(
                                            chat.chats[index],
                                            chat,
                                        );
                                    },
                                ),
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

    // ============================================
    // 👥 КНОПКА «УЧАСТНИКИ» С БЕЙДЖЕМ
    // ============================================
    Widget _buildUsersButton() {
        final users = Provider.of<UsersProvider>(context);
        final auth = Provider.of<AuthProvider>(context);
        final count = auth.canApproveUsers ? users.pendingCount : 0;

        return Stack(
            children: [
                IconButton(
                    icon: const Icon(Icons.people_outline, size: 26),
                    tooltip: 'Участники',
                    onPressed: _openUsers,
                ),
                if (count > 0)
                    Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                            ),
                            decoration: BoxDecoration(
                                color: RastaTheme.error,
                                borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                            ),
                            child: Text(
                                count > 99 ? '99+' : '$count',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                            ),
                        ),
                    ),
            ],
        );
    }

    // =====================================================
    // 🎴 КАРТОЧКА ЧАТА
    // =====================================================
    Widget _buildChatTile(Chat chat, ChatProvider provider) {
        final onlineInfo = _getOnlineInfo(chat, provider);

        final hasUnread = provider.getUnreadCount(chat) > 0;
        final unreadCount = provider.getUnreadCount(chat);

        // 🎯 ШАГ 14: не в канале?
        final isNotMember = chat.isChannel && !chat.isMember;

        return InkWell(
            onTap: () => _openChat(chat),
            child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                ),
                child: Row(
                    children: [
                        // ─────────────────────────────
                        // АВАТАРКА 68×68
                        // ─────────────────────────────
                        Stack(
                            children: [
                                Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: _getChatGradient(chat.type),
                                        boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                            ),
                                        ],
                                    ),
                                    child: Center(
                                        child: _buildChatIcon(chat),
                                    ),
                                ),
                                if (onlineInfo.showDot)
                                    Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: onlineInfo.isOnline
                                                    ? RastaTheme.online
                                                    : RastaTheme.offline,
                                                border: Border.all(
                                                    color:
                                                        RastaTheme.background,
                                                    width: 2.5,
                                                ),
                                            ),
                                        ),
                                    ),
                                // 🎯 ШАГ 14: замок для не-участников приватных
                                if (isNotMember && chat.isPrivate)
                                    Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: RastaTheme.surface,
                                                border: Border.all(
                                                    color: RastaTheme
                                                        .background,
                                                    width: 2,
                                                ),
                                            ),
                                            child: const Icon(
                                                Icons.lock,
                                                size: 12,
                                                color: RastaTheme.textMuted,
                                            ),
                                        ),
                                    ),
                            ],
                        ),

                        const SizedBox(width: 14),

                        // ─────────────────────────────
                        // ТЕКСТ
                        // ─────────────────────────────
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Row(
                                        children: [
                                            Expanded(
                                                child: Text(
                                                    chat.title,
                                                    style: TextStyle(
                                                        fontSize: 19,
                                                        fontWeight: hasUnread
                                                            ? FontWeight.w700
                                                            : FontWeight.w600,
                                                        color: RastaTheme
                                                            .textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                ),
                                            ),
                                            if (chat.lastMessageTime
                                                .isNotEmpty)
                                                Text(
                                                    chat.lastMessageTime,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: hasUnread
                                                            ? RastaTheme
                                                                .rastaYellow
                                                            : RastaTheme
                                                                .textMuted,
                                                        fontWeight: hasUnread
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                    ),
                                                ),
                                        ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                        children: [
                                            Expanded(
                                                child: Text(
                                                    chat.lastMessagePreview,
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: hasUnread
                                                            ? RastaTheme
                                                                .textPrimary
                                                            : RastaTheme
                                                                .textSecondary,
                                                        fontWeight: hasUnread
                                                            ? FontWeight.w600
                                                            : FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                ),
                                            ),
                                            if (onlineInfo.text != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                    onlineInfo.text!,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: onlineInfo
                                                                .isOnline
                                                            ? RastaTheme.online
                                                            : RastaTheme
                                                                .textMuted,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                    ),
                                                ),
                                            ],
                                        ],
                                    ),
                                ],
                            ),
                        ),

                        // ─────────────────────────────
                        // БЕЙДЖИ
                        // ─────────────────────────────
                        if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                    color: RastaTheme.rastaYellow,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                        BoxShadow(
                                            color: RastaTheme.rastaYellow
                                                .withValues(alpha: 0.5),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                        ),
                                    ],
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                ),
                                child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                ),
                            ),
                        ] else if (isNotMember) ...[
                            // 🎯 ШАГ 14: значок «можно вступить»
                            const SizedBox(width: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                    color: RastaTheme.rastaGreen
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                    'Вступить',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: RastaTheme.rastaGreen,
                                        fontWeight: FontWeight.w700,
                                    ),
                                ),
                            ),
                        ] else if (chat.isAdmin) ...[
                            const SizedBox(width: 8),
                            const Icon(
                                Icons.star,
                                size: 18,
                                color: RastaTheme.rastaYellow,
                            ),
                        ],
                    ],
                ),
            ),
        );
    }

    // ============================================
    // 🎨 ИКОНКА ЧАТА
    // ============================================
    Widget _buildChatIcon(Chat chat) {
        if (chat.useLogoImage) {
            return ClipOval(
                child: Image.asset(
                    'assets/images/logo.png',
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                        return Text(
                            chat.icon,
                            style: const TextStyle(fontSize: 34),
                        );
                    },
                ),
            );
        }

        // 🎯 ШАГ 14: для каналов — displayEmoji (учитывает emoji или дефолт)
        final icon = chat.isChannel ? chat.displayEmoji : chat.icon;

        return Text(
            icon,
            style: const TextStyle(fontSize: 34),
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