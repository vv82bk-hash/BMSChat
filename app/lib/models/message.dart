// =====================================================
// 📝 BMSChat — МОДЕЛЬ СООБЩЕНИЯ
// =====================================================
// 🎯 ЭТАП B.3: геттер displayPreview — превью для цитаты.
// 🎯 ДОКУМЕНТЫ: парсинг метаданных из FILE:.
// 🎯 ПОЛЛЫ: поддержка сообщений типа POLL:<id>.
//   В объект Message встроено поле poll (Poll?).
// =====================================================

import 'package:intl/intl.dart';
import 'poll.dart';

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

    /// 🎯 Прочитано ли получателем?
    final bool isRead;

    // Данные отправителя
    final String? senderName;
    final String? senderUsername;
    final String? senderAvatar;

    // Реакции и вложения
    final List<Reaction> reactions;
    final List<Attachment> attachments;

    // 🎯 ПОЛЛ: встроенный объект голосования (если тип POLL:)
    final Poll? poll;

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
        this.isRead = false,
        this.senderName,
        this.senderUsername,
        this.senderAvatar,
        this.reactions = const [],
        this.attachments = const [],
        this.poll,
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
            isRead: _intToBool(json['is_read']),
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
            poll: json['poll'] != null
                ? Poll.fromJson(json['poll'] as Map<String, dynamic>)
                : null,
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
            'is_read': isRead ? 1 : 0,
            'reactions': reactions.map((r) => r.toJson()).toList(),
            'attachments': attachments.map((a) => a.toJson()).toList(),
            if (poll != null) 'poll': poll!.toJson(),
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
        bool? isRead,
        String? senderName,
        String? senderUsername,
        String? senderAvatar,
        List<Reaction>? reactions,
        List<Attachment>? attachments,
        Poll? poll,
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
            isRead: isRead ?? this.isRead,
            senderName: senderName ?? this.senderName,
            senderUsername: senderUsername ?? this.senderUsername,
            senderAvatar: senderAvatar ?? this.senderAvatar,
            reactions: reactions ?? this.reactions,
            attachments: attachments ?? this.attachments,
            poll: poll ?? this.poll,
        );
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ
    // =====================================================

    /// Текст, безопасный для отображения
    String get displayText {
        if (isDeleted) return 'Сообщение удалено';
        if (isFileMessage) return '';
        if (isPollMessage) return '';
        return text ?? '';
    }

    /// 🎯 Превью для цитаты в reply.
    String get displayPreview {
        if (isDeleted) return 'Сообщение удалено';
        if (isImageMessage) return '🖼 Фото';
        if (isVoiceMessage) return '🎤 Голосовое';
        if (isPollMessage) {
            final q = poll?.question;
            return q != null ? '📊 $q' : '📊 Голосование';
        }
        if (isFileMessage) {
            final name = fileDisplayName;
            return name != null ? '📎 $name' : '📎 Файл';
        }
        return displayText;
    }

    // =====================================================
    // 📎 ОПРЕДЕЛЕНИЕ ТИПА ФАЙЛА
    // =====================================================

    String? get _filePrefix {
        if (text == null || text!.isEmpty) return null;
        if (text!.startsWith('IMG:')) return 'IMG:';
        if (text!.startsWith('VOICE:')) return 'VOICE:';
        if (text!.startsWith('FILE:')) return 'FILE:';
        return null;
    }

    /// 🎯 Путь к файлу (для IMG/VOICE/FILE).
    /// POLL: не является файлом — возвращает null.
    String? get filePath {
        if (text == null || text!.isEmpty) return null;

        final prefix = _filePrefix;
        if (prefix == 'IMG:' || prefix == 'VOICE:') {
            return text!.substring(prefix!.length);
        }
        if (prefix == 'FILE:') {
            final raw = text!.substring('FILE:'.length);
            final pipeIdx = raw.indexOf('|');
            return pipeIdx >= 0 ? raw.substring(0, pipeIdx) : raw;
        }

        if (text!.startsWith('/uploads/') ||
            text!.startsWith('/api/files/')) {
            return text!;
        }

        return null;
    }

    // =====================================================
    // 📊 ПОЛЛ
    // =====================================================

    /// 🎯 Это сообщение-голосование?
    /// Считается поллом, если текст начинается с "POLL:".
    bool get isPollMessage {
        if (text == null || text!.isEmpty) return false;
        return text!.startsWith('POLL:');
    }

    /// 🎯 ID полла, извлечённый из текста "POLL:<id>".
    /// Возвращает null, если это не полл.
    int? get pollId {
        if (!isPollMessage) return null;
        final raw = text!.substring('POLL:'.length).trim();
        return int.tryParse(raw);
    }

    // =====================================================
    // 📄 МЕТАДАННЫЕ ФАЙЛА
    // =====================================================

    Map<String, dynamic> get _fileMetadata {
        if (_filePrefix != 'FILE:') return const {};

        final raw = text!.substring('FILE:'.length);
        final parts = raw.split('|');

        String? name;
        int? size;

        for (int i = 1; i < parts.length; i++) {
            final part = parts[i];
            final eq = part.indexOf('=');
            if (eq <= 0) continue;

            final key = part.substring(0, eq);
            final value = part.substring(eq + 1);

            if (key == 'name' && value.isNotEmpty) {
                try {
                    name = Uri.decodeComponent(value);
                } catch (_) {
                    name = value;
                }
            } else if (key == 'size') {
                size = int.tryParse(value);
            }
        }

        return {'name': name, 'size': size};
    }

    String? get fileDisplayName {
        if (!isFileMessage) return null;
        if (_filePrefix == 'FILE:') {
            final name = _fileMetadata['name'] as String?;
            if (name != null && name.isNotEmpty) return name;
        }
        final path = filePath;
        if (path == null || path.isEmpty) return null;
        final segments = path.split('/');
        return segments.isNotEmpty ? segments.last : null;
    }

    int? get fileSize {
        if (!isFileMessage) return null;
        if (_filePrefix == 'FILE:') {
            return _fileMetadata['size'] as int?;
        }
        return null;
    }

    String? get fileExtension {
        final name = fileDisplayName;
        if (name == null) return null;
        final dot = name.lastIndexOf('.');
        if (dot <= 0 || dot == name.length - 1) return null;
        return name.substring(dot).toLowerCase();
    }

    String? get formattedFileSize {
        final size = fileSize;
        if (size == null) return null;

        if (size < 1024) return '$size Б';
        if (size < 1024 * 1024) {
            return '${(size / 1024).toStringAsFixed(1)} КБ';
        }
        return '${(size / 1024 / 1024).toStringAsFixed(1)} МБ';
    }

    // =====================================================
    // 🖼 ТИПЫ СООБЩЕНИЙ
    // =====================================================

    bool get isImageMessage {
        if (_filePrefix == 'IMG:') return true;

        final path = filePath;
        if (path == null) return false;

        final lower = path.toLowerCase();
        return lower.endsWith('.jpg') ||
               lower.endsWith('.jpeg') ||
               lower.endsWith('.png') ||
               lower.endsWith('.gif') ||
               lower.endsWith('.webp');
    }

    bool get isVoiceMessage {
        if (_filePrefix == 'VOICE:') return true;

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

    bool get isPdfMessage {
        final path = filePath;
        if (path == null) return false;
        return path.toLowerCase().endsWith('.pdf');
    }

    bool get isFileMessage => filePath != null;
    bool get isTextMessage => filePath == null && !isPollMessage;

    bool get isApkMessage => fileExtension == '.apk';

    bool get isArchiveMessage {
        final ext = fileExtension;
        return ext == '.zip' || ext == '.rar' || ext == '.7z';
    }

    bool get isDocMessage {
        final ext = fileExtension;
        return ext == '.pdf' ||
               ext == '.doc' ||
               ext == '.docx' ||
               ext == '.xls' ||
               ext == '.xlsx' ||
               ext == '.ppt' ||
               ext == '.pptx' ||
               ext == '.txt' ||
               ext == '.csv';
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ ОТОБРАЖЕНИЯ
    // =====================================================

    String get formattedTime => DateFormat('HH:mm').format(createdAt);
    String get formattedDate => DateFormat('dd.MM.yyyy').format(createdAt);
    String get formattedDateTime =>
        DateFormat('dd.MM.yyyy HH:mm').format(createdAt);

    bool get hasAttachments => attachments.isNotEmpty;
    bool get hasReactions => reactions.isNotEmpty;
    bool get hasText => text != null && text!.trim().isNotEmpty;

    bool isOwn(int currentUserId) => senderId == currentUserId;

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

    @override
    String toString() {
        return 'Message(id: $id, chatId: $chatId, senderId: $senderId, '
            'isRead: $isRead, isPoll: $isPollMessage)';
    }

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is Message &&
            other.id == id &&
            other.isDeleted == isDeleted &&
            other.isEdited == isEdited &&
            other.text == text &&
            other.isRead == isRead;
    }

    @override
    int get hashCode => Object.hash(id, isDeleted, isEdited, text, isRead);
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