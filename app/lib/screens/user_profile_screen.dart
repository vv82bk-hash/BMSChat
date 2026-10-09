// =====================================================
// 👤 BMSChat — ЭКРАН ЧУЖОГО ПРОФИЛЯ
// =====================================================
// 🎯 Открывается из:
//   • Списка команды (UsersScreen)
//   • Тапа по имени отправителя в чате
// 🎯 Показывает: аватар, имя, роли, статус, права
// 🎯 Действия:
//   • Написать сообщение (личный чат)
//   • Назначить командиром / Сделать новобранцем (для админа)
// =====================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../themes/rasta_theme.dart';
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

        final response = await ApiService.getUser(widget.userId);

        if (!mounted) return;

        if (response.isSuccess && response.data != null) {
            setState(() {
                _user = response.data;
                _isLoading = false;
            });
        } else {
            setState(() {
                _error = response.error ?? 'Не удалось загрузить профиль';
                _isLoading = false;
            });
        }
    }

    // ============================================
    // 🎨 BUILD
    // ============================================
    @override
    Widget build(BuildContext context) {
        final auth = Provider.of<AuthProvider>(context);
        final currentUser = auth.user;
        final isMe = currentUser?.id == widget.userId;

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: Text(isMe ? '👤 Мой профиль' : '👤 Профиль'),
            ),
            body: _isLoading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildContent(auth),
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

    Widget _buildError() {
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: RastaTheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                        _error ?? 'Ошибка',
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
        );
    }

    Widget _buildContent(AuthProvider auth) {
        final user = _user!;
        final isMe = auth.user?.id == user.id;

        return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                children: [
                    _buildAvatar(user),
                    const SizedBox(height: 16),
                    _buildNameSection(user),
                    const SizedBox(height: 24),
                    _buildRolesSection(user),
                    const SizedBox(height: 16),
                    _buildStatsSection(user),

                    if (user.canManageUsers ||
                        user.canApproveUsers ||
                        user.isCommander) ...[
                        const SizedBox(height: 16),
                        _buildPermissionsSection(user),
                    ],

                    if (!isMe) ...[
                        const SizedBox(height: 24),
                        _buildActionButtons(auth, user),
                    ],

                    const SizedBox(height: 24),
                ],
            ),
        );
    }

    // ============================================
    // 👤 АВАТАР
    // ============================================
    Widget _buildAvatar(User user) {
        final hasAvatar = user.avatar != null && user.avatar!.isNotEmpty;
        final avatarUrl = hasAvatar
            ? Constants.getFullFileUrl(user.avatar)
            : null;

        return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasAvatar
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                            RastaTheme.rastaRed,
                            RastaTheme.rastaYellow,
                            RastaTheme.rastaGreen,
                        ],
                    ),
                boxShadow: [
                    BoxShadow(
                        color: RastaTheme.rastaYellow.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                    ),
                ],
            ),
            child: ClipOval(
                child: hasAvatar
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildInitials(user),
                        errorWidget: (context, url, error) =>
                            _buildInitials(user),
                    )
                    : _buildInitials(user),
            ),
        );
    }

    Widget _buildInitials(User user) {
        return Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                        RastaTheme.rastaRed,
                        RastaTheme.rastaYellow,
                        RastaTheme.rastaGreen,
                    ],
                ),
            ),
            child: Center(
                child: Text(
                    user.initials,
                    style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                    ),
                ),
            ),
        );
    }

    // ============================================
    // 📝 ИМЯ + СТАТУС
    // ============================================
    Widget _buildNameSection(User user) {
        return Column(
            children: [
                Text(
                    user.displayName,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: RastaTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
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
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: user.isOnline
                                    ? RastaTheme.online
                                    : RastaTheme.textMuted,
                            ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                            user.isOnline ? 'онлайн' : user.lastSeenText,
                            style: TextStyle(
                                fontSize: 13,
                                color: user.isOnline
                                    ? RastaTheme.online
                                    : RastaTheme.textMuted,
                            ),
                        ),
                    ],
                ),
            ],
        );
    }

    // ============================================
    // 🎭 РОЛИ
    // ============================================
    Widget _buildRolesSection(User user) {
        if (user.roles.isEmpty) {
            return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: RastaTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                    children: [
                        Icon(
                            Icons.info_outline,
                            color: RastaTheme.textMuted,
                            size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                            'Роли не назначены',
                            style: TextStyle(
                                color: RastaTheme.textMuted,
                                fontSize: 14,
                            ),
                        ),
                    ],
                ),
            );
        }

        return Column(
            children: user.roles.map<Widget>((role) {
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                    ),
                    decoration: BoxDecoration(
                        color: RastaTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Color(role.colorValue)
                                .withValues(alpha: 0.3),
                        ),
                    ),
                    child: Row(
                        children: [
                            Text(
                                role.icon,
                                style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    role.name,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(role.colorValue),
                                    ),
                                ),
                            ),
                            if (role.priority > 0)
                                Text(
                                    'приоритет ${role.priority}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: RastaTheme.textMuted,
                                    ),
                                ),
                        ],
                    ),
                );
            }).toList(),
        );
    }

    // ============================================
    // 📊 СТАТИСТИКА
    // ============================================
    Widget _buildStatsSection(User user) {
        final created = user.createdAt != null
            ? DateFormat('dd.MM.yyyy').format(user.createdAt!)
            : '—';

        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                        '📊 Информация',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                        Icons.access_time,
                        'Последний визит',
                        user.lastSeenText,
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                        Icons.calendar_today,
                        'Дата регистрации',
                        created,
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                        Icons.verified_user,
                        'Подтверждён',
                        user.isApproved ? 'Да' : 'Нет',
                        color: user.isApproved
                            ? RastaTheme.success
                            : RastaTheme.error,
                    ),
                ],
            ),
        );
    }

    Widget _buildStatRow(IconData icon, String label, String value,
        {Color? color}) {
        return Row(
            children: [
                Icon(icon, size: 16, color: color ?? RastaTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 14,
                            color: RastaTheme.textSecondary,
                        ),
                    ),
                ),
                Text(
                    value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color ?? RastaTheme.textPrimary,
                    ),
                ),
            ],
        );
    }

    // ============================================
    // 🔐 ПРАВА
    // ============================================
    Widget _buildPermissionsSection(User user) {
        final permissions = [
            _Permission('Писать в общий чат', user.canWriteGeneral),
            _Permission('Писать в личные чаты', user.canWritePrivate),
            _Permission('Писать командиру', user.canWriteToCommander),
            _Permission('Создавать события', user.canCreateFeed),
            _Permission('Подтверждать новичков', user.canApproveUsers),
            _Permission('Управлять ролями', user.canManageRoles),
            _Permission('Управлять пользователями', user.canManageUsers),
            _Permission('Назначать командиров', user.canAssignCommanders),
        ];

        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                        '🔐 Права доступа',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 12),
                    ...permissions.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                            children: [
                                Icon(
                                    p.allowed
                                        ? Icons.check_circle
                                        : Icons.cancel_outlined,
                                    size: 18,
                                    color: p.allowed
                                        ? RastaTheme.success
                                        : RastaTheme.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        p.label,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: p.allowed
                                                ? RastaTheme.textSecondary
                                                : RastaTheme.textMuted,
                                        ),
                                    ),
                                ),
                            ],
                        ),
                    )),
                ],
            ),
        );
    }

    // ============================================
    // 🎯 КНОПКИ ДЕЙСТВИЙ
    // ============================================
    Widget _buildActionButtons(AuthProvider auth, User user) {
        return Column(
            children: [
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                        onPressed: () => _openPrivateChat(user),
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        label: const Text(
                            'Написать сообщение',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                            ),
                        ),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: RastaTheme.rastaYellow,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                            ),
                        ),
                    ),
                ),

                if (auth.canAssignCommanders) ...[
                    const SizedBox(height: 12),
                    if (!user.isCommander && user.isApproved)
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                                onPressed: () => _confirmAction(
                                    action: 'assign_commander',
                                    user: user,
                                ),
                                icon: const Icon(
                                    Icons.military_tech,
                                    size: 20,
                                    color: RastaTheme.rastaYellow,
                                ),
                                label: const Text(
                                    'Назначить командиром',
                                    style: TextStyle(
                                        color: RastaTheme.rastaYellow,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                    ),
                                ),
                                style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: RastaTheme.rastaYellow,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                    ),
                                ),
                            ),
                        ),
                    if (user.isCommander)
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                                onPressed: () => _confirmAction(
                                    action: 'remove_commander',
                                    user: user,
                                ),
                                icon: const Icon(
                                    Icons.military_tech,
                                    size: 20,
                                    color: RastaTheme.textMuted,
                                ),
                                label: const Text(
                                    'Снять командира',
                                    style: TextStyle(
                                        color: RastaTheme.textMuted,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                    ),
                                ),
                                style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: RastaTheme.textMuted,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                    ),
                                ),
                            ),
                        ),
                ],

                if (auth.canApproveUsers && user.isApproved) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                            onPressed: () => _confirmAction(
                                action: 'make_recruit',
                                user: user,
                            ),
                            icon: const Icon(
                                Icons.arrow_downward,
                                size: 20,
                                color: RastaTheme.error,
                            ),
                            label: const Text(
                                'Понизить до новобранца',
                                style: TextStyle(
                                    color: RastaTheme.error,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                ),
                            ),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: RastaTheme.error,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                ),
                            ),
                        ),
                    ),
                ],
            ],
        );
    }

    // ============================================
    // ✉️ ОТКРЫТЬ ЛИЧНЫЙ ЧАТ
    // ============================================
    Future<void> _openPrivateChat(User user) async {
        final chat = Provider.of<ChatProvider>(context, listen: false);

        try {
            final response = await ApiService.createPrivateChat(user.id);

            if (!mounted) return;

            if (!response.isSuccess || response.data == null) {
                _showError(response.error ?? 'Не удалось открыть чат');
                return;
            }

            final chatJson = response.data!['chat'] as Map<String, dynamic>?;
            if (chatJson == null) {
                _showError('Некорректный ответ сервера');
                return;
            }

            final chatId = chatJson['id'] as int?;
            if (chatId == null) {
                _showError('Сервер не вернул ID чата');
                return;
            }

            await chat.loadChats();
            if (!mounted) return;

            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(chatId: chatId),
                ),
            );
        } catch (e) {
            if (!mounted) return;
            _showError('Ошибка: $e');
        }
    }

    // ============================================
    // 👑 ДЕЙСТВИЯ С РОЛЯМИ
    // ============================================
    Future<void> _confirmAction({
        required String action,
        required User user,
    }) async {
        final (title, message, confirmLabel) = switch (action) {
            'assign_commander' => (
                'Назначить командиром?',
                '${user.displayName} получит роль «Командир» '
                    'и все её права.',
                'Назначить',
            ),
            'remove_commander' => (
                'Снять командира?',
                '${user.displayName} потеряет роль «Командир» '
                    'и станет бойцом.',
                'Снять',
            ),
            'make_recruit' => (
                'Понизить до новобранца?',
                '${user.displayName} станет новобранцем и потребует '
                    'повторного подтверждения.',
                'Понизить',
            ),
            _ => ('Подтвердить?', 'Продолжить?', 'OK'),
        };

        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: Text(
                    title,
                    style: const TextStyle(
                        color: RastaTheme.textPrimary,
                        fontSize: 20,
                    ),
                ),
                content: Text(
                    message,
                    style: const TextStyle(
                        color: RastaTheme.textSecondary,
                        fontSize: 15,
                    ),
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
                        child: Text(
                            confirmLabel,
                            style: const TextStyle(
                                color: RastaTheme.rastaYellow,
                            ),
                        ),
                    ),
                ],
            ),
        );

        if (confirmed != true || !mounted) return;

        ApiResponse<void> response;

        switch (action) {
            case 'assign_commander':
                response = await ApiService.assignCommander(user.id);
                break;
            case 'remove_commander':
                response = await ApiService.removeCommander(user.id);
                break;
            case 'make_recruit':
                response = await ApiService.makeRecruit(user.id);
                break;
            default:
                return;
        }

        if (!mounted) return;

        if (response.isSuccess) {
            _showInfo('Готово');
            await _loadUser();
        } else {
            _showError(response.error ?? 'Не удалось выполнить действие');
        }
    }

    // ============================================
    // 🛠️ УТИЛИТЫ
    // ============================================
    void _showError(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.error,
                behavior: SnackBarBehavior.floating,
            ),
        );
    }

    void _showInfo(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
            ),
        );
    }
}

class _Permission {
    final String label;
    final bool allowed;

    const _Permission(this.label, this.allowed);
}