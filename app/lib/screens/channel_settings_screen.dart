// =====================================================
// ⚙️ BMSChat — НАСТРОЙКИ КАНАЛА
// =====================================================
// 🎯 ШАГ 13: экран управления каналом.
// 
// Что на экране:
//   • Редактирование (эмодзи, название, описание, приватность)
//   • Список участников + удаление
//   • Кнопка «Добавить участников» (UserMultiSelect)
//   • Удаление канала
// 
// Права:
//   • canManageChannel — редактирование (Админ/Командир/Создатель)
//   • canManageChannelMembers — участники (с учётом is_private)
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/users_provider.dart';
import '../services/api_service.dart';
import '../themes/rasta_theme.dart';
import '../utils/app_logger.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/user_multi_select.dart';

class ChannelSettingsScreen extends StatefulWidget {
    final Chat chat;

    const ChannelSettingsScreen({
        super.key,
        required this.chat,
    });

    @override
    State<ChannelSettingsScreen> createState() =>
        _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState extends State<ChannelSettingsScreen> {
    // =====================================================
    // 📊 СОСТОЯНИЕ
    // =====================================================

    late TextEditingController _nameController;
    late TextEditingController _descriptionController;

    late String _selectedEmoji;
    late bool _isPrivate;

    // Участники (загружаются отдельно)
    List<ChatMember> _members = [];
    bool _isLoadingMembers = true;

    // Индикаторы операций
    bool _isSaving = false;
    bool _isDeleting = false;
    bool _isAddingMembers = false;

    // Флаг — были ли изменения в полях
    bool _hasChanges = false;

    @override
    void initState() {
        super.initState();

        final chat = widget.chat;

        _nameController = TextEditingController(text: chat.name ?? '');
        _descriptionController =
            TextEditingController(text: chat.description ?? '');
        _selectedEmoji = chat.emoji ?? '📢';
        _isPrivate = chat.isPrivate;

        // Слушаем изменения для `_hasChanges`
        _nameController.addListener(_onFieldChanged);
        _descriptionController.addListener(_onFieldChanged);

        _loadMembers();
    }

    @override
    void dispose() {
        _nameController.removeListener(_onFieldChanged);
        _descriptionController.removeListener(_onFieldChanged);
        _nameController.dispose();
        _descriptionController.dispose();
        super.dispose();
    }

    void _onFieldChanged() {
        final changed = _nameController.text.trim() != (widget.chat.name ?? '') ||
            _descriptionController.text.trim() !=
                (widget.chat.description ?? '') ||
            _selectedEmoji != (widget.chat.emoji ?? '📢') ||
            _isPrivate != widget.chat.isPrivate;

        if (changed != _hasChanges) {
            setState(() => _hasChanges = changed);
        }
    }

    // =====================================================
    // 📥 ЗАГРУЗКА УЧАСТНИКОВ
    // =====================================================

    Future<void> _loadMembers() async {
        setState(() => _isLoadingMembers = true);

        try {
            final response = await ApiService.getChat(widget.chat.id);

            if (!mounted) return;

            if (response.isSuccess && response.data != null) {
                final membersJson = response.data!['members'] as List<dynamic>? ?? [];
                setState(() {
                    _members = membersJson
                        .map((m) =>
                            ChatMember.fromJson(m as Map<String, dynamic>))
                        .toList();
                    _isLoadingMembers = false;
                });
            } else {
                setState(() => _isLoadingMembers = false);
                _showSnack('Ошибка загрузки участников', isError: true);
            }
        } catch (e) {
            AppLogger.error('Ошибка загрузки участников', e);
            if (mounted) {
                setState(() => _isLoadingMembers = false);
            }
        }
    }

    // =====================================================
    // 💾 СОХРАНЕНИЕ
    // =====================================================

    Future<void> _save() async {
        final name = _nameController.text.trim();

        if (name.length < 2) {
            _showSnack('Название минимум 2 символа', isError: true);
            return;
        }

        setState(() => _isSaving = true);

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        final description = _descriptionController.text.trim();

        final success = await chatProvider.updateChannel(
            widget.chat.id,
            name: name,
            description: description.isEmpty ? null : description,
            emoji: _selectedEmoji,
            isPrivate: _isPrivate,
        );

        if (!mounted) return;
        setState(() => _isSaving = false);

        if (success) {
            _showSnack('Канал обновлён');
            setState(() => _hasChanges = false);
        } else {
            final reason = chatProvider.chatsError ?? 'неизвестная ошибка';
            _showSnack('Ошибка сохранения: $reason', isError: true);
        }
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
            setState(() {
                _selectedEmoji = emoji;
                _hasChanges = true;
            });
        }
    }

