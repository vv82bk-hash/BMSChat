// =====================================================
// 👤 BMSChat — ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ
// =====================================================
// Показывает данные пользователя + кнопки действий
// (зависят от прав текущего пользователя).
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/users_provider.dart';
import '../services/api_service.dart';
import '../themes/rasta_theme.dart';
import '../utils/app_logger.dart';
import '../widgets/permission_chip.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
    final int userId;

    const UserProfileScreen({
        super.key,
        required this.userId,
    });

    @override
    State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
    User? _user;
    bool _isLoading = true;
    String? _error;
    bool _actionInProgress = false;

    @override
    void initState() {
        super.initState();
        _loadUser();
    }

    Future<void> _loadUser() async {
        setState(() {
            _isLoading = true;
            _error = null;
        });

        // Сначала пробуем из провайдера (быстро)
        final usersProvider = Provider.of<UsersProvider>(context, listen: false);
        final cached = usersProvider.getUserById(widget.userId);

        if (cached != null) {
            setState(() {
                _user = cached;
                _isLoading = false;
            });
        }

        // Затем обновляем с сервера
        final response = await ApiService.getUser(widget.userId);

        if (!mounted) return;

        if (response.isSuccess) {
            setState(() {
                _user = response.data;
                _isLoading = false;
                _error = null;
            });
        } else {
            setState(() {
                _error = response.error ?? 'Ошибка загрузки';
                _isLoading = false;
            });
        }
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('Профиль'),
                actions: [
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadUser,
                        tooltip: 'Обновить',
                    ),
                ],
            ),
            body: _buildBody(),
        );
    }

    Widget _buildBody() {
        if (_isLoading && _user == null) {
            return const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        RastaTheme.rastaYellow,
                    ),
                ),
            );
        }

        if (_error != null && _user == null) {
            return _buildError(_error!);
        }

        if (_user == null) {
            return const Center(
                child: Text(
                    'Пользователь не найден',
                    style: TextStyle(color: RastaTheme.textMuted),
                ),
            );
        }

        return RefreshIndicator(
            onRefresh: _loadUser,
            color: RastaTheme.rastaYellow,
            backgroundColor: RastaTheme.surface,
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                    children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildInfoCard(),
                        const SizedBox(height: 12),
                        if (_user!.roles.isNotEmpty) _buildRolesCard(),
                        const SizedBox(height: 12),
                        _buildPermissionsCard(),
                        const SizedBox(height: 16),
                        _buildActionsCard(),
                        const SizedBox(height: 32),
                    ],
                ),
            ),
        );
    }

    // =====================================================
    // 👤 ШАПКА (аватар, имя, username, статус)
    // =====================================================
    Widget _buildHeader() {
        final user = _user!;
        final isMe = user.id ==
            Provider.of<AuthProvider>(context, listen: false).user?.id;

        return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            color: RastaTheme.surface,
            child: Column(
                children: [
                    Stack(
                        children: [
                            CircleAvatar(
                                radius: 48,
                                backgroundColor: RastaTheme.surfaceSecondary,
                                backgroundImage: user.avatar != null
                                    ? NetworkImage(user.avatar!)
                                    : null,
                                child: user.avatar == null
                                    ? Text(
                                        user.initials,
                                        style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: RastaTheme.rastaYellow,
                                        ),
                                    )
                                    : null,
                            ),
                            Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                        color: user.isOnline
                                            ? RastaTheme.success
                                            : RastaTheme.textMuted,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: RastaTheme.surface,
                                            width: 3,
                                        ),
                                    ),
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Flexible(
                                child: Text(
                                    user.displayName,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: RastaTheme.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                ),
                            ),
                            if (isMe)
                                const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Text(
                                        '(вы)',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontStyle: FontStyle.italic,
                                            color: RastaTheme.rastaYellow,
                                        ),
                                    ),
                                ),
                        ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '@${user.username}',
                        style: const TextStyle(
                            fontSize: 14,
                            color: RastaTheme.textMuted,
                        ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        user.isOnline ? 'онлайн' : user.lastSeenText,
                        style: TextStyle(
                            fontSize: 13,
                            color: user.isOnline
                                ? RastaTheme.success
                                : RastaTheme.textMuted,
                        ),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 📋 ИНФОРМАЦИЯ
    // =====================================================
    Widget _buildInfoCard() {
        final user = _user!;

        return _card(
            title: 'Информация',
            child: Column(
                children: [
                    _row('ID', '#${user.id}'),
                    _row('Username', user.username),
                    if (user.createdAt != null)
                        _row('Дата регистрации', _formatDate(user.createdAt!)),
                    if (!user.isApproved)
                        const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                                '⏳ Ожидает подтверждения',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: RastaTheme.warning,
                                    fontWeight: FontWeight.w600,
                                ),
                            ),
                        ),
                ],
            ),
        );
    }

    // =====================================================
    // 🎭 РОЛИ
    // =====================================================
    Widget _buildRolesCard() {
        final user = _user!;

        return _card(
            title: 'Роли',
            child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.roles.map((role) {
                    final color = Color(role.colorValue);
                    return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                        ),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Text(role.icon,
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                    role.name,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                    ),
                                ),
                            ],
                        ),
                    );
                }).toList(),
            ),
        );
    }

    // =====================================================
    // ✅ ПРАВА
    // =====================================================
    Widget _buildPermissionsCard() {
        final user = _user!;

        return _card(
            title: 'Права',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    PermissionChip(
                        label: 'Писать в общий чат',
                        enabled: user.canWriteGeneral,
                    ),
                    PermissionChip(
                        label: 'Писать в личные чаты',
                        enabled: user.canWritePrivate,
                    ),
                    PermissionChip(
                        label: 'Писать командиру',
                        enabled: user.canWriteToCommander,
                    ),
                    PermissionChip(
                        label: 'Создавать события в ленте',
                        enabled: user.canCreateFeed,
                    ),
                    PermissionChip(
                        label: 'Подтверждать новобранцев',
                        enabled: user.canApproveUsers,
                    ),
                    PermissionChip(
                        label: 'Управлять ролями',
                        enabled: user.canManageRoles,
                    ),
                    PermissionChip(
                        label: 'Управлять пользователями',
                        enabled: user.canManageUsers,
                    ),
                    PermissionChip(
                        label: 'Назначать командиров',
                        enabled: user.canAssignCommanders,
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 🎯 ДЕЙСТВИЯ
    // =====================================================
    Widget _buildActionsCard() {
        final user = _user!;
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final me = auth.user;
        final isMe = me?.id == user.id;

        final canApprove = me?.canApproveUsers ?? false;
        final canAssign = me?.canAssignCommanders ?? false;

        // 🔒 ЗАЩИТА: target — админ, а я — не сам админ
        // (id 1 — оригинальный admin, его нельзя трогать)
        final targetIsAdmin = user.isAdmin;
        final iAmOriginalAdmin = me?.id == 1;

        if (targetIsAdmin && !iAmOriginalAdmin && !isMe) {
            return _card(
                title: 'Действия',
                child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                        children: [
                            Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: RastaTheme.warning,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    'Нельзя управлять учётной записью администратора',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: RastaTheme.warning,
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            );
        }

        final buttons = <Widget>[];

        // Написать сообщение (всем, кроме себя)
        if (!isMe) {
            buttons.add(_actionButton(
                icon: Icons.chat_bubble_outline,
                label: 'Написать сообщение',
                color: RastaTheme.rastaYellow,
                onPressed:
                    _actionInProgress ? null : () => _openPrivateChat(user),
            ));
        }

        // Подтвердить (если есть право и пользователь не подтверждён)
        if (!user.isApproved && canApprove) {
            buttons.add(_actionButton(
                icon: Icons.check_circle_outline,
                label: 'Подтвердить',
                color: RastaTheme.success,
                onPressed: _actionInProgress ? null : () => _approve(user),
            ));
        }

        // Назначить командиром (только админ, если ещё не командир)
        if (canAssign && !user.isCommander && user.isApproved && !isMe) {
            buttons.add(_actionButton(
                icon: Icons.military_tech,
                label: 'Назначить командиром',
                color: RastaTheme.rastaRed,
                onPressed:
                    _actionInProgress ? null : () => _assignCommander(user),
            ));
        }

        // Снять командира (только админ, если командир)
        if (canAssign && user.isCommander && !isMe) {
            buttons.add(_actionButton(
                icon: Icons.remove_circle_outline,
                label: 'Снять командира',
                color: RastaTheme.warning,
                onPressed:
                    _actionInProgress ? null : () => _removeCommander(user),
            ));
        }

        // Понизить до новобранца (админ или командир, не себя, не админа)
        if (canApprove && !isMe && !user.isAdmin) {
            buttons.add(_actionButton(
                icon: Icons.arrow_downward,
                label: 'Понизить до новобранца',
                color: RastaTheme.error,
                onPressed: _actionInProgress ? null : () => _makeRecruit(user),
            ));
        }

        if (buttons.isEmpty) {
            return _card(
                title: 'Действия',
                child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        'Нет доступных действий',
                        style: TextStyle(
                            fontSize: 13,
                            color: RastaTheme.textMuted,
                        ),
                    ),
                ),
            );
        }

        return _card(
            title: 'Действия',
            child: Column(
                children: buttons
                    .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: b,
                    ))
                    .toList(),
            ),
        );
    }

    Widget _actionButton({
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback? onPressed,
    }) {
        return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 🎯 ОБРАБОТЧИКИ ДЕЙСТВИЙ
    // =====================================================

    Future<void> _openPrivateChat(User user) async {
        setState(() => _actionInProgress = true);

        // Берём провайдеры ДО await — чтобы не использовать context после
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);

        try {
            final response = await ApiService.createPrivateChat(user.id);

            if (!mounted) return;

            if (!response.isSuccess) {
                _showSnack('Не удалось открыть чат: ${response.error}',
                    isError: true);
                return;
            }

            final chatData = response.data!;
            // Сервер возвращает { chat_id: ..., existed: ... }
            final chatId = chatData['chat_id'] ??
                chatData['chat']?['id'] ??
                chatData['id'];

            if (chatId == null) {
                _showSnack('Ошибка: нет ID чата', isError: true);
                return;
            }

            await chatProvider.loadChats();
            await chatProvider.openChat(chatId);

            if (!mounted) return;

            // 📱 Переходим в чат (профиль остаётся в стеке — как в Telegram)
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(chatId: chatId),
                ),
            );
        } catch (e) {
            AppLogger.error('Ошибка открытия личного чата', e);
            if (mounted) _showSnack('Ошибка сети', isError: true);
        } finally {
            if (mounted) setState(() => _actionInProgress = false);
        }
    }

    Future<void> _approve(User user) async {
        final confirmed = await _confirm(
            'Подтвердить пользователя?',
            '${user.displayName} станет бойцом команды.',
        );
        if (confirmed != true) return;
        if (!mounted) return;

        setState(() => _actionInProgress = true);

        final usersProvider = Provider.of<UsersProvider>(context, listen: false);
        final success = await usersProvider.approveUser(user.id);

        if (!mounted) return;
        setState(() => _actionInProgress = false);

        if (success) {
            _showSnack('Пользователь подтверждён');
            await _loadUser();
        } else {
            _showSnack('Ошибка подтверждения', isError: true);
        }
    }

    Future<void> _assignCommander(User user) async {
        final confirmed = await _confirm(
            'Назначить командиром?',
            '${user.displayName} получит права командира.',
        );
        if (confirmed != true) return;
        if (!mounted) return;

        setState(() => _actionInProgress = true);

        final usersProvider = Provider.of<UsersProvider>(context, listen: false);
        final success = await usersProvider.assignCommander(user.id);

        if (!mounted) return;
        setState(() => _actionInProgress = false);

        if (success) {
            _showSnack('${user.displayName} назначен командиром');
            await _loadUser();
        } else {
            _showSnack('Ошибка назначения', isError: true);
        }
    }

    Future<void> _removeCommander(User user) async {
        final confirmed = await _confirm(
            'Снять командира?',
            '${user.displayName} потеряет права командира.',
        );
        if (confirmed != true) return;
        if (!mounted) return;

        setState(() => _actionInProgress = true);

        final usersProvider = Provider.of<UsersProvider>(context, listen: false);
        final success = await usersProvider.removeCommander(user.id);

        if (!mounted) return;
        setState(() => _actionInProgress = false);

        if (success) {
            _showSnack('${user.displayName} больше не командир');
            await _loadUser();
        } else {
            _showSnack('Ошибка снятия', isError: true);
        }
    }

    Future<void> _makeRecruit(User user) async {
        final confirmed = await _confirm(
            'Понизить до новобранца?',
            '${user.displayName} потеряет все роли и станет новобранцем.',
        );
        if (confirmed != true) return;
        if (!mounted) return;

        setState(() => _actionInProgress = true);

        final usersProvider = Provider.of<UsersProvider>(context, listen: false);
        final success = await usersProvider.makeRecruit(user.id);

        if (!mounted) return;
        setState(() => _actionInProgress = false);

        if (success) {
            _showSnack('${user.displayName} стал новобранцем');
            await _loadUser();
        } else {
            _showSnack('Ошибка понижения', isError: true);
        }
    }

    // =====================================================
    // 🛠️ ВСПОМОГАТЕЛЬНЫЕ
    // =====================================================

    Widget _card({required String title, required Widget child}) {
        return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                        title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: RastaTheme.rastaYellow,
                        ),
                    ),
                    const SizedBox(height: 12),
                    child,
                ],
            ),
        );
    }

    Widget _row(String label, String value) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(
                        label,
                        style: const TextStyle(
                            fontSize: 14,
                            color: RastaTheme.textMuted,
                        ),
                    ),
                    Flexible(
                        child: Text(
                            value,
                            style: const TextStyle(
                                fontSize: 14,
                                color: RastaTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                        ),
                    ),
                ],
            ),
        );
    }

    String _formatDate(DateTime date) {
        return '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.'
            '${date.year}';
    }

    Widget _buildError(String error) {
        return Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
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
                            onPressed: _loadUser,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: RastaTheme.rastaYellow,
                                foregroundColor: Colors.black,
                            ),
                            child: const Text('Повторить'),
                        ),
                    ],
                ),
            ),
        );
    }

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