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
                        left: isOwn ? 60 : 12,
                        right: isOwn ? 12 : 60,
                        top: 2,
                        bottom: 2,
                    ),
                    padding: EdgeInsets.all(message.isImageMessage ? 4 : 14),
                    decoration: BoxDecoration(
                        gradient: isOwn && !message.isImageMessage
                            ? RastaTheme.ownBubbleGradient
                            : null,
                        color: isOwn && message.isImageMessage
                            ? null
                            : (isOwn ? null : RastaTheme.bubbleOther),
                        borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isOwn ? 18 : 4),
                            bottomRight: Radius.circular(isOwn ? 4 : 18),
                        ),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            // Имя отправителя (только для чужих, не для картинок)
                            if (!isOwn && message.senderName != null && !message.isImageMessage)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                        message.senderName!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: RastaTheme.rastaYellow,
                                        ),
                                    ),
                                ),

                            // Ответ на сообщение
                            if (message.replyToId != null)
                                Padding(
                                    padding: EdgeInsets.only(
                                        bottom: 6,
                                        left: message.isImageMessage ? 10 : 0,
                                        right: message.isImageMessage ? 10 : 0,
                                        top: message.isImageMessage ? 6 : 0,
                                    ),
                                    child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: const Border(
                                                left: BorderSide(
                                                    color: RastaTheme.rastaYellow,
                                                    width: 3,
                                                ),
                                            ),
                                        ),
                                        child: const Text(
                                            'Ответ на сообщение',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: RastaTheme.textMuted,
                                            ),
                                        ),
                                    ),
                                ),

                            // ═══════════════════════════════════════
                            // КОНТЕНТ: картинка / файл / текст
                            // ═══════════════════════════════════════
                            if (message.isImageMessage)
                                _buildImage(message)
                            else if (message.isFileMessage)
                                _buildFile(message, isOwn)
                            else
                                _buildText(message, isOwn),

                            // Время + метки (для картинок — под ними)
                            Padding(
                                padding: EdgeInsets.only(
                                    top: 4,
                                    left: message.isImageMessage ? 10 : 0,
                                    right: message.isImageMessage ? 10 : 0,
                                    bottom: message.isImageMessage ? 6 : 0,
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        if (message.isEdited)
                                            const Padding(
                                                padding: EdgeInsets.only(right: 4),
                                                child: Text(
                                                    'изменено',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontStyle: FontStyle.italic,
                                                        color: RastaTheme.textMuted,
                                                    ),
                                                ),
                                            ),
                                        Text(
                                            message.formattedTime,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: isOwn && !message.isImageMessage
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
                                        top: 4,
                                        left: message.isImageMessage ? 10 : 0,
                                        right: message.isImageMessage ? 10 : 0,
                                        bottom: message.isImageMessage ? 6 : 0,
                                    ),
                                    child: Wrap(
                                        spacing: 4,
                                        children: message.reactionCounts.entries
                                            .map((entry) => Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                    '${entry.key} ${entry.value}',
                                                    style: const TextStyle(fontSize: 12),
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
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
                url,
                width: 250,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;

                    return Container(
                        width: 250,
                        height: 200,
                        color: RastaTheme.surfaceSecondary,
                        child: Center(
                            child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    RastaTheme.rastaYellow,
                                ),
                            ),
                        ),
                    );
                },
                errorBuilder: (context, error, stackTrace) {
                    return Container(
                        width: 250,
                        height: 150,
                        decoration: BoxDecoration(
                            color: RastaTheme.surfaceSecondary,
                            borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                        color: RastaTheme.textMuted,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                        'Не удалось загрузить',
                                        style: TextStyle(
                                            fontSize: 12,
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
    // 📄 ФАЙЛ (не картинка)
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
                    size: 32,
                ),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(
                        fileName,
                        style: TextStyle(
                            fontSize: 14,
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
                fontSize: 16,
                color: isOwn
                    ? RastaTheme.bubbleOwnText
                    : RastaTheme.bubbleOtherText,
                fontStyle: message.isDeleted
                    ? FontStyle.italic
                    : FontStyle.normal,
            ),
        );
    }
}