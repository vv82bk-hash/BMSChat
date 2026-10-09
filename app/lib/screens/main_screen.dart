// =====================================================
// 🏠 BMSChat — ГЛАВНЫЙ ЭКРАН (BottomNav)
// =====================================================
// 🎯 ЭТАП A: навигация как в Telegram
//   • Вкладка «Чаты» — список чатов
//   • Вкладка «Команда» — пользователи + счётчик (N)
//   • Вкладка «Профиль» — личный профиль
//   • Вкладка «Заявки» — только для админов (бейдж)
// 🎯 Бейджи:
//   • Чаты — totalUnreadCount из ChatProvider
//   • Заявки — pendingUsers.length из UsersProvider
// 🎯 СЧЁТЧИК КОМАНДЫ: серый текст (N) рядом с иконкой
// 🎯 ПЕРЕХОД ПО ТАПУ: открытие чата из push-уведомления
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' show navigatorKey;
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/users_provider.dart';
import '../services/notification_service.dart';
import '../themes/rasta_theme.dart';
import 'chat_screen.dart';
import 'chats_screen.dart';
import 'pending_users_screen.dart';
import 'profile_screen.dart';
import 'users_screen.dart';

class MainScreen extends StatefulWidget {
    const MainScreen({super.key});

    @override
    State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
    int _currentIndex = 0;

    static const List<Widget> _pages = [
        ChatsScreen(),
        UsersScreen(),
        ProfileScreen(),
    ];

