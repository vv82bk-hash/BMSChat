// =====================================================
// 📝 BMSChat — МОДЕЛЬ СООБЩЕНИЯ
// =====================================================

import 'package:intl/intl.dart';

class Message {
    // =====================================================
    // 📋 ОСНОВНЫЕ ПОЛЯ
    // =====================================================

    final int id;
    final int chatId;
    final int senderId;
    final String? text;
    final int? replyToId;
    final bool isDeleted;
    final bool isEdited;
    final DateTime createdAt;
    final DateTime? updatedAt;

    // Данные отправителя
    final String? senderName;
    final String? senderUsername;
    final String? senderAvatar;

    // Реакции и вложения
    final List<Reaction> reactions;
    final List<Attachment> attachments;

    // =====================================================
    // 🏗️ КОНСТРУКТОР
    // =====================================================

    const Message({
        required this.id,
        required this.chatId,
        required this.senderId,
        this.text,
        this.replyToId,
        this.isDeleted = false,
        this.isEdited = false,
        required this.createdAt,
        this.updatedAt,
        this.senderName,
        this.senderUsername,
        this.senderAvatar,
        this.reactions = const [],
        this.attachments = const [],
    });

    // =====================================================
    // 📥 FROM JSON
    // =====================================================

    factory Message.fromJson(Map<String, dynamic> json) {
        return Message(
            id: json['id'] as int? ?? 0,
            chatId: json['chat_id'] as int? ?? 0,
            senderId: json['sender_id'] as int? ?? 0,
            text: json['text'] as String?,
            replyToId: json['reply_to_id'] as int?,
            isDeleted: _intToBool(json['is_deleted']),
            isEdited: _intToBool(json['is_edited']),
            createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
            updatedAt: _parseDate(json['updated_at']),
            senderName: json['display_name'] as String? ??
                        json['sender_name'] as String?,
            senderUsername: json['username'] as String? ??
                            json['sender_username'] as String?,
            senderAvatar: json['avatar'] as String? ??
                          json['sender_avatar'] as String?,
            reactions: (json['reactions'] as List<dynamic>?)
                ?.map((r) => Reaction.fromJson(r as Map<String, dynamic>))
                .toList() ?? [],
            attachments: (json['attachments'] as List<dynamic>?)
                ?.map((a) => Attachment.fromJson(a as Map<String, dynamic>))
                .toList() ?? [],
        );
    }

    // =====================================================
    // 📤 TO JSON
    // =====================================================

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'chat_id': chatId,
            'sender_id': senderId,
            'text': text,
            'reply_to_id': replyToId,
            'is_deleted': isDeleted ? 1 : 0,
            'is_edited': isEdited ? 1 : 0,
            'created_at': createdAt.toIso8601String(),
            'updated_at': updatedAt?.toIso8601String(),
            'reactions': reactions.map((r) => r.toJson()).toList(),
            'attachments': attachments.map((a) => a.toJson()).toList(),
        };
    }

    // =====================================================
    // 📋 COPY WITH
    // =====================================================

    Message copyWith({
        int? id,
        int? chatId,
        int? senderId,
        String? text,
        int? replyToId,
        bool? isDeleted,
        bool? isEdited,
        DateTime? createdAt,
        DateTime? updatedAt,
        String? senderName,
        String? senderUsername,
        String? senderAvatar,
        List<Reaction>? reactions,
        List<Attachment>? attachments,
    }) {
        return Message(
            id: id ?? this.id,
            chatId: chatId ?? this.chatId,
            senderId: senderId ?? this.senderId,
            text: text ?? this.text,
            replyToId: replyToId ?? this.replyToId,
            isDeleted: isDeleted ?? this.isDeleted,
            isEdited: isEdited ?? this.isEdited,
            createdAt: createdAt ?? this.createdAt,
            updatedAt: updatedAt ?? this.updatedAt,
            senderName: senderName ?? this.senderName,
            senderUsername: senderUsername ?? this.senderUsername,
            senderAvatar: senderAvatar ?? this.senderAvatar,
            reactions: reactions ?? this.reactions,
            attachments: attachments ?? this.attachments,
        );
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ
    // =====================================================

    /// Текст, безопасный для отображения
    String get displayText {
        if (isDeleted) return 'Сообщение удалено';
        return text ?? '';
    }

    // =====================================================
    // 📎 ОПРЕДЕЛЕНИЕ ТИПА ФАЙЛА
    // =====================================================

    /// Путь к файлу в тексте сообщения (если есть)
    String? get filePath {
        if (text == null || text!.isEmpty) return null;
        if (!text!.startsWith('/uploads/')) return null;
        return text!;
    }

    /// Есть ли в сообщении картинка?
    bool get isImageMessage {
        final path = filePath;
        if (path == null) return false;

        final lower = path.toLowerCase();
        return lower.endsWith('.jpg') ||
               lower.endsWith('.jpeg') ||
               lower.endsWith('.png') ||
               lower.endsWith('.gif') ||
               lower.endsWith('.webp');
    }

    /// Есть ли в сообщении голосовое?
    bool get isVoiceMessage {
        final path = filePath;
        if (path == null) return false;

        final lower = path.toLowerCase();
        return lower.endsWith('.mp3') ||
               lower.endsWith('.m4a') ||
               lower.endsWith('.wav') ||
               lower.endsWith('.webm') ||
               lower.endsWith('.ogg') ||
               lower.endsWith('.aac');
    }

    /// Есть ли в сообщении PDF?
    bool get isPdfMessage {
        final path = filePath;
        if (path == null) return false;
        return path.toLowerCase().endsWith('.pdf');
    }

    /// Есть ли в сообщении файл (любой)?
    bool get isFileMessage => filePath != null;

    /// Это текстовое сообщение? (не файл)
    bool get isTextMessage => filePath == null;

    // =====================================================
    // 🛠️ ГЕТТЕРЫ ОТОБРАЖЕНИЯ
    // =====================================================

    /// Время в формате «14:30»
    String get formattedTime {
        return DateFormat('HH:mm').format(createdAt);
    }

    /// Дата в формате «13.09.2026»
    String get formattedDate {
        return DateFormat('dd.MM.yyyy').format(createdAt);
    }

    /// Полная дата и время
    String get formattedDateTime {
        return DateFormat('dd.MM.yyyy HH:mm').format(createdAt);
    }

    /// Есть ли вложения (старый способ)
    bool get hasAttachments => attachments.isNotEmpty;

    /// Есть ли реакции
    bool get hasReactions => reactions.isNotEmpty;

    /// Есть ли текст
    bool get hasText => text != null && text!.trim().isNotEmpty;

    /// Своё ли сообщение
    bool isOwn(int currentUserId) => senderId == currentUserId;

    /// Количество разных эмодзи-реакций
    Map<String, int> get reactionCounts {
        final counts = <String, int>{};
        for (final reaction in reactions) {
            counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
        }
        return counts;
    }

    // =====================================================
    // 🛠️ СТАТИЧЕСКИЕ МЕТОДЫ
    // =====================================================

    static bool _intToBool(dynamic value) {
        if (value == null) return false;
        if (value is bool) return value;
        if (value is int) return value == 1;
        return false;
    }

    static DateTime? _parseDate(dynamic value) {
        if (value == null) return null;
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
        return null;
    }

    // =====================================================
    // 🔍 ОТЛАДКА
    // =====================================================

    @override
    String toString() {
        return 'Message(id: $id, chatId: $chatId, senderId: $senderId, text: ${text?.substring(0, text!.length > 20 ? 20 : text!.length)}...)';
    }

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is Message &&
            other.id == id &&
            other.isDeleted == isDeleted &&
            other.isEdited == isEdited &&
            other.text == text;
    }

    @override
    int get hashCode => Object.hash(id, isDeleted, isEdited, text);
}

