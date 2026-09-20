// =====================================================
// 💬 BMSChat — МОДЕЛЬ ЧАТА
// =====================================================
// 🎯 unreadCount: количество непрочитанных сообщений
// 🎯 isPrivate: приватный ли канал
// 🎯 isMember: я участник чата?
// 🎯 emoji: эмодзи-аватар (для каналов и чатов)
//
// 🔧 v2: _intToBool теперь парсит строки ('true', '1', 't')
// 🎯 DEBUG: временные print в fromJson (убрать после диагностики)
// 🎯 ЭТАП C.1: Telegram-формат даты и превью
//   • lastMessageTime — 14:30 / вчера / Пн / 12 сентября / 12.09.24
//   • lastMessagePreview — 🖼 Фото / 🎤 Голосовое / 📎 Файл
// 🎯 ЭМОДЗИ «Потарахтеть»:
//   • useLogoImage — теперь только для general-чатов БЕЗ emoji.
//     Если у general-чата задан emoji (например, 🍁) —
//     он показывается вместо логотипа.
// =====================================================

class Chat {
    // =====================================================
    // 📋 ОСНОВНЫЕ ПОЛЯ
    // =====================================================

    final int id;
    final String type;
    final String? name;
    final String? displayName;
    final String? description;
    final String? avatar;
    final int? createdBy;
    final bool isActive;
    final DateTime? createdAt;
    final DateTime? updatedAt;

    // =====================================================
    // 📊 ДАННЫЕ О ЧАТЕ
    // =====================================================

    final String? myRole;
    final int membersCount;
    final int? lastMessageId;
    final String? lastMessageText;
    final DateTime? lastMessageAt;
    final List<ChatMember> members;

    /// 🎯 Количество непрочитанных сообщений
    final int unreadCount;

    // =====================================================
    // 🎯 ШАГ 7: НОВЫЕ ПОЛЯ ДЛЯ КАНАЛОВ
    // =====================================================

    /// 🎯 Приватный ли канал? (только приглашённые видят/читают/пишут)
    final bool isPrivate;

    /// 🎯 Я участник чата? (для каналов — критично: не-участник видит,
    /// но не может открыть/писать до «Вступить»)
    final bool isMember;

    /// 🎯 Эмодзи-аватар (для каналов и кастомных чатов).
    /// Если null — для каналов дефолт '📢', для general — логотип.
    final String? emoji;

    // =====================================================
    // 🏗️ КОНСТРУКТОР
    // =====================================================

    const Chat({
        required this.id,
        required this.type,
        this.name,
        this.displayName,
        this.description,
        this.avatar,
        this.createdBy,
        this.isActive = true,
        this.createdAt,
        this.updatedAt,
        this.myRole,
        this.membersCount = 0,
        this.lastMessageId,
        this.lastMessageText,
        this.lastMessageAt,
        this.members = const [],
        this.unreadCount = 0,
        // 🎯 ШАГ 7:
        this.isPrivate = false,
        this.isMember = false,
        this.emoji,
    });

    // =====================================================
    // 📥 FROM JSON
    // =====================================================

    factory Chat.fromJson(Map<String, dynamic> json) {
        // 🎯 DEBUG: для каналов — посмотреть реальные типы полей
        if (json['type'] == 'channel') {
            // ignore: avoid_print
            print('🔍 Chat.fromJson CHANNEL: '
                'id=${json['id']}, '
                'is_member=${json['is_member']} '
                '(${json['is_member'].runtimeType}), '
                'is_private=${json['is_private']} '
                '(${json['is_private'].runtimeType}), '
                'emoji=${json['emoji']} '
                '(${json['emoji'].runtimeType})');
        }

        return Chat(
            id: json['id'] as int? ?? 0,
            type: json['type'] as String? ?? 'group',
            name: json['name'] as String?,
            displayName: json['display_name'] as String?,
            description: json['description'] as String?,
            avatar: json['avatar'] as String?,
            createdBy: json['created_by'] as int?,
            isActive: _intToBool(json['is_active']),
            createdAt: _parseDate(json['created_at']),
            updatedAt: _parseDate(json['updated_at']),
            myRole: json['my_role'] as String?,
            membersCount: json['members_count'] as int? ?? 0,
            lastMessageId: json['last_message_id'] as int?,
            lastMessageText: json['last_message_text'] as String?,
            lastMessageAt: _parseDate(json['last_message_at']),
            members: (json['members'] as List<dynamic>?)
                ?.map((m) => ChatMember.fromJson(m as Map<String, dynamic>))
                .toList() ?? [],
            unreadCount: json['unread_count'] as int?
                ?? json['unreadCount'] as int?
                ?? 0,
            // 🎯 ШАГ 7:
            isPrivate: _intToBool(json['is_private']),
            isMember: _intToBool(json['is_member']),
            emoji: _parseEmoji(json['emoji']),
        );
    }

