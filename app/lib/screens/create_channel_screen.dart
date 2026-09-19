// =====================================================
// 📢 BMSChat — ЭКРАН СОЗДАНИЯ КАНАЛА
// =====================================================
// 🎯 ШАГ 12: создание канала.
// 
// Что на экране:
//   • Название (обязательно, 2–100 символов)
//   • Описание (опционально)
//   • Эмодзи-аватар (showChannelEmojiPicker)
//   • Приватный/публичный (Switch)
//   • Выбор участников (UserMultiSelect)
//   • Кнопка «Создать»
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/users_provider.dart';
import '../themes/rasta_theme.dart';
import '../utils/app_logger.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/user_multi_select.dart';

class CreateChannelScreen extends StatefulWidget {
    const CreateChannelScreen({super.key});

    @override
    State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
    final _nameController = TextEditingController();
    final _descriptionController = TextEditingController();

    String _selectedEmoji = '📢';
    bool _isPrivate = false;
    final Set<int> _selectedUserIds = {};
    bool _isCreating = false;

    @override
    void initState() {
        super.initState();

        // Подгружаем пользователей, если ещё не загружены
        WidgetsBinding.instance.addPostFrameCallback((_) {
            final users = Provider.of<UsersProvider>(context, listen: false);
            if (users.count == 0) {
                users.loadUsers();
            }
        });
    }

    @override
    void dispose() {
        _nameController.dispose();
        _descriptionController.dispose();
        super.dispose();
    }

    // =====================================================
    // 🎯 СОЗДАНИЕ
    // =====================================================

    Future<void> _create() async {
        final name = _nameController.text.trim();

        if (name.length < 2) {
            _showSnack('Название минимум 2 символа', isError: true);
            return;
        }

        if (name.length > 100) {
            _showSnack('Название максимум 100 символов', isError: true);
            return;
        }

        setState(() => _isCreating = true);

        final chat = Provider.of<ChatProvider>(context, listen: false);
        final description = _descriptionController.text.trim();

        final created = await chat.createChannel(
            name: name,
            description: description.isEmpty ? null : description,
            isPrivate: _isPrivate,
            emoji: _selectedEmoji,
            members: _selectedUserIds.toList(),
        );

        if (!mounted) return;
        setState(() => _isCreating = false);

        if (created == null) {
            final reason = chat.chatsError ?? 'неизвестная ошибка';
            _showSnack('Ошибка создания: $reason', isError: true);
            return;
        }

        AppLogger.success('Канал создан: ${created.id}');
        _showSnack('Канал "${created.title}" создан');

        // Возвращаем созданный канал на предыдущий экран
        Navigator.pop(context, created);
    }

    // =====================================================
    // 😀 ВЫБОР ЭМОДЗИ
    // =====================================================

    Future<void> _pickEmoji() async {
        final emoji = await showChannelEmojiPicker(
            context,
            initialEmoji: _selectedEmoji,
        );

        if (emoji != null && mounted) {
            setState(() => _selectedEmoji = emoji);
        }
    }

    // =====================================================
    // 🎨 UI
    // =====================================================

