// =====================================================
// 💬 BMSChat — ПУЗЫРЬ СООБЩЕНИЯ (С ПРОПОРЦИЯМИ)
// =====================================================

import 'dart:ui' as ui;

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
                        left: isOwn ? 50 : 12,
                        right: isOwn ? 12 : 50,
                        top: 2,
                        bottom: 2,
                    ),
                    padding: EdgeInsets.all(message.isImageMessage ? 4 : 12),
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
                            bottomLeft: Radius.circular(isOwn ? 18 : 6),
                            bottomRight: Radius.circular(isOwn ? 6 : 18),
                        ),
                        boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                            ),
                        ],
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            if (!isOwn &&
                                message.senderName != null &&
                                !message.isImageMessage)
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

                            if (message.replyToId != null)
                                Padding(
                                    padding: EdgeInsets.only(
                                        bottom: 6,
                                        left: message.isImageMessage ? 8 : 0,
                                        right: message.isImageMessage ? 8 : 0,
                                        top: message.isImageMessage ? 6 : 0,
                                    ),
                                    child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: RastaTheme.textMuted,
                                            ),
                                        ),
                                    ),
                                ),

                            if (message.isImageMessage)
                                _buildImage(message)
                            else if (message.isFileMessage)
                                _buildFile(message, isOwn)
                            else
                                _buildText(message, isOwn),

                            // Время + галочки + метки
                            Padding(
                                padding: EdgeInsets.only(
                                    top: 6,
                                    left: message.isImageMessage ? 8 : 0,
                                    right: message.isImageMessage ? 8 : 0,
                                    bottom: message.isImageMessage ? 6 : 0,
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        if (message.isEdited)
                                            const Padding(
                                                padding:
                                                    EdgeInsets.only(right: 4),
                                                child: Text(
                                                    'изменено',
                                                    style: TextStyle(
                                                        fontSize: 10,
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
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: isOwn &&
                                                        !message.isImageMessage
                                                    ? Colors.black87
                                                    : RastaTheme.textMuted,
                                            ),
                                        ),

                                        // 🎯 ГАЛОЧКИ — только для своих
                                        if (isOwn) ...[
                                            const SizedBox(width: 8),
                                            _buildReadIcon(
                                                isImage: message.isImageMessage,
                                            ),
                                        ],
                                    ],
                                ),
                            ),

                            if (message.hasReactions)
                                Padding(
                                    padding: EdgeInsets.only(
                                        top: 4,
                                        left: message.isImageMessage ? 8 : 0,
                                        right: message.isImageMessage ? 8 : 0,
                                        bottom: message.isImageMessage ? 6 : 0,
                                    ),
                                    child: Wrap(
                                        spacing: 4,
                                        runSpacing: 3,
                                        children: message.reactionCounts.entries
                                            .map((entry) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                        color: RastaTheme
                                                            .rastaYellow
                                                            .withValues(alpha: 0.3),
                                                        width: 0.5,
                                                    ),
                                                ),
                                                child: Text(
                                                    '${entry.key} ${entry.value}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
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
    // 🎯 ГАЛОЧКА ПРОЧТЕНИЯ
    // =====================================================
    //   ✓  — отправлено (серое)
    //   ✓✓ — прочитано (ЯРКО-ЗЕЛЁНОЕ)
    // =====================================================
    Widget _buildReadIcon({required bool isImage}) {
        final Color color;
        if (isImage) {
            color = Colors.white;
        } else {
            // 🎯 ЯРКО-ЗЕЛЁНЫЙ для прочитанных
            color = message.isRead
                ? const Color(0xFF00E676)   // Material Green A400
                : Colors.black45;            // отправлено — серое
        }

        return Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 18,
            color: color,
        );
    }

    // =====================================================
    // 📷 КАРТИНКА (АВТО-ПРОПОРЦИИ)
    // =====================================================
    Widget _buildImage(Message message) {
        final url = Constants.getFullFileUrl(message.filePath!);

        return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _ProportionalImage(
                url: url,
                maxWidth: 280,
                maxHeight: 400,
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
                    size: 32,
                ),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(
                        fileName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w400,
                color: isOwn
                    ? RastaTheme.bubbleOwnText
                    : RastaTheme.bubbleOtherText,
                fontStyle:
                    message.isDeleted ? FontStyle.italic : FontStyle.normal,
                height: 1.3,
            ),
        );
    }
}

// =====================================================
// 📷 ПРОПОРЦИОНАЛЬНАЯ КАРТИНКА
// =====================================================

class _ProportionalImage extends StatefulWidget {
    final String url;
    final double maxWidth;
    final double maxHeight;

    const _ProportionalImage({
        required this.url,
        this.maxWidth = 280,
        this.maxHeight = 400,
    });

    @override
    State<_ProportionalImage> createState() => _ProportionalImageState();
}

class _ProportionalImageState extends State<_ProportionalImage> {
    double? _displayWidth;
    double? _displayHeight;
    bool _hasError = false;

    @override
    void initState() {
        super.initState();
        _resolveImage();
    }

    @override
    void didUpdateWidget(_ProportionalImage oldWidget) {
        super.didUpdateWidget(oldWidget);
        if (oldWidget.url != widget.url) {
            _displayWidth = null;
            _displayHeight = null;
            _hasError = false;
            _resolveImage();
        }
    }

    void _resolveImage() {
        final ImageProvider provider = NetworkImage(widget.url);
        final ImageStream stream = provider.resolve(ImageConfiguration.empty);

        final ImageStreamListener listener = ImageStreamListener(
            (ImageInfo info, bool synchronousCall) {
                if (!mounted) return;

                final ui.Image image = info.image;
                final imageWidth = image.width.toDouble();
                final imageHeight = image.height.toDouble();

                if (imageWidth <= 0 || imageHeight <= 0) {
                    setState(() => _hasError = true);
                    return;
                }

                final aspectRatio = imageWidth / imageHeight;

                double width = imageWidth > widget.maxWidth
                    ? widget.maxWidth
                    : imageWidth;

                double height = width / aspectRatio;

                if (height > widget.maxHeight) {
                    height = widget.maxHeight;
                    width = height * aspectRatio;
                }

                setState(() {
                    _displayWidth = width;
                    _displayHeight = height;
                });
            },
            onError: (exception, stackTrace) {
                if (!mounted) return;
                setState(() => _hasError = true);
            },
        );

        stream.addListener(listener);
    }

    @override
    Widget build(BuildContext context) {
        if (_hasError) {
            return _buildError();
        }

        if (_displayWidth == null || _displayHeight == null) {
            return _buildLoading();
        }

        return Image.network(
            widget.url,
            width: _displayWidth,
            height: _displayHeight,
            fit: BoxFit.contain,
            cacheWidth: (_displayWidth! * 2).toInt(),
            errorBuilder: (context, error, stackTrace) => _buildError(),
            loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _buildLoading();
            },
        );
    }

    Widget _buildLoading() {
        return Container(
            width: widget.maxWidth,
            height: 200,
            decoration: BoxDecoration(
                color: RastaTheme.surfaceSecondary,
                borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        RastaTheme.rastaYellow,
                    ),
                ),
            ),
        );
    }

    Widget _buildError() {
        return Container(
            width: widget.maxWidth,
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
    }
}