    // =====================================================
    // 🗑️ УДАЛЕНИЕ КАНАЛА
    // =====================================================

    Future<void> _deleteChannel() async {
        final confirmed = await _confirm(
            'Удалить канал?',
            'Канал "${widget.chat.title}" будет удалён. '
                'Сообщения сохранятся, но канал станет недоступен.',
        );

        if (confirmed != true) return;
        if (!mounted) return;

        setState(() => _isDeleting = true);

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        final success = await chatProvider.deleteChannel(widget.chat.id);

        if (!mounted) return;
        setState(() => _isDeleting = false);

        if (success) {
            _showSnack('Канал удалён');
            Navigator.pop(context, 'deleted');
        } else {
            final reason = chatProvider.chatsError ?? 'неизвестная ошибка';
            _showSnack('Ошибка удаления: $reason', isError: true);
        }
    }

    // =====================================================
    // 👥 ДОБАВЛЕНИЕ УЧАСТНИКОВ
    // =====================================================

    Future<void> _openAddMembersDialog() async {
        final usersProvider =
            Provider.of<UsersProvider>(context, listen: false);

        if (usersProvider.count == 0) {
            await usersProvider.loadUsers();
        }

        if (!mounted) return;

        final existingIds = _members.map((m) => m.id).toSet();
        final currentUserId =
            Provider.of<AuthProvider>(context, listen: false).user?.id ?? 0;

        // excludedIds = уже в канале + я сам
        final excluded = {...existingIds, currentUserId};

        final selected = await showModalBottomSheet<Set<int>>(
            context: context,
            backgroundColor: RastaTheme.surface,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (sheetContext) {
                final tempSelected = <int>{};

                return DraggableScrollableSheet(
                    initialChildSize: 0.85,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    expand: false,
                    builder: (context, scrollController) {
                        return StatefulBuilder(
                            builder: (context, setSheetState) {
                                return Column(
                                    children: [
                                        // Ручка
                                        Container(
                                            margin:
                                                const EdgeInsets.only(top: 8),
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                                color: RastaTheme.textMuted
                                                    .withValues(alpha: 0.4),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                            ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                            'Добавить участников',
                                            style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: RastaTheme.textPrimary,
                                            ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(
                                            height: 1,
                                            color: RastaTheme.separator,
                                        ),

                                        // Список
                                        Expanded(
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: UserMultiSelect(
                                                    users: usersProvider
                                                        .allUsers,
                                                    excludedIds: excluded,
                                                    onSelectionChanged:
                                                        (ids) {
                                                        tempSelected
                                                            .clear();
                                                        tempSelected
                                                            .addAll(ids);
                                                    },
                                                    title: null,
                                                    showSearch: true,
                                                ),
                                            ),
                                        ),

                                        // Кнопки
                                        Padding(
                                            padding: EdgeInsets.only(
                                                left: 16,
                                                right: 16,
                                                top: 8,
                                                bottom: 16 +
                                                    MediaQuery.of(
                                                            sheetContext)
                                                        .padding
                                                        .bottom,
                                            ),
                                            child: Row(
                                                children: [
                                                    Expanded(
                                                        child: OutlinedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    sheetContext),
                                                            style: OutlinedButton
                                                                .styleFrom(
                                                                foregroundColor:
                                                                    RastaTheme
                                                                        .textMuted,
                                                                side: BorderSide(
                                                                    color: RastaTheme
                                                                        .textMuted
                                                                        .withValues(
                                                                            alpha:
                                                                                0.5)),
                                                            ),
                                                            child: const Text(
                                                                'Отмена'),
                                                        ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                        child: ElevatedButton(
                                                            onPressed: tempSelected
                                                                    .isEmpty
                                                                ? null
                                                                : () =>
                                                                    Navigator.pop(
                                                                        sheetContext,
                                                                        tempSelected),
                                                            style: ElevatedButton
                                                                .styleFrom(
                                                                backgroundColor:
                                                                    RastaTheme
                                                                        .rastaYellow,
                                                                foregroundColor:
                                                                    Colors.black,
                                                            ),
                                                            child: Text(
                                                                'Добавить '
                                                                '(${tempSelected.length})',
                                                            ),
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

        if (selected == null || selected.isEmpty) return;
        if (!mounted) return;

        setState(() => _isAddingMembers = true);

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        final result =
            await chatProvider.addChannelMembers(widget.chat.id, selected.toList());

        if (!mounted) return;
        setState(() => _isAddingMembers = false);

        if (result == null) {
            final reason = chatProvider.chatsError ?? 'неизвестная ошибка';
            _showSnack('Ошибка добавления: $reason', isError: true);
            return;
        }

        final added = result['added'] ?? 0;
        final filtered = result['filtered'] ?? 0;

        if (added > 0) {
            _showSnack('Добавлено: $added');
        }
        if (filtered > 0) {
            _showSnack(
                'Отфильтровано $filtered (не Бойцы)',
                isError: true,
            );
        }

        // Перезагружаем список
        await _loadMembers();
    }

    // =====================================================
    // 🗑️ УДАЛЕНИЕ УЧАСТНИКА
    // =====================================================

    Future<void> _removeMember(ChatMember member) async {
        final confirmed = await _confirm(
            'Удалить из канала?',
            '${member.displayName} потеряет доступ к каналу.',
        );

        if (confirmed != true) return;
        if (!mounted) return;

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        final success =
            await chatProvider.removeChannelMember(widget.chat.id, member.id);

        if (!mounted) return;

        if (success) {
            _showSnack('${member.displayName} удалён');
            await _loadMembers();
        } else {
            final reason = chatProvider.chatsError ?? 'неизвестная ошибка';
            _showSnack('Ошибка: $reason', isError: true);
        }
    }

    // =====================================================
    // 🔐 ПРАВА
    // =====================================================

    /// Могу ли я редактировать канал (Админ/Командир системы + Создатель)
    bool _canEdit() {
        final me = Provider.of<AuthProvider>(context, listen: false).user;
        if (me == null) return false;

        if (me.isAdmin || me.isCommander) return true;
        if (widget.chat.createdBy == me.id) return true;

        return false;
    }

    /// Могу ли я управлять участниками
    bool _canManageMembers() {
        final me = Provider.of<AuthProvider>(context, listen: false).user;
        if (me == null) return false;

        // Создатель — всегда
        if (widget.chat.createdBy == me.id) return true;

        // Приватный — только создатель (уже проверено выше)
        if (widget.chat.isPrivate) return false;

        // Публичный — Админ/Командир системы
        return me.isAdmin || me.isCommander;
    }

    // =====================================================
    // 🎨 UI
    // =====================================================

    @override
    Widget build(BuildContext context) {
        final canEdit = _canEdit();
        final canManageMembers = _canManageMembers();

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('Настройки канала'),
                actions: [
                    if (canEdit)
                        TextButton(
                            onPressed: (_isSaving || !_hasChanges) ? null : _save,
                            child: _isSaving
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
                                : Text(
                                    'Сохранить',
                                    style: TextStyle(
                                        color: _hasChanges
                                            ? RastaTheme.rastaYellow
                                            : RastaTheme.textMuted,
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
                            // Блок 1: Редактирование
                            // ─────────────────────────────
                            if (canEdit) ...[
                                _buildEditBlock(),
                                const SizedBox(height: 24),
                            ] else
                                _buildNoEditNotice(),

                            // ─────────────────────────────
                            // Блок 2: Участники
                            // ─────────────────────────────
                            _buildMembersBlock(canManageMembers),
                            const SizedBox(height: 32),

                            // ─────────────────────────────
                            // Блок 3: Удаление канала
                            // ─────────────────────────────
                            if (canEdit) _buildDeleteBlock(),

                            const SizedBox(height: 32),
                        ],
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 🎨 БЛОКИ
    // =====================================================

    Widget _buildEditBlock() {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                        'Основное',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: RastaTheme.rastaYellow,
                        ),
                    ),
                    const SizedBox(height: 16),

                    // Эмодзи + Название
                    Row(
                        children: [
                            GestureDetector(
                                onTap: _pickEmoji,
                                child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                                RastaTheme.rastaYellow,
                                                RastaTheme.rastaGreen,
                                            ],
                                        ),
                                    ),
                                    child: Center(
                                        child: Text(
                                            _selectedEmoji,
                                            style: const TextStyle(
                                                fontSize: 30),
                                        ),
                                    ),
                                ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: TextField(
                                    controller: _nameController,
                                    maxLength: 100,
                                    style: const TextStyle(
                                        color: RastaTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                        hintText: 'Название канала',
                                        hintStyle: const TextStyle(
                                            color: RastaTheme.textMuted,
                                            fontSize: 16,
                                            fontWeight: FontWeight.normal,
                                        ),
                                        counterStyle: const TextStyle(
                                            color: RastaTheme.textMuted,
                                            fontSize: 11,
                                        ),
                                        filled: true,
                                        fillColor: RastaTheme.background,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide.none,
                                        ),
                                    ),
                                ),
                            ),
                        ],
                    ),

                    const SizedBox(height: 16),

                    // Описание
                    TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        minLines: 2,
                        style: const TextStyle(
                            color: RastaTheme.textPrimary,
                            fontSize: 15,
                        ),
                        decoration: InputDecoration(
                            hintText: 'Описание',
                            hintStyle: const TextStyle(
                                color: RastaTheme.textMuted,
                                fontSize: 15,
                            ),
                            filled: true,
                            fillColor: RastaTheme.background,
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                            ),
                        ),
                    ),

                    const SizedBox(height: 16),

                    // Приватность
                    Row(
                        children: [
                            Icon(
                                _isPrivate ? Icons.lock : Icons.public,
                                color: _isPrivate
                                    ? RastaTheme.warning
                                    : RastaTheme.rastaGreen,
                                size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    _isPrivate
                                        ? 'Приватный канал'
                                        : 'Публичный канал',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: RastaTheme.textPrimary,
                                    ),
                                ),
                            ),
                            Switch(
                                value: _isPrivate,
                                onChanged: (v) {
                                    setState(() {
                                        _isPrivate = v;
                                        _hasChanges = true;
                                    });
                                },
                                activeThumbColor: RastaTheme.warning,
                            ),
                        ],
                    ),
                ],
            ),
        );
    }

    Widget _buildMembersBlock(bool canManage) {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        children: [
                            const Expanded(
                                child: Text(
                                    'Участники',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: RastaTheme.rastaYellow,
                                    ),
                                ),
                            ),
                            if (canManage && !_isAddingMembers)
                                TextButton.icon(
                                    onPressed: _openAddMembersDialog,
                                    icon: const Icon(
                                        Icons.add,
                                        size: 18,
                                        color: RastaTheme.rastaYellow,
                                    ),
                                    label: const Text(
                                        'Добавить',
                                        style: TextStyle(
                                            color: RastaTheme.rastaYellow,
                                            fontSize: 14,
                                        ),
                                    ),
                                ),
                            if (_isAddingMembers)
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                RastaTheme.rastaYellow,
                                            ),
                                    ),
                                ),
                        ],
                    ),
                    const SizedBox(height: 12),

                    if (_isLoadingMembers)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            RastaTheme.rastaYellow,
                                        ),
                                ),
                            ),
                        )
                    else if (_members.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                                'Нет участников',
                                style: TextStyle(
                                    color: RastaTheme.textMuted,
                                    fontSize: 14,
                                ),
                            ),
                        )
                    else
                        Column(
                            children: _members
                                .map((m) => _buildMemberTile(m, canManage))
                                .toList(),
                        ),
                ],
            ),
        );
    }

    Widget _buildMemberTile(ChatMember member, bool canManage) {
        final me = Provider.of<AuthProvider>(context, listen: false).user;
        final isMe = me?.id == member.id;
        final isCreator = widget.chat.createdBy == member.id;

        // Нельзя удалить: создателя, себя, если ты не создатель
        final canRemove = canManage && !isCreator && !isMe;

        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
                children: [
                    // Аватар
                    CircleAvatar(
                        radius: 20,
                        backgroundColor: RastaTheme.surfaceSecondary,
                        backgroundImage: member.avatar != null
                            ? NetworkImage(member.avatar!)
                            : null,
                        child: member.avatar == null
                            ? Text(
                                member.initials,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: RastaTheme.rastaYellow,
                                ),
                            )
                            : null,
                    ),
                    const SizedBox(width: 12),

                    // Имя + роль
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                    children: [
                                        Flexible(
                                            child: Text(
                                                member.displayName,
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: RastaTheme
                                                        .textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                            ),
                                        ),
                                        if (isCreator) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                    color: RastaTheme
                                                        .rastaYellow
                                                        .withValues(
                                                            alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(6),
                                                ),
                                                child: const Text(
                                                    'создатель',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: RastaTheme
                                                            .rastaYellow,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                    ),
                                                ),
                                            ),
                                        ],
                                    ],
                                ),
                                if (member.isAdmin && !isCreator)
                                    const Text(
                                        'админ канала',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: RastaTheme.rastaGreen,
                                            fontWeight: FontWeight.w600,
                                        ),
                                    ),
                            ],
                        ),
                    ),

                    // Кнопка удаления
                    if (canRemove)
                        IconButton(
                            onPressed: () => _removeMember(member),
                            icon: const Icon(
                                Icons.remove_circle_outline,
                                color: RastaTheme.error,
                                size: 22,
                            ),
                            tooltip: 'Удалить из канала',
                        ),
                ],
            ),
        );
    }

    Widget _buildNoEditNotice() {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
                children: [
                    Icon(
                        Icons.info_outline,
                        color: RastaTheme.textMuted,
                        size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'Редактировать канал может только создатель, '
                            'администратор или командир.',
                            style: TextStyle(
                                fontSize: 13,
                                color: RastaTheme.textMuted,
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildDeleteBlock() {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: RastaTheme.error.withValues(alpha: 0.3),
                    width: 1,
                ),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                        'Опасная зона',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: RastaTheme.error,
                        ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'Удаление канала — необратимо. '
                        'Все сообщения сохранятся в базе, '
                        'но канал станет недоступен.',
                        style: TextStyle(
                            fontSize: 13,
                            color: RastaTheme.textMuted,
                        ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                            onPressed: _isDeleting ? null : _deleteChannel,
                            icon: _isDeleting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                RastaTheme.error,
                                            ),
                                    ),
                                )
                                : const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                ),
                            label: const Text('Удалить канал'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: RastaTheme.error,
                                side: BorderSide(
                                    color: RastaTheme.error
                                        .withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                ),
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 🛠️ СЛУЖЕБНЫЕ
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