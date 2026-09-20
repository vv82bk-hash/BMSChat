// =====================================================
// ⏳ BMSChat — ЭКРАН ЗАЯВОК
// =====================================================
// Показывает неподтверждённых пользователей.
// Командир/админ может подтвердить или отклонить.
// 🎯 ЭТАП A: экран стал вкладкой в MainScreen
//   • Убрана кнопка «Назад» (automaticallyImplyLeading: false)
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/users_provider.dart';
import '../themes/rasta_theme.dart';

class PendingUsersScreen extends StatefulWidget {
    const PendingUsersScreen({super.key});

    @override
    State<PendingUsersScreen> createState() => _PendingUsersScreenState();
}

class _PendingUsersScreenState extends State<PendingUsersScreen> {
    bool _actionInProgress = false;

    @override
    void initState() {
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UsersProvider>(context, listen: false)
                .loadPendingUsers();
        });
    }

    @override
    Widget build(BuildContext context) {
        final users = Provider.of<UsersProvider>(context);

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                // 🎯 ЭТАП A: скрываем кнопку «Назад» — экран теперь вкладка
                automaticallyImplyLeading: false,
                title: const Text('Заявки'),
                actions: [
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => users.loadPendingUsers(),
                        tooltip: 'Обновить',
                    ),
                ],
            ),
            body: _buildBody(users),
        );
    }

    Widget _buildBody(UsersProvider users) {
        if (users.isLoadingPending && users.pendingUsers.isEmpty) {
            return const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        RastaTheme.rastaYellow,
                    ),
                ),
            );
        }

        if (users.pendingUsers.isEmpty) {
            return _buildEmpty();
        }

        return RefreshIndicator(
            onRefresh: () => users.loadPendingUsers(),
            color: RastaTheme.rastaYellow,
            backgroundColor: RastaTheme.surface,
            child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: users.pendingUsers.length,
                itemBuilder: (context, index) {
                    final user = users.pendingUsers[index];
                    return _buildPendingTile(user);
                },
            ),
        );
    }

    Widget _buildEmpty() {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Text('✅', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                        'Нет новых заявок',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Все пользователи подтверждены',
                        style: TextStyle(
                            fontSize: 14,
                            color: RastaTheme.textMuted.withValues(alpha: 0.8),
                        ),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 👤 КАРТОЧКА ЗАЯВКИ
    // =====================================================
    Widget _buildPendingTile(User user) {
        return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
                children: [
                    // Аватар
                    CircleAvatar(
                        radius: 26,
                        backgroundColor: RastaTheme.surfaceSecondary,
                        child: Text(
                            user.initials,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: RastaTheme.rastaYellow,
                            ),
                        ),
                    ),
                    const SizedBox(width: 12),

                    // Имя + username
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                    user.displayName,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: RastaTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    '@${user.username}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: RastaTheme.textMuted,
                                    ),
                                ),
                            ],
                        ),
                    ),

                    // Кнопки
                    IconButton(
                        icon: const Icon(Icons.check_circle,
                            color: RastaTheme.success),
                        tooltip: 'Подтвердить',
                        onPressed: _actionInProgress
                            ? null
                            : () => _approve(user),
                    ),
                    IconButton(
                        icon: const Icon(Icons.cancel_outlined,
                            color: RastaTheme.error),
                        tooltip: 'Отклонить',
                        onPressed: _actionInProgress
                            ? null
                            : () => _reject(user),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // ✅ ПОДТВЕРДИТЬ
    // =====================================================
    Future<void> _approve(User user) async {
        final confirmed = await _confirm(
            'Подтвердить?',
            '${user.displayName} станет бойцом команды.',
        );
        if (confirmed != true || !mounted) return;

        setState(() => _actionInProgress = true);

        final users = Provider.of<UsersProvider>(context, listen: false);
        final success = await users.approveUser(user.id);

        if (!mounted) return;
        setState(() => _actionInProgress = false);

        _showSnack(
            success
                ? '${user.displayName} подтверждён'
                : 'Ошибка подтверждения',
            isError: !success,
        );
    }

    // =====================================================
    // ❌ ОТКЛОНИТЬ
    // =====================================================
    Future<void> _reject(User user) async {
        final confirmed = await _confirm(
            'Отклонить заявку?',
            'Аккаунт ${user.displayName} будет удалён.',
        );
        if (confirmed != true || !mounted) return;

        setState(() => _actionInProgress = true);

        final users = Provider.of<UsersProvider>(context, listen: false);
        final success = await users.rejectUser(user.id);

        if (!mounted) return;
        setState(() => _actionInProgress = false);

        _showSnack(
            success ? 'Заявка отклонена' : 'Ошибка отклонения',
            isError: !success,
        );
    }

    // =====================================================
    // 🛠️ ВСПОМОГАТЕЛЬНЫЕ
    // =====================================================

    Future<bool?> _confirm(String title, String message) {
        return showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: Text(
                    title,
                    style: const TextStyle(color: RastaTheme.textPrimary),
                ),
                content: Text(
                    message,
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
                            'Да',
                            style: TextStyle(color: RastaTheme.rastaYellow),
                        ),
                    ),
                ],
            ),
        );
    }

    void _showSnack(String message, {bool isError = false}) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor:
                    isError ? RastaTheme.error : RastaTheme.success,
                behavior: SnackBarBehavior.floating,
            ),
        );
    }
}