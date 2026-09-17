// =====================================================
// 💬 BMSChat — ПУЗЫРЬ СООБЩЕНИЯ
// =====================================================

import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/message.dart';
import '../themes/rasta_theme.dart';

class MessageBubble extends StatelessWidget {
    final Message message;
    final bool isOwn;
    final VoidCallback? onLongPress;

    const MessageBubble({
        super.key,
        required this.message,
        required this.isOwn,
        this.onLongPress,
    });

    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onLongPress: onLongPress,
            child: Align(
                alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                    margin: EdgeInsets.only(
                        left: isOwn ? 50 : 10,
                        right: isOwn ? 10 : 50,
                        top: 1.5,
                        bottom: 1.5,
                    ),
                    padding: EdgeInsets.all(message.isImageMessage ? 3 : 10),
                    decoration: BoxDecoration(
                        gradient: isOwn && !message.isImageMessage
                            ? RastaTheme.ownBubbleGradient
                            : null,
                        color: isOwn && message.isImageMessage
                            ? null
                            : (isOwn ? null : RastaTheme.bubbleOther),
                        borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isOwn ? 16 : 4),
                            bottomRight: Radius.circular(isOwn ? 4 : 16),
                        ),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            // Имя отправителя (только для чужих, не для картинок)
                            if (!isOwn &&
                                message.senderName != null &&
                                !message.isImageMessage)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                        message.senderName!,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: RastaTheme.rastaYellow,
                                        ),
                                    ),
                                ),

                            // Ответ на сообщение
                            if (message.replyToId != null)
                                Padding(
                                    padding: EdgeInsets.only(
                                        bottom: 5,
                                        left: message.isImageMessage ? 8 : 0,
                                        right: message.isImageMessage ? 8 : 0,
                                        top: message.isImageMessage ? 5 : 0,
                                    ),
                                    child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            border: const Border(
                                                left: BorderSide(
                                                    color: RastaTheme
                                                        .rastaYellow,
                                                    width: 3,
                                                ),
                                            ),
                                        ),
                                        child: const Text(
                                            'Ответ на сообщение',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                                color: RastaTheme.textMuted,
                                            ),
                                        ),
                                    ),
                                ),

                            // ═══════════════════════════════════════
                            // КОНТЕНТ
                            // ═══════════════════════════════════════
                            if (message.isImageMessage)
                                _buildImage(message)
                            else if (message.isFileMessage)
                                _buildFile(message, isOwn)
                            else
                                _buildText(message, isOwn),

                            // Время + метки
                            Padding(
                                padding: EdgeInsets.only(
                                    top: 3,
                                    left: message.isImageMessage ? 8 : 0,
                                    right: message.isImageMessage ? 8 : 0,
                                    bottom: message.isImageMessage ? 5 : 0,
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        if (message.isEdited)
                                            const Padding(
                                                padding:
                                                    EdgeInsets.only(right: 3),
                                                child: Text(
                                                    'изменено',
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        color: RastaTheme
                                                            .textMuted,
                                                    ),
                                                ),
                                            ),
                                        Text(
                                            message.formattedTime,
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: isOwn &&
                                                        !message.isImageMessage
                                                    ? Colors.black54
                                                    : RastaTheme.textMuted,
                                            ),
                                        ),
                                    ],
                                ),
                            ),

                            // Реакции
                            if (message.hasReactions)
                                Padding(
                                    padding: EdgeInsets.only(
                                        top: 3,
                                        left: message.isImageMessage ? 8 : 0,
                                        right: message.isImageMessage ? 8 : 0,
                                        bottom: message.isImageMessage ? 5 : 0,
                                    ),
                                    child: Wrap(
                                        spacing: 3,
                                        runSpacing: 2,
                                        children: message.reactionCounts.entries
                                            .map((entry) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                ),
                                                child: Text(
                                                    '${entry.key} ${entry.value}',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                    ),
                                                ),
                                            ))
                                            .toList(),
                                    ),
                                ),
                        ],
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 📷 КАРТИНКА
    // =====================================================
    Widget _buildImage(Message message) {
        final url = Constants.getFullFileUrl(message.filePath!);

        return ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.network(
                url,
                width: 220,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;

                    return Container(
                        width: 220,
                        height: 180,
                        color: RastaTheme.surfaceSecondary,
                        child: Center(
                            child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                    RastaTheme.rastaYellow,
                                ),
                            ),
                        ),
                    );
                },
                errorBuilder: (context, error, stackTrace) {
                    return Container(
                        width: 220,
                        height: 140,
                        decoration: BoxDecoration(
                            color: RastaTheme.surfaceSecondary,
                            borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(
                                        Icons.broken_image_outlined,
                                        size: 36,
                                        color: RastaTheme.textMuted,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                        'Не удалось загрузить',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: RastaTheme.textMuted,
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    );
                },
            ),
        );
    }

    // =====================================================
    // 📄 ФАЙЛ
    // =====================================================
    Widget _buildFile(Message message, bool isOwn) {
        final path = message.filePath!;
        final fileName = path.split('/').last;

        return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                Icon(
                    Icons.insert_drive_file_outlined,
                    color: isOwn ? Colors.black54 : RastaTheme.rastaYellow,
                    size: 28,
                ),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(
                        fileName,
                        style: TextStyle(
                            fontSize: 13,
                            color: isOwn
                                ? RastaTheme.bubbleOwnText
                                : RastaTheme.bubbleOtherText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                    ),
                ),
            ],
        );
    }

    // =====================================================
    // 📝 ТЕКСТ
    // =====================================================
    Widget _buildText(Message message, bool isOwn) {
        return Text(
            message.displayText,
            style: TextStyle(
                fontSize: 15,
                color: isOwn
                    ? RastaTheme.bubbleOwnText
                    : RastaTheme.bubbleOtherText,
                fontStyle:
                    message.isDeleted ? FontStyle.italic : FontStyle.normal,
                height: 1.25,
            ),
        );
    }
}