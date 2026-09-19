// =====================================================
// 👥 BMSChat — ВЫБОР НЕСКОЛЬКИХ ПОЛЬЗОВАТЕЛЕЙ
// =====================================================
// 🎯 ШАГ 11: виджет для выбора участников канала.
// 
// Используется в:
//   • create_channel_screen.dart (создание канала)
//   • channel_settings_screen.dart (добавление участников)
// 
// Фильтр:
//   • Только подтверждённые Бойцы/Командиры/Админы
//   • Не Новобранцы
//   • Не сам создатель
// =====================================================

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../themes/rasta_theme.dart';

class UserMultiSelect extends StatefulWidget {
    /// Список всех доступных пользователей
    final List<User> users;

    /// ID, которые нужно исключить (например, создатель, уже в канале)
    final Set<int> excludedIds;

    /// ID, которые уже выбраны (начальное состояние)
    final Set<int> initialSelectedIds;

    /// Callback: вызывается при изменении выбора
    final ValueChanged<Set<int>> onSelectionChanged;

    /// Заголовок (опционально)
    final String? title;

    /// Показывать ли поиск
    final bool showSearch;

    const UserMultiSelect({
        super.key,
        required this.users,
        required this.onSelectionChanged,
        this.excludedIds = const {},
        this.initialSelectedIds = const {},
        this.title,
        this.showSearch = true,
    });

    @override
    State<UserMultiSelect> createState() => _UserMultiSelectState();
}

class _UserMultiSelectState extends State<UserMultiSelect> {
    final _searchController = TextEditingController();
    String _searchQuery = '';
    late Set<int> _selectedIds;

    @override
    void initState() {
        super.initState();
        _selectedIds = Set.from(widget.initialSelectedIds);
    }

    @override
    void dispose() {
        _searchController.dispose();
        super.dispose();
    }

    // =====================================================
    // 🔍 ФИЛЬТРАЦИЯ
    // =====================================================

