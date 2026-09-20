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
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/users_provider.dart';
import '../themes/rasta_theme.dart';
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
    // 🎯 Рисует иконку + серый текст (N) рядом.
    // Если count == 0 — просто иконка.
    Widget _buildTeamIcon({
        required IconData icon,
        required int count,
        required bool selected,
    }) {
        // 🎯 Если пользователей нет — просто иконка
        if (count <= 0) {
            return Icon(icon);
        }

        // 🎯 Если выделено (активная вкладка) — цвет rastaYellow;
        // иначе — RastaTheme.textMuted.
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