    // =====================================================
    // 📤 TO JSON
    // =====================================================

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'type': type,
            'name': name,
            'display_name': displayName,
            'description': description,
            'avatar': avatar,
            'created_by': createdBy,
            'is_active': isActive ? 1 : 0,
            'created_at': createdAt?.toIso8601String(),
            'updated_at': updatedAt?.toIso8601String(),
            'my_role': myRole,
            'members_count': membersCount,
            'last_message_id': lastMessageId,
            'last_message_text': lastMessageText,
            'last_message_at': lastMessageAt?.toIso8601String(),
            'unread_count': unreadCount,
            // 🎯 ШАГ 7:
            'is_private': isPrivate ? 1 : 0,
            'is_member': isMember ? 1 : 0,
            'emoji': emoji,
        };
    }

    // =====================================================
    // 📋 COPY WITH
    // =====================================================

    Chat copyWith({
        int? id,
        String? type,
        String? name,
        String? displayName,
        String? description,
        String? avatar,
        int? createdBy,
        bool? isActive,
        DateTime? createdAt,
        DateTime? updatedAt,
        String? myRole,
        int? membersCount,
        int? lastMessageId,
        String? lastMessageText,
        DateTime? lastMessageAt,
        List<ChatMember>? members,
        int? unreadCount,
        // 🎯 ШАГ 7:
        bool? isPrivate,
        bool? isMember,
        String? emoji,
    }) {
        return Chat(
            id: id ?? this.id,
            type: type ?? this.type,
            name: name ?? this.name,
            displayName: displayName ?? this.displayName,
            description: description ?? this.description,
            avatar: avatar ?? this.avatar,
            createdBy: createdBy ?? this.createdBy,
            isActive: isActive ?? this.isActive,
            createdAt: createdAt ?? this.createdAt,
            updatedAt: updatedAt ?? this.updatedAt,
            myRole: myRole ?? this.myRole,
            membersCount: membersCount ?? this.membersCount,
            lastMessageId: lastMessageId ?? this.lastMessageId,
            lastMessageText: lastMessageText ?? this.lastMessageText,
            lastMessageAt: lastMessageAt ?? this.lastMessageAt,
            members: members ?? this.members,
            unreadCount: unreadCount ?? this.unreadCount,
            // 🎯 ШАГ 7:
            isPrivate: isPrivate ?? this.isPrivate,
            isMember: isMember ?? this.isMember,
            emoji: emoji ?? this.emoji,
        );
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ
    // =====================================================

    bool get isPrivateChat => type == 'private';
    bool get isGeneral => type == 'general';
    bool get isGroup => type == 'group';
    bool get isChannel => type == 'channel';

    bool get isAdmin => myRole == 'admin';
    bool get isMemberOfChat => myRole == 'member';

    /// Есть ли непрочитанные?
    bool get hasUnread => unreadCount > 0;

    // =====================================================
    // 🎯 ШАГ 7: НОВЫЕ ГЕТТЕРЫ ДЛЯ КАНАЛОВ
    // =====================================================

    /// 🎯 Показывать ли эмодзи-аватар?
    bool get hasEmojiAvatar =>
        emoji != null && emoji!.isNotEmpty;

    /// 🎯 Эмодзи-аватар или дефолт:
    ///   • Если emoji задано — оно.
    ///   • Если канал без emoji — '📢'.
    ///   • Иначе — стандартная иконка типа.
    String get displayEmoji {
        if (emoji != null && emoji!.isNotEmpty && emoji != '??') {
            return emoji!;
        }
        if (isChannel) return '📢';
        return icon;
    }

    /// 🎯 Может ли текущий пользователь писать в этот чат?
    bool canWriteChannel({
        required bool canWriteGeneral,
        required bool isAdmin,
    }) {
        if (!isChannel) return false;
        if (isAdmin) return true;
        if (!canWriteGeneral) return false;
        return isMember;
    }

    /// 🎯 Может ли текущий пользователь вступить в канал?
    bool canJoinChannel({
        required bool canWriteGeneral,
        required bool isAdmin,
    }) {
        if (!isChannel) return false;
        if (isMember) return false;
        if (isPrivate) return false;
        return canWriteGeneral || isAdmin;
    }

    // =====================================================
    // 🎨 ИКОНКА ЧАТА
    // =====================================================

    /// Отображаемое имя чата
    String get title {
        if (isPrivateChat && displayName != null && displayName!.isNotEmpty) {
            return displayName!;
        }
        if (name != null && name!.isNotEmpty) return name!;
        if (isGeneral) return 'Общий чат';
        if (isPrivateChat) return 'Личный чат';
        return 'Чат #$id';
    }

    /// Эмодзи-иконка (для не-каналов, если emoji не задано)
    String get icon {
        switch (type) {
            case 'general':
                return '🖼️';
            case 'private':
                return '🤙';
            case 'group':
                return '📢';
            case 'channel':
                return '📢';
            default:
                return '💬';
        }
    }

    /// 🎯 ЭМОДЗИ «Потарахтеть»:
    /// Логотип показываем только для general-чатов БЕЗ emoji.
    /// Если у general-чата задан emoji (например, 🍁) —
    /// вместо логотипа будет эмодзи.
    bool get useLogoImage =>
        type == 'general' && (emoji == null || emoji!.isEmpty);

    // =====================================================
    // 🎯 ЭТАП C.1: TELEGRAM-ФОРМАТ ПРЕВЬЮ
    // =====================================================

    /// 🎯 Превью последнего сообщения с префиксами типа.
    String get lastMessagePreview {
        if (lastMessageText == null || lastMessageText!.isEmpty) {
            return 'Нет сообщений';
        }

        final text = lastMessageText!;

        if (text.startsWith('VOICE:')) {
            return '🎤 Голосовое сообщение';
        }
        if (text.startsWith('FILE:')) {
            return '📎 Файл';
        }
        if (text.startsWith('IMG:') || text.startsWith('/api/files/')) {
            return '🖼 Фото';
        }

        if (text.length > 50) {
            return '${text.substring(0, 50)}...';
        }
        return text;
    }

    // =====================================================
    // 🎯 ЭТАП C.1: TELEGRAM-ФОРМАТ ДАТЫ
    // =====================================================

    /// 🎯 Время последнего сообщения в Telegram-формате:
    ///   • Сегодня      → `14:30`
    ///   • Вчера        → `вчера`
    ///   • Эта неделя   → `Пн`, `Вт`, `Ср`...
    ///   • Этот год     → `12.09`
    ///   • Старше года  → `12.09.24`
    String get lastMessageTime {
        if (lastMessageAt == null) return '';

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final messageDay = DateTime(
            lastMessageAt!.year,
            lastMessageAt!.month,
            lastMessageAt!.day,
        );

        // Сегодня → 14:30
        if (messageDay == today) {
            final hour = lastMessageAt!.hour.toString().padLeft(2, '0');
            final minute = lastMessageAt!.minute.toString().padLeft(2, '0');
            return '$hour:$minute';
        }

        // Вчера → вчера
        if (messageDay == yesterday) {
            return 'вчера';
        }

        // Эта неделя (2-6 дней назад) → Пн, Вт, ...
        final diffDays = today.difference(messageDay).inDays;
        if (diffDays >= 2 && diffDays < 7) {
            const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
            return weekdays[lastMessageAt!.weekday - 1];
        }

        // Этот год → 12.09
        final day = lastMessageAt!.day.toString().padLeft(2, '0');
        final month = lastMessageAt!.month.toString().padLeft(2, '0');

        if (lastMessageAt!.year == now.year) {
            return '$day.$month';
        }

        // Старше года → 12.09.24
        final year = (lastMessageAt!.year % 100).toString().padLeft(2, '0');
        return '$day.$month.$year';
    }

    String get initials {
        final source = displayName ?? name;
        if (source == null || source.isEmpty) return '?';
        final parts = source.trim().split(' ');
        if (parts.length == 1) {
            return parts[0].substring(0, 1).toUpperCase();
        }
        return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
            .toUpperCase();
    }

    // =====================================================
    // 🛠️ СТАТИЧЕСКИЕ МЕТОДЫ
    // =====================================================

    /// 🎯 Парсинг bool: поддерживает bool, int (0/1), String ('true'/'1'/'t').
    static bool _intToBool(dynamic value) {
        if (value == null) return false;
        if (value is bool) return value;
        if (value is int) return value == 1;
        if (value is String) {
            final s = value.toLowerCase().trim();
            return s == 'true' || s == '1' || s == 't';
        }
        return false;
    }

    static DateTime? _parseDate(dynamic value) {
        if (value == null) return null;
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
        return null;
    }

    /// 🎯 Парсинг эмодзи: если null, пусто или '??' — возвращаем null.
    static String? _parseEmoji(dynamic value) {
        if (value == null) return null;
        final str = value.toString().trim();
        if (str.isEmpty) return null;
        if (str == '??' || str == '?') return null;
        return str;
    }

    // =====================================================
    // 🔍 ОТЛАДКА
    // =====================================================

    @override
    String toString() {
        return 'Chat(id: $id, type: $type, title: $title, '
            'members: $membersCount, unread: $unreadCount, '
            'isPrivate: $isPrivate, isMember: $isMember, emoji: $emoji)';
    }

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is Chat &&
            other.id == id &&
            other.lastMessageId == lastMessageId &&
            other.unreadCount == unreadCount &&
            other.isPrivate == isPrivate &&
            other.isMember == isMember &&
            other.emoji == emoji;
    }

    @override
    int get hashCode => Object.hash(
        id, lastMessageId, unreadCount, isPrivate, isMember, emoji,
    );
}

