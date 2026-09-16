import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../themes/rasta_theme.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
    const ProfileScreen({super.key});

    @override
    Widget build(BuildContext context) {
        final auth = Provider.of<AuthProvider>(context);
        final user = auth.user;

        if (user == null) {
            return const Scaffold(
                backgroundColor: RastaTheme.background,
                body: Center(
                    child: Text(
                        'Не авторизован',
                        style: TextStyle(color: RastaTheme.textMuted),
                    ),
                ),
            );
        }

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('👤 Профиль'),
                actions: [
                    IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                ),
                            );
                        },
                        tooltip: 'Настройки',
                    ),
                ],
            ),
            body: SingleChildScrollView(
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
                        const SizedBox(height: 16),
                        _buildPermissionsSection(user),
                        const SizedBox(height: 24),
                        _buildLogoutButton(context),
                    ],
                ),
            ),
        );
    }

    // ============================================
    // 👤 АВАТАР
    // ============================================
    Widget _buildAvatar(dynamic user) {
        return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
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
    // 📝 ИМЯ
    // ============================================
    Widget _buildNameSection(dynamic user) {
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
            ],
        );
    }

    // ============================================
    // 🎭 РОЛИ
    // ============================================
    Widget _buildRolesSection(dynamic user) {
        if (user.roles.isEmpty) {
            return const SizedBox.shrink();
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
                            color: Color(role.colorValue).withValues(alpha: 0.3),
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
    Widget _buildStatsSection(dynamic user) {
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
                        Icons.circle,
                        'Статус',
                        user.isOnline ? 'Онлайн' : 'Офлайн',
                        color: user.isOnline
                            ? RastaTheme.online
                            : RastaTheme.textMuted,
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
    Widget _buildPermissionsSection(dynamic user) {
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
    // 🚪 ВЫХОД
    // ============================================
    Widget _buildLogoutButton(BuildContext context) {
        return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, color: RastaTheme.error),
                label: const Text(
                    'Выйти из аккаунта',
                    style: TextStyle(color: RastaTheme.error, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: RastaTheme.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                    ),
                ),
            ),
        );
    }

    Future<void> _confirmLogout(BuildContext context) async {
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

        if (confirmed == true && context.mounted) {
            await Provider.of<AuthProvider>(context, listen: false).logout();
        }
    }
}

class _Permission {
    final String label;
    final bool allowed;

    const _Permission(this.label, this.allowed);
}