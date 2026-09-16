import 'package:flutter/material.dart';

import '../themes/rasta_theme.dart';

class SettingsScreen extends StatelessWidget {
    const SettingsScreen({super.key});

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('⚙️ Настройки'),
            ),
            body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                    _buildTile(
                        context,
                        icon: Icons.lock_outline,
                        title: 'Сменить пароль',
                        subtitle: 'Обновить пароль от аккаунта',
                        onTap: () => _showChangePasswordDialog(context),
                    ),
                    _buildTile(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        title: 'Политика обработки ПД',
                        subtitle: 'Как мы работаем с данными',
                        onTap: () => _showPrivacyPolicy(context),
                    ),
                    _buildTile(
                        context,
                        icon: Icons.info_outline,
                        title: 'О приложении',
                        subtitle: 'Версия 1.0.0',
                        onTap: () => _showAbout(context),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context),
                        icon: const Icon(Icons.logout, color: RastaTheme.error),
                        label: const Text(
                            'Выйти из аккаунта',
                            style: TextStyle(
                                color: RastaTheme.error,
                                fontSize: 16,
                            ),
                        ),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: RastaTheme.error),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                            ),
                        ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                        child: Text(
                            '🌿 One Love ✌️',
                            style: TextStyle(
                                fontSize: 12,
                                color: RastaTheme.textMuted.withValues(alpha: 0.6),
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildTile(
        BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
    }) {
        return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
                leading: Icon(icon, color: RastaTheme.rastaYellow),
                title: Text(
                    title,
                    style: const TextStyle(
                        color: RastaTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                    ),
                ),
                subtitle: Text(
                    subtitle,
                    style: const TextStyle(
                        color: RastaTheme.textMuted,
                        fontSize: 13,
                    ),
                ),
                trailing: const Icon(
                    Icons.chevron_right,
                    color: RastaTheme.textMuted,
                ),
                onTap: onTap,
            ),
        );
    }

    void _showChangePasswordDialog(BuildContext context) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Смена пароля',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: const Text(
                    'Функция будет доступна в следующей версии.\n\n'
                    'Пока что обратитесь к администратору.',
                    style: TextStyle(color: RastaTheme.textSecondary),
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                            'Понятно',
                            style: TextStyle(color: RastaTheme.rastaYellow),
                        ),
                    ),
                ],
            ),
        );
    }

    void _showPrivacyPolicy(BuildContext context) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Политика обработки ПД',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: const SingleChildScrollView(
                    child: Text(
                        'Дата последнего обновления: 16.09.2026\n\n'
                        '1. Общие положения\n'
                        'Настоящая Политика описывает, как приложение BMSChat '
                        'работает с персональными данными.\n\n'
                        '2. Какие данные мы обрабатываем\n'
                        '• Логин (username)\n'
                        '• Пароль (хранится в виде хеша)\n'
                        '• Отображаемое имя\n'
                        '• Сообщения и их метаданные\n\n'
                        '3. Цели обработки\n'
                        '• Идентификация в приложении\n'
                        '• Обеспечение работы мессенджера\n'
                        '• Связь внутри команды\n\n'
                        '4. Хранение\n'
                        'Данные хранятся на серверах, расположенных на территории РФ.\n\n'
                        '5. Ваши права\n'
                        'Вы можете запросить удаление своих данных.\n\n'
                        '6. Согласие\n'
                        'Используя приложение, вы соглашаетесь с обработкой данных.',
                        style: TextStyle(color: RastaTheme.textSecondary),
                    ),
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                            'Понятно',
                            style: TextStyle(color: RastaTheme.rastaYellow),
                        ),
                    ),
                ],
            ),
        );
    }

    void _showAbout(BuildContext context) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Row(
                    children: [
                        Text('🎯', style: TextStyle(fontSize: 28)),
                        SizedBox(width: 8),
                        Text(
                            'BMSChat',
                            style: TextStyle(color: RastaTheme.rastaYellow),
                        ),
                    ],
                ),
                content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                            'Версия 1.0.0',
                            style: TextStyle(
                                color: RastaTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                            ),
                        ),
                        SizedBox(height: 8),
                        Text(
                            'Мессенджер для команды "Отряд Боба Марли".',
                            style: TextStyle(color: RastaTheme.textSecondary),
                        ),
                        SizedBox(height: 12),
                        Text(
                            'Двигай. Вдохновляй.',
                            style: TextStyle(
                                color: RastaTheme.rastaYellow,
                                fontStyle: FontStyle.italic,
                            ),
                        ),
                    ],
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                            'Закрыть',
                            style: TextStyle(color: RastaTheme.rastaYellow),
                        ),
                    ),
                ],
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
            Navigator.of(context).popUntil((route) => route.isFirst);
        }
    }
}