// =====================================================
// 👥 МОДЕЛЬ УЧАСТНИКА ЧАТА
// =====================================================

class ChatMember {
    final int id;
    final String username;
    final String displayName;
    final String? avatar;
    final String status;
    final String role;
    final DateTime? joinedAt;

    const ChatMember({
        required this.id,
        required this.username,
        required this.displayName,
        this.avatar,
        this.status = 'offline',
        this.role = 'member',
        this.joinedAt,
    });

    factory ChatMember.fromJson(Map<String, dynamic> json) {
        return ChatMember(
            id: json['id'] as int? ?? 0,
            username: json['username'] as String? ?? '',
            displayName: json['display_name'] as String? ?? '',
            avatar: json['avatar'] as String?,
            status: json['status'] as String? ?? 'offline',
            role: json['role'] as String? ?? 'member',
            joinedAt: _parseDate(json['joined_at']),
        );
    }

    bool get isOnline => status == 'online';
    bool get isAdmin => role == 'admin';

    String get initials {
        final parts = displayName.trim().split(' ');
        if (parts.isEmpty || parts.first.isEmpty) return '?';
        if (parts.length == 1) {
            return parts.first.substring(0, 1).toUpperCase();
        }
        return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
            .toUpperCase();
    }

    static DateTime? _parseDate(dynamic value) {
        if (value == null) return null;
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
        return null;
    }

    @override
    String toString() =>
        'ChatMember(id: $id, name: $displayName, role: $role)';
}