    /// Пользователи, доступные для выбора (после фильтров).
    List<User> get _availableUsers {
        return widget.users.where((u) {
            // Исключаем тех, кто в excludedIds
            if (widget.excludedIds.contains(u.id)) return false;

            // Только подтверждённые
            if (!u.isApproved) return false;

            // Только Бойцы+ (не Новобранцы)
            if (!u.isSoldier && !u.isCommander && !u.isAdmin) return false;

            // Поиск
            if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                final nameMatch = u.displayName.toLowerCase().contains(q);
                final usernameMatch = u.username.toLowerCase().contains(q);
                if (!nameMatch && !usernameMatch) return false;
            }

            return true;
        }).toList()
            ..sort((a, b) {
                // Онлайн — выше
                if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
                // Потом по алфавиту
                return a.displayName.compareTo(b.displayName);
            });
    }

    // =====================================================
    // 🎯 ВЫБОР
    // =====================================================

    void _toggleSelection(int userId) {
        setState(() {
            if (_selectedIds.contains(userId)) {
                _selectedIds.remove(userId);
            } else {
                _selectedIds.add(userId);
            }
        });
        widget.onSelectionChanged(_selectedIds);
    }

    void _clearAll() {
        setState(() => _selectedIds.clear());
        widget.onSelectionChanged(_selectedIds);
    }

    // =====================================================
    // 🎨 UI
    // =====================================================

    @override
    Widget build(BuildContext context) {
        final available = _availableUsers;
        final selectedCount = _selectedIds.length;

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // ─────────────────────────────
                // Заголовок + счётчик
                // ─────────────────────────────
                if (widget.title != null) ...[
                    Row(
                        children: [
                            Expanded(
                                child: Text(
                                    widget.title!,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: RastaTheme.textPrimary,
                                    ),
                                ),
                            ),
                            if (selectedCount > 0)
                                Text(
                                    'Выбрано: $selectedCount',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: RastaTheme.rastaYellow,
                                        fontWeight: FontWeight.w600,
                                    ),
                                ),
                        ],
                    ),
                    const SizedBox(height: 8),
                ],

                // ─────────────────────────────
                // Поиск
                // ─────────────────────────────
                if (widget.showSearch) ...[
                    TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                            color: RastaTheme.textPrimary,
                            fontSize: 15,
                        ),
                        decoration: InputDecoration(
                            hintText: 'Поиск пользователей...',
                            hintStyle: const TextStyle(
                                color: RastaTheme.textMuted,
                                fontSize: 15,
                            ),
                            prefixIcon: const Icon(
                                Icons.search,
                                color: RastaTheme.rastaYellow,
                                size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                        Icons.close,
                                        color: RastaTheme.textMuted,
                                        size: 18,
                                    ),
                                    onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                    },
                                )
                                : null,
                            filled: true,
                            fillColor: RastaTheme.background,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                            ),
                        ),
                    ),
                    const SizedBox(height: 8),
                ],

                // ─────────────────────────────
                // Кнопка «Очистить»
                // ─────────────────────────────
                if (selectedCount > 0) ...[
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                            onPressed: _clearAll,
                            icon: const Icon(
                                Icons.clear_all,
                                size: 16,
                                color: RastaTheme.rastaYellow,
                            ),
                            label: const Text(
                                'Очистить',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: RastaTheme.rastaYellow,
                                ),
                            ),
                        ),
                    ),
                ],

                // ─────────────────────────────
                // Список
                // ─────────────────────────────
                if (available.isEmpty)
                    _buildEmpty()
                else
                    Flexible(
                        child: ListView.builder(
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            itemCount: available.length,
                            itemBuilder: (context, index) {
                                return _buildUserTile(available[index]);
                            },
                        ),
                    ),
            ],
        );
    }

    // =====================================================
    // 📋 ЭЛЕМЕНТ СПИСКА
    // =====================================================

    Widget _buildUserTile(User user) {
        final isSelected = _selectedIds.contains(user.id);

        return InkWell(
            onTap: () => _toggleSelection(user.id),
            child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                ),
                child: Row(
                    children: [
                        // ─────────────────────
                        // Аватар
                        // ─────────────────────
                        Stack(
                            children: [
                                CircleAvatar(
                                    radius: 22,
                                    backgroundColor:
                                        RastaTheme.surfaceSecondary,
                                    backgroundImage: user.avatar != null
                                        ? NetworkImage(user.avatar!)
                                        : null,
                                    child: user.avatar == null
                                        ? Text(
                                            user.initials,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: RastaTheme.rastaYellow,
                                            ),
                                        )
                                        : null,
                                ),
                                Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            color: user.isOnline
                                                ? RastaTheme.online
                                                : RastaTheme.offline,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: RastaTheme.background,
                                                width: 2,
                                            ),
                                        ),
                                    ),
                                ),
                            ],
                        ),

                        const SizedBox(width: 12),

                        // ─────────────────────
                        // Имя + роль
                        // ─────────────────────
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        user.displayName,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: RastaTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                    if (user.primaryRole != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                            user.primaryRole!.name,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Color(
                                                    user.primaryRole!.colorValue,
                                                ),
                                                fontWeight: FontWeight.w600,
                                            ),
                                        ),
                                    ],
                                ],
                            ),
                        ),

                        // ─────────────────────
                        // Чекбокс
                        // ─────────────────────
                        Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? RastaTheme.rastaYellow
                                    : Colors.transparent,
                                border: Border.all(
                                    color: isSelected
                                        ? RastaTheme.rastaYellow
                                        : RastaTheme.textMuted,
                                    width: 2,
                                ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.black,
                                )
                                : null,
                        ),
                    ],
                ),
            ),
        );
    }

    // =====================================================
    // 📭 ПУСТО
    // =====================================================

    Widget _buildEmpty() {
        return Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
                children: [
                    const Icon(
                        Icons.people_outline,
                        size: 48,
                        color: RastaTheme.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                        _searchQuery.isNotEmpty
                            ? 'Никого не найдено'
                            : 'Нет доступных пользователей',
                        style: const TextStyle(
                            fontSize: 14,
                            color: RastaTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                    ),
                ],
            ),
        );
    }
}