// =====================================================
// 👥 BMSChat — ЭКРАН СОЗДАНИЯ ГРУППЫ
// =====================================================
// 🎯 Поля:
//   • Название группы (2-100 символов, обязательно)
//   • Описание (0-500 символов, опционально)
//   • Выбор участников через UserMultiSelect
// 🎯 После создания возвращает Chat через Navigator.pop
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/users_provider.dart';
import '../themes/rasta_theme.dart';
import '../widgets/user_multi_select.dart';

class CreateGroupScreen extends StatefulWidget {
    const CreateGroupScreen({super.key});

    @override
    State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
    final _nameController = TextEditingController();
    final _descriptionController = TextEditingController();

    final Set<int> _selectedMemberIds = {};

    bool _isCreating = false;
    String? _error;

    @override
    void initState() {
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UsersProvider>(context, listen: false).loadUsers();
        });
    }

    @override
    void dispose() {
        _nameController.dispose();
        _descriptionController.dispose();
        super.dispose();
    }

    // =====================================================
    // ➕ СОЗДАНИЕ ГРУППЫ
    // =====================================================
    Future<void> _createGroup() async {
        final name = _nameController.text.trim();
        final description = _descriptionController.text.trim();

        // 🎯 Валидация
        if (name.length < 2) {
            setState(() => _error = 'Название минимум 2 символа');
            return;
        }
        if (name.length > 100) {
            setState(() => _error = 'Название максимум 100 символов');
            return;
        }
        if (_selectedMemberIds.isEmpty) {
            setState(() => _error = 'Выберите хотя бы одного участника');
            return;
        }

        setState(() {
            _isCreating = true;
            _error = null;
        });

        try {
            final chat = Provider.of<ChatProvider>(context, listen: false);

            final created = await chat.createGroup(
                name: name,
                description: description.isEmpty ? null : description,
                members: _selectedMemberIds.toList(),
            );

            if (!mounted) return;

            if (created == null) {
                setState(() {
                    _isCreating = false;
                    _error = chat.chatsError ?? 'Не удалось создать группу';
                });
                return;
            }

            // 🎯 Возвращаем созданный чат назад
            Navigator.pop(context, created);
        } catch (e) {
            if (!mounted) return;
            setState(() {
                _isCreating = false;
                _error = 'Ошибка: $e';
            });
        }
    }

    // =====================================================
    // 🎨 BUILD
    // =====================================================
    @override
    Widget build(BuildContext context) {
        final users = Provider.of<UsersProvider>(context);
        final auth = Provider.of<AuthProvider>(context);
        final currentUserId = auth.user?.id ?? 0;

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('👥 Новая группа'),
            ),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // ─────────────────────────────────
                        // НАЗВАНИЕ
                        // ─────────────────────────────────
                        const Text(
                            'Название группы',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: RastaTheme.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                            controller: _nameController,
                            maxLength: 100,
                            style: const TextStyle(
                                color: RastaTheme.textPrimary,
                                fontSize: 16,
                            ),
                            decoration: InputDecoration(
                                hintText: 'Например, «Тренировка 15 октября»',
                                hintStyle: const TextStyle(
                                    color: RastaTheme.textMuted,
                                    fontSize: 16,
                                ),
                                filled: true,
                                fillColor: RastaTheme.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                ),
                            ),
                        ),
                        const SizedBox(height: 16),

                        // ─────────────────────────────────
                        // ОПИСАНИЕ
                        // ─────────────────────────────────
                        const Text(
                            'Описание (опционально)',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: RastaTheme.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                            controller: _descriptionController,
                            maxLines: 3,
                            maxLength: 500,
                            style: const TextStyle(
                                color: RastaTheme.textPrimary,
                                fontSize: 16,
                            ),
                            decoration: InputDecoration(
                                hintText: 'О чём эта группа?',
                                hintStyle: const TextStyle(
                                    color: RastaTheme.textMuted,
                                    fontSize: 16,
                                ),
                                filled: true,
                                fillColor: RastaTheme.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                ),
                            ),
                        ),
                        const SizedBox(height: 16),

                        // ─────────────────────────────────
                        // ВЫБОР УЧАСТНИКОВ
                        // ─────────────────────────────────
                        UserMultiSelect(
                            users: users.allUsers,
                            excludedIds: {currentUserId},
                            initialSelectedIds: _selectedMemberIds,
                            title: 'Участники',
                            onSelectionChanged: (ids) {
                                setState(() {
                                    _selectedMemberIds
                                        ..clear()
                                        ..addAll(ids);
                                });
                            },
                        ),
                        const SizedBox(height: 24),

                        // ─────────────────────────────────
                        // ОШИБКА
                        // ─────────────────────────────────
                        if (_error != null)
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                    color: RastaTheme.error
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: RastaTheme.error
                                            .withValues(alpha: 0.5),
                                    ),
                                ),
                                child: Row(
                                    children: [
                                        const Icon(
                                            Icons.error_outline,
                                            color: RastaTheme.error,
                                            size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                _error!,
                                                style: const TextStyle(
                                                    color: RastaTheme.error,
                                                    fontSize: 14,
                                                ),
                                            ),
                                        ),
                                    ],
                                ),
                            ),

                        // ─────────────────────────────────
                        // КНОПКА СОЗДАНИЯ
                        // ─────────────────────────────────
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                                onPressed: _isCreating ? null : _createGroup,
                                icon: _isCreating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.black,
                                                ),
                                        ),
                                    )
                                    : const Icon(Icons.group_add, size: 20),
                                label: Text(
                                    _isCreating
                                        ? 'Создаю...'
                                        : 'Создать группу',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                    ),
                                ),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: RastaTheme.rastaYellow,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                    ),
                                ),
                            ),
                        ),

                        const SizedBox(height: 24),
                    ],
                ),
            ),
        );
    }
}