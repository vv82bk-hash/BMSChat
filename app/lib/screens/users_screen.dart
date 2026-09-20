// =====================================================
// 👥 BMSChat — ЭКРАН КОМАНДЫ
// =====================================================
// Показывает список всех пользователей команды.
// 🎯 ЭТАП A: экран стал вкладкой в MainScreen
//   • Убрана кнопка «Назад» (automaticallyImplyLeading: false)
//   • Заголовок «Участники» → «Команда»
//   • Убрана кнопка «Заявки» — теперь это отдельная вкладка
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/users_provider.dart';
import '../themes/rasta_theme.dart';
import '../widgets/user_list_tile.dart';
import 'user_profile_screen.dart';

class UsersScreen extends StatefulWidget {
    const UsersScreen({super.key});

    @override
    State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
    final _searchController = TextEditingController();
    String _searchQuery = '';

    @override
    void initState() {
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
            final users = Provider.of<UsersProvider>(context, listen: false);
            // Инициализируем Socket-слушатели
            users.initSocketListeners();
            // Загружаем пользователей
            users.loadUsers();
            // Загружаем заявки (для бейджа в MainScreen — счётчик)
            final auth = Provider.of<AuthProvider>(context, listen: false);
            if (auth.canApproveUsers) {
                users.loadPendingUsers();
            }
        });
    }

    @override
    void dispose() {
        _searchController.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final users = Provider.of<UsersProvider>(context);
        final auth = Provider.of<AuthProvider>(context);

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                // 🎯 ЭТАП A: скрываем кнопку «Назад» — экран теперь вкладка
                automaticallyImplyLeading: false,
                title: const Text('Команда'),
                actions: [
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                            users.loadUsers();
                            if (auth.canApproveUsers) {
                                users.loadPendingUsers();
                            }
                        },
                        tooltip: 'Обновить',
                    ),
                ],
            ),
            body: Column(
                children: [
                    _buildSearchField(),
                    Expanded(
                        child: users.isLoading && users.count == 0
                            ? _buildLoading()
                            : users.hasError
                                ? _buildError(users.error!)
                                : _buildList(users),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 🔍 ПОИСК
    // =====================================================
    Widget _buildSearchField() {
        return Container(
            padding: const EdgeInsets.all(12),
            color: RastaTheme.surface,
            child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: RastaTheme.textPrimary),
                decoration: InputDecoration(
                    hintText: 'Поиск по имени...',
                    hintStyle: const TextStyle(color: RastaTheme.textMuted),
                    prefixIcon: const Icon(Icons.search,
                        color: RastaTheme.rastaYellow),
                    filled: true,
                    fillColor: RastaTheme.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 📋 СПИСОК
    // =====================================================
    Widget _buildList(UsersProvider users) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = auth.user?.id ?? 0;

        final filtered = _searchQuery.isEmpty
            ? users.allUsers
            : users.search(_searchQuery);

        final sorted = List.of(filtered)
            ..sort((a, b) {
                if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
                final aPriority = a.primaryRole?.priority ?? 0;
                final bPriority = b.primaryRole?.priority ?? 0;
                if (aPriority != bPriority) return bPriority.compareTo(aPriority);
                return a.displayName.compareTo(b.displayName);
            });

        if (sorted.isEmpty) {
            return _buildEmpty();
        }

        return RefreshIndicator(
            onRefresh: () async {
                await users.loadUsers();
                if (auth.canApproveUsers) {
                    await users.loadPendingUsers();
                }
            },
            color: RastaTheme.rastaYellow,
            backgroundColor: RastaTheme.surface,
            child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                    final user = sorted[index];
                    final isMe = user.id == currentUserId;

                    return UserListTile(
                        user: user,
                        isMe: isMe,
                        onTap: () => _openUserProfile(user.id),
                    );
                },
            ),
        );
    }

    Widget _buildEmpty() {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Text('👥', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                        _searchQuery.isEmpty
                            ? 'Нет пользователей'
                            : 'Никого не найдено',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildLoading() {
        return const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    RastaTheme.rastaYellow,
                ),
            ),
        );
    }

    Widget _buildError(String error) {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: RastaTheme.error),
                    const SizedBox(height: 16),
                    Text(
                        error,
                        style: const TextStyle(
                            color: RastaTheme.textMuted,
                            fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: () =>
                            Provider.of<UsersProvider>(context, listen: false)
                                .loadUsers(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: RastaTheme.rastaYellow,
                            foregroundColor: Colors.black,
                        ),
                        child: const Text('Повторить'),
                    ),
                ],
            ),
        );
    }

    void _openUserProfile(int userId) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: userId),
            ),
        ).then((_) {
            if (!mounted) return;
            Provider.of<UsersProvider>(context, listen: false).loadUsers();
        });
    }
}