    @override
    Widget build(BuildContext context) {
        final auth = Provider.of<AuthProvider>(context);
        final users = Provider.of<UsersProvider>(context);

        // Исключаем самого создателя из списка выбора
        final currentUserId = auth.user?.id ?? 0;
        final excludedIds = <int>{currentUserId};

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('Новый канал'),
                actions: [
                    // Кнопка «Создать» в AppBar
                    TextButton(
                        onPressed: _isCreating ? null : _create,
                        child: _isCreating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            RastaTheme.rastaYellow,
                                        ),
                                ),
                            )
                            : const Text(
                                'Создать',
                                style: TextStyle(
                                    color: RastaTheme.rastaYellow,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                ),
                            ),
                    ),
                ],
            ),
            body: SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // ─────────────────────────────
                            // Эмодзи + Название (в одной строке)
                            // ─────────────────────────────
                            _buildHeaderBlock(),
                            const SizedBox(height: 20),

                            // ─────────────────────────────
                            // Описание
                            // ─────────────────────────────
                            _buildSection(
                                title: 'Описание',
                                child: TextField(
                                    controller: _descriptionController,
                                    maxLines: 4,
                                    minLines: 2,
                                    style: const TextStyle(
                                        color: RastaTheme.textPrimary,
                                        fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                        hintText: 'О чём этот канал?',
                                        hintStyle: const TextStyle(
                                            color: RastaTheme.textMuted,
                                            fontSize: 15,
                                        ),
                                        filled: true,
                                        fillColor: RastaTheme.surface,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                        ),
                                    ),
                                ),
                            ),
                            const SizedBox(height: 20),

                            // ─────────────────────────────
                            // Приватный/публичный
                            // ─────────────────────────────
                            _buildPrivacySwitch(),
                            const SizedBox(height: 24),

                            // ─────────────────────────────
                            // Участники
                            // ─────────────────────────────
                            _buildSection(
                                title: 'Участники',
                                child: users.isLoading && users.count == 0
                                    ? _buildUsersLoading()
                                    : UserMultiSelect(
                                        users: users.allUsers,
                                        excludedIds: excludedIds,
                                        onSelectionChanged: (ids) {
                                            setState(() {
                                                _selectedUserIds
                                                    .clear();
                                                _selectedUserIds
                                                    .addAll(ids);
                                            });
                                        },
                                        title: null,
                                        showSearch: true,
                                    ),
                            ),
                            const SizedBox(height: 32),
                        ],
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 🎨 БЛОКИ UI
    // =====================================================

    /// Эмодзи + поле названия
    Widget _buildHeaderBlock() {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
                children: [
                    // ─────────────────────
                    // Эмодзи-кнопка
                    // ─────────────────────
                    GestureDetector(
                        onTap: _pickEmoji,
                        child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                        RastaTheme.rastaYellow,
                                        RastaTheme.rastaGreen,
                                    ],
                                ),
                                boxShadow: [
                                    BoxShadow(
                                        color: RastaTheme.rastaYellow
                                            .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                    ),
                                ],
                            ),
                            child: Center(
                                child: Text(
                                    _selectedEmoji,
                                    style: const TextStyle(fontSize: 34),
                                ),
                            ),
                        ),
                    ),

                    const SizedBox(width: 16),

                    // ─────────────────────
                    // Поле названия
                    // ─────────────────────
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const Text(
                                    'Название',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: RastaTheme.textMuted,
                                        fontWeight: FontWeight.w600,
                                    ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                    controller: _nameController,
                                    maxLength: 100,
                                    style: const TextStyle(
                                        color: RastaTheme.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                        hintText: 'Например: Новости отряда',
                                        hintStyle: TextStyle(
                                            color: RastaTheme.textMuted,
                                            fontSize: 16,
                                            fontWeight: FontWeight.normal,
                                        ),
                                        counterStyle: TextStyle(
                                            color: RastaTheme.textMuted,
                                            fontSize: 11,
                                        ),
                                        filled: true,
                                        fillColor: RastaTheme.background,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                        ),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(10),
                                            ),
                                            borderSide: BorderSide.none,
                                        ),
                                    ),
                                ),
                            ],
                        ),
                    ),
                ],
            ),
        );
    }

    /// Переключатель приватности
    Widget _buildPrivacySwitch() {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
                children: [
                    Icon(
                        _isPrivate ? Icons.lock : Icons.public,
                        color: _isPrivate
                            ? RastaTheme.warning
                            : RastaTheme.rastaGreen,
                        size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                    _isPrivate
                                        ? 'Приватный канал'
                                        : 'Публичный канал',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: RastaTheme.textPrimary,
                                    ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    _isPrivate
                                        ? 'Только приглашённые видят и пишут'
                                        : 'Виден всем Бойцам, но писать — только участники',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: RastaTheme.textMuted,
                                    ),
                                ),
                            ],
                        ),
                    ),
                    Switch(
                        value: _isPrivate,
                        onChanged: (v) => setState(() => _isPrivate = v),
                        activeThumbColor: RastaTheme.warning,
                    ),
                ],
            ),
        );
    }

    /// Секция с заголовком
    Widget _buildSection({
        required String title,
        required Widget child,
    }) {
        return Container(
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
                            fontSize: 15,
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

    Widget _buildUsersLoading() {
        return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        RastaTheme.rastaYellow,
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 🛠️ SNACKBAR
    // =====================================================

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