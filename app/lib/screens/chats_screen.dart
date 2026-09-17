// =====================================================
// 💬 BMSChat — ЭКРАН СПИСКА ЧАТОВ
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
    // 📂 ОТКРЫТИЕ ЧАТА С АНИМАЦИЕЙ (снизу вверх)
    // ============================================
    Future<void> _openChat(Chat chat) async {
        AppLogger.info('📂 Открытие: ${chat.displayName}');

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
                            begin: const Offset(0, 1), // снизу
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
                        Text('🎯', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 8),
                        Text('Чаты'),
                    ],
                ),
                actions: [
                    // 👥 Участники с бейджем заявок
                    _buildUsersButton(),
                    IconButton(
                        icon: const Icon(Icons.person_outline),
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
                        icon: const Icon(Icons.logout),
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

                    return RefreshIndicator(
                        onRefresh: _onRefresh,
                        color: RastaTheme.rastaYellow,
                        backgroundColor: RastaTheme.surface,
                        child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: chat.chats.length,
                            itemBuilder: (context, index) {
                                return _buildChatTile(chat.chats[index], chat);
                            },
                        ),
                    );
                },
            ),
        );
    }

    // ============================================
    // 👥 КНОПКА «УЧАСТНИКИ» С БЕЙДЖЕМ ЗАЯВОК
    // ============================================
    Widget _buildUsersButton() {
        final users = Provider.of<UsersProvider>(context);
        final auth = Provider.of<AuthProvider>(context);
        final count = auth.canApproveUsers ? users.pendingCount : 0;

        return Stack(
            children: [
                IconButton(
                    icon: const Icon(Icons.people_outline),
                    tooltip: 'Участники',
                    onPressed: _openUsers,
                ),
                if (count > 0)
                    Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                            ),
                            decoration: BoxDecoration(
                                color: RastaTheme.error,
                                borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                            ),
                            child: Text(
                                count > 99 ? '99+' : '$count',
                                style: const TextStyle(
                                    fontSize: 10,
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

        return InkWell(
            onTap: () => _openChat(chat),
            child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                ),
                child: Row(
                    children: [
                        Stack(
                            children: [
                                Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: _getChatGradient(chat.type),
                                    ),
                                    child: Center(
                                        child: Text(
                                            chat.icon,
                                            style: const TextStyle(fontSize: 28),
                                        ),
                                    ),
                                ),
                                if (onlineInfo.showDot)
                                    Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: onlineInfo.isOnline
                                                    ? RastaTheme.online
                                                    : RastaTheme.offline,
                                                border: Border.all(
                                                    color: RastaTheme.background,
                                                    width: 2,
                                                ),
                                            ),
                                        ),
                                    ),
                            ],
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Row(
                                        children: [
                                            Expanded(
                                                child: Text(
                                                    chat.displayName,
                                                    style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: RastaTheme.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                ),
                                            ),
                                            if (chat.lastMessageTime.isNotEmpty)
                                                Text(
                                                    chat.lastMessageTime,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: RastaTheme.textMuted,
                                                    ),
                                                ),
                                        ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                        children: [
                                            Expanded(
                                                child: Text(
                                                    chat.lastMessagePreview,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        color: RastaTheme.textSecondary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                ),
                                            ),
                                            if (onlineInfo.text != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                    onlineInfo.text!,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: onlineInfo.isOnline
                                                            ? RastaTheme.online
                                                            : RastaTheme.textMuted,
                                                        fontWeight: FontWeight.w600,
                                                    ),
                                                ),
                                            ],
                                        ],
                                    ),
                                ],
                            ),
                        ),

                        if (chat.isAdmin)
                            const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                    Icons.star,
                                    size: 16,
                                    color: RastaTheme.rastaYellow,
                                ),
                            ),
                    ],
                ),
            ),
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

    Widget _buildEmptyState() {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Text('📭', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                        'Нет чатов',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Начните общение с командой',
                        style: TextStyle(
                            fontSize: 14,
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
                            size: 64,
                            color: RastaTheme.error,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                            'Ошибка загрузки',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: RastaTheme.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            error,
                            style: const TextStyle(
                                fontSize: 14,
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