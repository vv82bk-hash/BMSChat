// =====================================================
// 💬 BMSChat — ЭКРАН СПИСКА ЧАТОВ (С НЕПРОЧИТАННЫМИ)
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
                                        valueColor: AlwaysStoppedAnimation<Color>(
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
                            // ─────────────────────────────
                            // СПИСОК ЧАТОВ
                            // ─────────────────────────────
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

                            // ─────────────────────────────
                            // ЛОГОТИП СНИЗУ (ярче в 2 раза)
                            // ─────────────────────────────
                            Positioned(
                                bottom: -40,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                    child: Center(
                                        child: Opacity(
                                            opacity: 0.16,   // ← было 0.08
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
                        // БЕЙДЖ НЕПРОЧИТАННЫХ
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
    // 🎨 ИКОНКА ЧАТА (логотип или эмодзи)
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

        return Text(
            chat.icon,
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
    // 📭 ПУСТО (с логотипом)
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