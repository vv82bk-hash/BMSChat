// =====================================================
// 👤 BMSChat — ЭКРАН ПРОФИЛЯ
// =====================================================
// 🎯 Аватар: тап → галерея/камера → загрузка на сервер
// 🎯 Имя: карандаш → диалог → PATCH /api/users/me
// 🎯 Аватар показывается через CachedNetworkImage, если есть
// =====================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../themes/rasta_theme.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
    const ProfileScreen({super.key});

    @override
    State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
    final _imagePicker = ImagePicker();
    bool _isUploadingAvatar = false;

    // ============================================
    // 🖼️ АВАТАР
    // ============================================
    Widget _buildAvatar(User user) {
        final hasAvatar = user.avatar != null && user.avatar!.isNotEmpty;
        final avatarUrl = hasAvatar
            ? Constants.getFullFileUrl(user.avatar)
            : null;

        return GestureDetector(
            onTap: _isUploadingAvatar ? null : () => _onAvatarTap(),
            child: Stack(
                children: [
                    Container(
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
                                    color: RastaTheme.rastaYellow
                                        .withValues(alpha: 0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                ),
                            ],
                        ),
                        child: ClipOval(
                            child: _isUploadingAvatar
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                RastaTheme.rastaYellow,
                                            ),
                                    ),
                                )
                                : hasAvatar
                                    ? CachedNetworkImage(
                                        imageUrl: avatarUrl!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            _buildInitials(user),
                                        errorWidget:
                                            (context, url, error) =>
                                                _buildInitials(user),
                                    )
                                    : _buildInitials(user),
                        ),
                    ),

                    Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: RastaTheme.rastaYellow,
                                border: Border.all(
                                    color: RastaTheme.background,
                                    width: 3,
                                ),
                            ),
                            child: const Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                                size: 18,
                            ),
                        ),
                    ),
                ],
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

    Future<void> _onAvatarTap() async {
        final source = await showModalBottomSheet<ImageSource>(
            context: context,
            backgroundColor: RastaTheme.surface,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => SafeArea(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        const SizedBox(height: 8),
                        Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: RastaTheme.textMuted
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                            ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                            'Сменить аватар',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: RastaTheme.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                            leading: const Icon(
                                Icons.photo_library_outlined,
                                color: RastaTheme.rastaYellow,
                                size: 28,
                            ),
                            title: const Text(
                                'Из галереи',
                                style: TextStyle(
                                    color: RastaTheme.textPrimary,
                                    fontSize: 16,
                                ),
                            ),
                            onTap: () =>
                                Navigator.pop(context, ImageSource.gallery),
                        ),
                        ListTile(
                            leading: const Icon(
                                Icons.camera_alt_outlined,
                                color: RastaTheme.rastaYellow,
                                size: 28,
                            ),
                            title: const Text(
                                'Сделать фото',
                                style: TextStyle(
                                    color: RastaTheme.textPrimary,
                                    fontSize: 16,
                                ),
                            ),
                            onTap: () =>
                                Navigator.pop(context, ImageSource.camera),
                        ),
                        const SizedBox(height: 8),
                    ],
                ),
            ),
        );

        if (source == null || !mounted) return;

        try {
            final XFile? image = await _imagePicker.pickImage(
                source: source,
                imageQuality: 80,
                maxWidth: 800,
                maxHeight: 800,
            );

            if (image == null) return;
            if (!mounted) return;

            setState(() => _isUploadingAvatar = true);

            final uploadResponse = await ApiService.uploadFile(image, 'image');

            if (!mounted) return;

            if (!uploadResponse.isSuccess || uploadResponse.data == null) {
                _showError(
                    uploadResponse.error ?? 'Не удалось загрузить аватар',
                );
                setState(() => _isUploadingAvatar = false);
                return;
            }

            final uploadedPath =
                uploadResponse.data!['file_path'] as String?;

            if (uploadedPath == null) {
                _showError('Сервер не вернул путь к файлу');
                setState(() => _isUploadingAvatar = false);
                return;
            }

            final auth = Provider.of<AuthProvider>(context, listen: false);
            final success = await auth.updateProfile(avatar: uploadedPath);

            if (!mounted) return;

            setState(() => _isUploadingAvatar = false);

            if (success) {
                _showInfo('Аватар обновлён');
            } else {
                _showError(auth.error ?? 'Не удалось сохранить аватар');
            }
        } catch (e) {
            if (!mounted) return;
            setState(() => _isUploadingAvatar = false);
            _showError('Ошибка: $e');
        }
    }

    // ============================================
    // 📝 ИМЯ
    // ============================================
    Widget _buildNameSection(User user) {
        return Column(
            children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Flexible(
                            child: Text(
                                user.displayName,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: RastaTheme.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                            ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                            icon: const Icon(
                                Icons.edit,
                                size: 20,
                                color: RastaTheme.rastaYellow,
                            ),
                            tooltip: 'Изменить имя',
                            onPressed: () => _onEditNameTap(user),
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
            ],
        );
    }

    Future<void> _onEditNameTap(User user) async {
        final controller = TextEditingController(text: user.displayName);

        final newName = await showDialog<String>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Изменить имя',
                    style: TextStyle(
                        color: RastaTheme.textPrimary,
                        fontSize: 20,
                    ),
                ),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 100,
                    style: const TextStyle(
                        color: RastaTheme.textPrimary,
                        fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                        hintText: 'Как вас зовут?',
                        hintStyle: TextStyle(color: RastaTheme.textMuted),
                        counterStyle: TextStyle(color: RastaTheme.textMuted),
                    ),
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                            'Отмена',
                            style: TextStyle(
                                color: RastaTheme.textMuted,
                                fontSize: 16,
                            ),
                        ),
                    ),
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text(
                            'Сохранить',
                            style: TextStyle(
                                color: RastaTheme.rastaYellow,
                                fontSize: 16,
                            ),
                        ),
                    ),
                ],
            ),
        );

        if (newName == null || newName.isEmpty) return;
        if (newName == user.displayName) return;
        if (newName.length < 2) {
            _showError('Имя слишком короткое');
            return;
        }

        if (!mounted) return;

        final auth = Provider.of<AuthProvider>(context, listen: false);
        final success = await auth.updateProfile(displayName: newName);

        if (!mounted) return;

        if (success) {
            _showInfo('Имя обновлено');
        } else {
            _showError(auth.error ?? 'Не удалось сохранить имя');
        }
    }

    // ============================================
    // 🎭 РОЛИ
    // ============================================
    Widget _buildRolesSection(User user) {
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
                        Icons.circle,
                        'Статус',
                        user.isOnline ? 'Онлайн' : 'Офлайн',
                        color: user.isOnline
                            ? RastaTheme.online
                            : RastaTheme.textMuted,
                    ),
                    const SizedBox(height: 8),
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

    // ============================================
    // 🎨 BUILD
    // ============================================
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
}

class _Permission {
    final String label;
    final bool allowed;

    const _Permission(this.label, this.allowed);
}