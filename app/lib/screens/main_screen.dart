// =====================================================
// 🏠 BMSChat — ГЛАВНЫЙ ЭКРАН (BottomNav)
// =====================================================
// 🎯 ЭТАП A: навигация как в Telegram
//   • Вкладка «Чаты» — список чатов
//   • Вкладка «Команда» — пользователи
//   • Вкладка «Профиль» — личный профиль
//   • Вкладка «Заявки» — только для админов (бейдж)
// 🎯 Бейджи:
//   • Чаты — totalUnreadCount из ChatProvider
//   • Заявки — pendingUsers.length из UsersProvider
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

    // =====================================================
    // 📑 СПИСОК ВКЛАДОК
    // =====================================================
    // Заявки добавляются только если пользователь — админ/командир.
    // Список строится в build(), чтобы реагировать на изменение роли.

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
            const BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
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

        // 🎯 Страницы — синхронно с items
        final pages = <Widget>[
            ..._pages,
            if (canSeePending) const PendingUsersScreen(),
        ];

        // 🎯 Защита: если _currentIndex выходит за пределы (например,
        // админ вышел, и вкладка «Заявки» исчезла) — сбрасываем на 0.
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
    // 🔴 БЕЙДЖ НА ИКОНКЕ
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
}