// =====================================================
// 👥 BMSChat — НАСТРОЙКИ ГРУППЫ
// =====================================================
// 🎯 Редактирование названия и описания группы.
// 🎯 Кнопка «Покинуть группу» с подтверждением.
// 🎯 Доступно только создателю или командиру/админу.
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';

class GroupSettingsScreen extends StatefulWidget {
    final Chat chat;

    const GroupSettingsScreen({
        super.key,
        required this.chat,
    });

    @override
    State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
    late final TextEditingController _nameController;
    late final TextEditingController _descriptionController;

    bool _isSaving = false;
    bool _isLeaving = false;
    String? _error;

    @override
    void initState() {
        super.initState();
        _nameController = TextEditingController(text: widget.chat.name ?? '');
        _descriptionController =
            TextEditingController(text: widget.chat.description ?? '');
    }

    @override
    void dispose() {
        _nameController.dispose();
        _descriptionController.dispose();
        super.dispose();
    }

    // =====================================================
    // 💾 СОХРАНЕНИЕ ИЗМЕНЕНИЙ
    // =====================================================
    Future<void> _save() async {
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
        if (description.length > 500) {
            setState(() => _error = 'Описание максимум 500 символов');
            return;
        }

        // 🎯 Если ничего не изменилось — просто закрыть
        if (name == (widget.chat.name ?? '') &&
            description == (widget.chat.description ?? '')) {
            Navigator.pop(context, false);
            return;
        }

        setState(() {
            _isSaving = true;
            _error = null;
        });

        try {
            final chat = Provider.of<ChatProvider>(context, listen: false);

            final success = await chat.updateGroup(
                widget.chat.id,
                name: name,
                description: description.isEmpty ? null : description,
            );

            if (!mounted) return;

            if (success) {
                Navigator.pop(context, true);
            } else {
                setState(() {
                    _isSaving = false;
                    _error = chat.chatsError ?? 'Не удалось сохранить';
                });
            }
        } catch (e) {
            if (!mounted) return;
            setState(() {
                _isSaving = false;
                _error = 'Ошибка: $e';
            });
        }
    }

    // =====================================================
    // 🚪 ВЫХОД ИЗ ГРУППЫ
    // =====================================================
    Future<void> _leaveGroup() async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Покинуть группу?',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: Text(
                    'Вы выйдете из группы «${widget.chat.title}». '
                    'Вернуться можно будет только по приглашению.',
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
                            'Выйти',
                            style: TextStyle(color: RastaTheme.error),
                        ),
                    ),
                ],
            ),
        );

        if (confirmed != true || !mounted) return;

        setState(() {
            _isLeaving = true;
            _error = null;
        });

        try {
            final chat = Provider.of<ChatProvider>(context, listen: false);

            final success = await chat.leaveGroup(widget.chat.id);

            if (!mounted) return;

            if (success) {
                // 🎯 Возвращаем 'deleted' — родительский экран поймёт,
                //    что нужно закрыться (чат исчез)
                Navigator.pop(context, 'left');
            } else {
                setState(() {
                    _isLeaving = false;
                    _error = chat.chatsError ?? 'Не удалось выйти';
                });
            }
        } catch (e) {
            if (!mounted) return;
            setState(() {
                _isLeaving = false;
                _error = 'Ошибка: $e';
            });
        }
    }

    // =====================================================
    // 🎯 ПРАВО НА РЕДАКТИРОВАНИЕ
    // =====================================================
    bool _canEdit() {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final me = auth.user;
        if (me == null) return false;

        // Создатель
        if (widget.chat.createdBy == me.id) return true;

        // Админ или командир
        if (me.isAdmin || me.isCommander) return true;

        return false;
    }

    // =====================================================
    // 🎯 BUILD
    // =====================================================
    @override
    Widget build(BuildContext context) {
        final canEdit = _canEdit();
        final isCreator = widget.chat.createdBy ==
            Provider.of<AuthProvider>(context, listen: false).user?.id;

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('⚙️ Настройки группы'),
            ),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // ─────────────────────────────────
                        // ИНФОРМАЦИЯ О ГРУППЕ
                        // ─────────────────────────────────
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: RastaTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        widget.chat.title,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: RastaTheme.textPrimary,
                                        ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${widget.chat.membersCount} участников',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: RastaTheme.textMuted,
                                        ),
                                    ),
                                ],
                            ),
                        ),
                        const SizedBox(height: 24),

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
                            enabled: canEdit && !_isSaving && !_isLeaving,
                            style: const TextStyle(
                                color: RastaTheme.textPrimary,
                                fontSize: 16,
                            ),
                            decoration: InputDecoration(
                                hintText: 'Название',
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
                            'Описание',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: RastaTheme.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            maxLength: 500,
                            enabled: canEdit && !_isSaving && !_isLeaving,
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
                        // КНОПКА СОХРАНИТЬ (только для canEdit)
                        // ─────────────────────────────────
                        if (canEdit)
                            SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                    onPressed: (_isSaving || _isLeaving)
                                        ? null
                                        : _save,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.black),
                                            ),
                                        )
                                        : const Icon(Icons.save, size: 20),
                                    label: Text(
                                        _isSaving ? 'Сохраняю...' : 'Сохранить',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                        ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            RastaTheme.rastaYellow,
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

                        // ─────────────────────────────────
                        // КНОПКА ПОКИНУТЬ (не для создателя)
                        // ─────────────────────────────────
                        if (!isCreator)
                            SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                    onPressed: (_isSaving || _isLeaving)
                                        ? null
                                        : _leaveGroup,
                                    icon: _isLeaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                    RastaTheme.error,
                                                ),
                                            ),
                                        )
                                        : const Icon(
                                            Icons.logout,
                                            size: 20,
                                            color: RastaTheme.error,
                                        ),
                                    label: Text(
                                        _isLeaving
                                            ? 'Выхожу...'
                                            : 'Покинуть группу',
                                        style: const TextStyle(
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                        ),
                                    ),
                                ),
                            ),

                        // ─────────────────────────────────
                        // ПОДСКАЗКА ДЛЯ НЕ-АДМИНОВ
                        // ─────────────────────────────────
                        if (!canEdit)
                            Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: RastaTheme.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                    children: [
                                        const Icon(
                                            Icons.info_outline,
                                            color: RastaTheme.textMuted,
                                            size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                'Редактировать группу может '
                                                'только создатель или командир',
                                                style: TextStyle(
                                                    color: RastaTheme
                                                        .textMuted
                                                        .withValues(alpha: 0.9),
                                                    fontSize: 13,
                                                ),
                                            ),
                                        ),
                                    ],
                                ),
                            ),

                        const SizedBox(height: 24),
                    ],
                ),
            ),
        );
    }
}