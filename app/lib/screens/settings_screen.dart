// =====================================================
// ⚙️ BMSChat — ЭКРАН НАСТРОЕК
// =====================================================
// 🎯 Базовые настройки приложения.
// 🎯 Заглушки для будущих фич (тема, уведомления, кэш).
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../themes/rasta_theme.dart';

class SettingsScreen extends StatefulWidget {
    const SettingsScreen({super.key});

    @override
    State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
    @override
    Widget build(BuildContext context) {
        final auth = Provider.of<AuthProvider>(context);
        final user = auth.user;

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('⚙️ Настройки'),
            ),
            body: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                    _buildSectionHeader('Аккаунт'),
                    _buildTile(
                        icon: Icons.person_outline,
                        title: 'Имя',
                        subtitle: user?.displayName ?? '—',
                    ),
                    _buildTile(
                        icon: Icons.alternate_email,
                        title: 'Логин',
                        subtitle: user != null ? '@${user.username}' : '—',
                    ),

                    const SizedBox(height: 8),

                    _buildSectionHeader('Уведомления'),
                    _buildTile(
                        icon: Icons.notifications_outlined,
                        title: 'Push-уведомления',
                        subtitle: 'Скоро',
                        onTap: () => _showSoon(context, 'Уведомления'),
                    ),
                    _buildTile(
                        icon: Icons.volume_up_outlined,
                        title: 'Звуки',
                        subtitle: 'Скоро',
                        onTap: () => _showSoon(context, 'Звуки'),
                    ),

                    const SizedBox(height: 8),

                    _buildSectionHeader('Внешний вид'),
                    _buildTile(
                        icon: Icons.palette_outlined,
                        title: 'Тема',
                        subtitle: 'Rasta (по умолчанию)',
                        onTap: () => _showSoon(context, 'Смена темы'),
                    ),
                    _buildTile(
                        icon: Icons.language_outlined,
                        title: 'Язык',
                        subtitle: 'Русский',
                        onTap: () => _showSoon(context, 'Смена языка'),
                    ),

                    const SizedBox(height: 8),

                    _buildSectionHeader('Данные и хранилище'),
                    _buildTile(
                        icon: Icons.cleaning_services_outlined,
                        title: 'Очистить кэш',
                        subtitle: 'Освободить место',
                        onTap: () => _clearCache(context),
                    ),

                    const SizedBox(height: 8),

                    _buildSectionHeader('О приложении'),
                    _buildTile(
                        icon: Icons.info_outline,
                        title: 'Версия',
                        subtitle: Constants.appVersion,
                    ),
                    _buildTile(
                        icon: Icons.groups_outlined,
                        title: Constants.teamName,
                        subtitle: Constants.teamMotto,
                    ),

                    const SizedBox(height: 24),
                ],
            ),
        );
    }

    Widget _buildSectionHeader(String title) {
        return Padding(
            padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 4,
            ),
            child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RastaTheme.textMuted,
                    letterSpacing: 1.0,
                ),
            ),
        );
    }

    Widget _buildTile({
        required IconData icon,
        required String title,
        String? subtitle,
        VoidCallback? onTap,
    }) {
        return ListTile(
            leading: Icon(
                icon,
                color: RastaTheme.rastaYellow,
                size: 26,
            ),
            title: Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    color: RastaTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                ),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 13,
                        color: RastaTheme.textMuted,
                    ),
                )
                : null,
            trailing: onTap != null
                ? const Icon(
                    Icons.chevron_right,
                    color: RastaTheme.textMuted,
                    size: 22,
                )
                : null,
            onTap: onTap,
        );
    }

    void _showSoon(BuildContext context, String feature) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('$feature — скоро'),
                backgroundColor: RastaTheme.rastaYellow,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
            ),
        );
    }

    Future<void> _clearCache(BuildContext context) async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Очистить кэш?',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: const Text(
                    'Кэшированные сообщения и картинки будут удалены. '
                    'При следующем открытии чата данные загрузятся заново.',
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
                            'Очистить',
                            style: TextStyle(color: RastaTheme.rastaYellow),
                        ),
                    ),
                ],
            ),
        );

        if (confirmed == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Кэш очищен (заглушка)'),
                    backgroundColor: RastaTheme.success,
                    behavior: SnackBarBehavior.floating,
                ),
            );
        }
    }
}