// =====================================================
// 😀 МОДЕЛЬ РЕАКЦИИ
// =====================================================

class Reaction {
    final String emoji;
    final int userId;
    final String? displayName;

    const Reaction({
        required this.emoji,
        required this.userId,
        this.displayName,
    });

    factory Reaction.fromJson(Map<String, dynamic> json) {
        return Reaction(
            emoji: json['emoji'] as String? ?? '👍',
            userId: json['user_id'] as int? ?? 0,
            displayName: json['display_name'] as String?,
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'emoji': emoji,
            'user_id': userId,
            'display_name': displayName,
        };
    }

    @override
    String toString() => 'Reaction($emoji by $userId)';

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is Reaction &&
            other.emoji == emoji &&
            other.userId == userId;
    }

    @override
    int get hashCode => Object.hash(emoji, userId);
}

// =====================================================
// 📸 МОДЕЛЬ ВЛОЖЕНИЯ
// =====================================================

class Attachment {
    final int id;
    final String fileType;
    final String filePath;
    final String? fileName;
    final int? fileSize;
    final String? mimeType;
    final int? duration;
    final int? width;
    final int? height;

    const Attachment({
        required this.id,
        required this.fileType,
        required this.filePath,
        this.fileName,
        this.fileSize,
        this.mimeType,
        this.duration,
        this.width,
        this.height,
    });

    factory Attachment.fromJson(Map<String, dynamic> json) {
        return Attachment(
            id: json['id'] as int? ?? 0,
            fileType: json['file_type'] as String? ?? 'file',
            filePath: json['file_path'] as String? ?? '',
            fileName: json['file_name'] as String?,
            fileSize: json['file_size'] as int?,
            mimeType: json['mime_type'] as String?,
            duration: json['duration'] as int?,
            width: json['width'] as int?,
            height: json['height'] as int?,
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'file_type': fileType,
            'file_path': filePath,
            'file_name': fileName,
            'file_size': fileSize,
            'mime_type': mimeType,
            'duration': duration,
            'width': width,
            'height': height,
        };
    }

    bool get isImage => fileType == 'image';
    bool get isVoice => fileType == 'voice';
    bool get isFile => fileType == 'file';

    String get formattedSize {
        if (fileSize == null) return '—';
        if (fileSize! < 1024) return '$fileSize Б';
        if (fileSize! < 1024 * 1024) {
            return '${(fileSize! / 1024).toStringAsFixed(1)} КБ';
        }
        return '${(fileSize! / 1024 / 1024).toStringAsFixed(1)} МБ';
    }

    String get formattedDuration {
        if (duration == null) return '—';
        final minutes = duration! ~/ 60;
        final seconds = duration! % 60;
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    @override
    String toString() => 'Attachment(id: $id, type: $fileType, path: $filePath)';

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is Attachment && other.id == id;
    }

    @override
    int get hashCode => id.hashCode;
}