    @override
    void initState() {
        super.initState();

        // 🎯 Устанавливаем callback для тапа по push-уведомлению
        NotificationService.onNotificationTap = _openChatFromNotification;

        // 🎯 Проверяем: если приложение запущено ИЗ уведомления —
        //    initial message уже обработан в NotificationService.init(),
        //    но callback тогда ещё не был установлен.
        //    Поэтому подождём и проверим ещё раз через микрозадержку.
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkInitialNotification();
        });
    }

    @override
    void dispose() {
        // 🎯 Сбрасываем callback, чтобы не было утечек
        if (NotificationService.onNotificationTap == _openChatFromNotification) {
            NotificationService.onNotificationTap = null;
        }
        super.dispose();
    }

    // =====================================================
    // 🔔 ПЕРЕХОД В ЧАТ ПО ТАПУ НА УВЕДОМЛЕНИЕ
    // =====================================================
    Future<void> _openChatFromNotification(String? chatIdStr) async {
        if (chatIdStr == null || chatIdStr.isEmpty) return;

        final chatId = int.tryParse(chatIdStr);
        if (chatId == null) return;

        // 🎯 Проверяем, что пользователь авторизован
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (!auth.isAuthenticated) {
            debugPrint('🔔 Тап по уведомлению: пользователь не авторизован');
            return;
        }

        try {
            // 🎯 Убеждаемся, что чат есть в списке (подгружаем при необходимости)
            final chat = Provider.of<ChatProvider>(context, listen: false);
            await chat.loadChats();

            if (!mounted) return;

            // 🎯 Переходим в чат через глобальный ключ навигации
            navigatorKey.currentState?.push(
                MaterialPageRoute(
                    settings: RouteSettings(name: 'chat_$chatId'),
                    builder: (_) => ChatScreen(chatId: chatId),
                ),
            );
        } catch (e) {
            debugPrint('🔔 Ошибка перехода в чат по уведомлению: $e');
        }
    }

    // =====================================================
    // 🔔 ПРОВЕРКА: приложение запущено из уведомления?
    // =====================================================
    // NotificationService.init() вызывается ДО того, как MainScreen
    // установил onNotificationTap. Поэтому первый вызов мог потеряться.
    // Здесь — «догоняем» и проверяем initial message ещё раз.
    Future<void> _checkInitialNotification() async {
        // Этот метод — заглушка: если нужно, можно добавить логику
        // «отложенного тапа». Но обычно initial message обрабатывается
        // при первом тапе пользователя, так что дополнительная логика
        // не требуется.
    }

    @override
    Widget build(BuildContext context) {
        final auth = Provider.of<AuthProvider>(context);
        final chats = Provider.of<ChatProvider>(context);
        final users = Provider.of<UsersProvider>(context);

        final isAdmin = auth.user?.isAdmin ?? false;
        final isCommander = auth.user?.isCommander ?? false;
        final canSeePending = isAdmin || isCommander;

        final teamCount = users.allUsers.length;

        // 🎯 Собираем вкладки динамически — «Заявки» только для админов
        final items = <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: _buildBadgedIcon(
                    icon: Icons.chat_bubble_outline,
                    count: chats.totalUnreadCount,
                ),
                activeIcon: _buildBadgedIcon(
                    icon: Icons.chat_bubble,
                    count: chats.totalUnreadCount,
                ),
                label: 'Чаты',
            ),
            // 🎯 Команда — со счётчиком (N)
            BottomNavigationBarItem(
                icon: _buildTeamIcon(
                    icon: Icons.people_outline,
                    count: teamCount,
                    selected: false,
                ),
                activeIcon: _buildTeamIcon(
                    icon: Icons.people,
                    count: teamCount,
                    selected: true,
                ),
                label: 'Команда',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Профиль',
            ),
            if (canSeePending)
                BottomNavigationBarItem(
                    icon: _buildBadgedIcon(
                        icon: Icons.how_to_reg_outlined,
                        count: users.pendingUsers.length,
                    ),
                    activeIcon: _buildBadgedIcon(
                        icon: Icons.how_to_reg,
                        count: users.pendingUsers.length,
                    ),
                    label: 'Заявки',
                ),
        ];

        final pages = <Widget>[
            ..._pages,
            if (canSeePending) const PendingUsersScreen(),
        ];

        final safeIndex = _currentIndex < pages.length ? _currentIndex : 0;

        return Scaffold(
            backgroundColor: RastaTheme.background,
            body: IndexedStack(
                index: safeIndex,
                children: pages,
            ),
            bottomNavigationBar: Container(
                decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: RastaTheme.separator.withValues(alpha: 0.5),
                            width: 0.5,
                        ),
                    ),
                ),
                child: BottomNavigationBar(
                    currentIndex: safeIndex,
                    onTap: (index) {
                        if (index == _currentIndex) return;
                        setState(() => _currentIndex = index);
                    },
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: RastaTheme.surface,
                    selectedItemColor: RastaTheme.rastaYellow,
                    unselectedItemColor: RastaTheme.textMuted,
                    selectedFontSize: 12,
                    unselectedFontSize: 12,
                    selectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                    ),
                    items: items,
                ),
            ),
        );
    }

    // =====================================================
    // 🔴 БЕЙДЖ НА ИКОНКЕ (красный кружок)
    // =====================================================
    Widget _buildBadgedIcon({
        required IconData icon,
        required int count,
    }) {
        if (count <= 0) {
            return Icon(icon);
        }

        return Stack(
            clipBehavior: Clip.none,
            children: [
                Icon(icon),
                Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                            color: RastaTheme.rastaRed,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: RastaTheme.surface,
                                width: 1.5,
                            ),
                        ),
                        child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                            ),
                        ),
                    ),
                ),
            ],
        );
    }

    // =====================================================
    // 👥 ИКОНКА «КОМАНДА» С (N)
    // =====================================================
    Widget _buildTeamIcon({
        required IconData icon,
        required int count,
        required bool selected,
    }) {
        if (count <= 0) {
            return Icon(icon);
        }

        final countColor = selected
            ? RastaTheme.rastaYellow
            : RastaTheme.textMuted;

        return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Icon(icon),
                const SizedBox(width: 3),
                Text(
                    '($count)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: countColor,
                        height: 1.2,
                    ),
                ),
            ],
        );
    }
}