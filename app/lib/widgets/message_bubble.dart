// =====================================================
// 💬 BMSChat — ПУЗЫРЬ СООБЩЕНИЯ
// =====================================================
// 🎯 ЭТАП B.3:
//   • Свайп влево → onReply (ответ на сообщение)
//   • Параметр replyTo — рендер цитаты (имя + текст)
//   • Тап на цитату → onReplyTap (скролл к оригиналу)
// 🎯 ЭТАП D.1: CachedNetworkImage для картинок-вложений
// 🎯 ЭТАП D.2: RepaintBoundary для изоляции перерисовки
// 🎯 ГОЛОСОВЫЕ: плеер с Play/Pause, таймер, простая волна
// 🎯 ПРОСМОТР ФОТО: InstaImageViewer (зум + свайп вниз)
// 🎯 ПРОФИЛЬ: тап по имени отправителя → onSenderTap
// 🎯 АВАТАР: мини-аватар рядом с именем отправителя
// 🎯 ДОКУМЕНТЫ: карточка файла с иконкой по типу,
//   именем, размером и открытием через FileDownloader
// 🎯 ПОЛЛЫ: карточка голосования через PollMessageWidget
// =====================================================

import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:just_audio/just_audio.dart';

import '../config/constants.dart';
import '../models/message.dart';
import '../services/file_downloader.dart';
import '../themes/rasta_theme.dart';
import 'poll_message_widget.dart';

class MessageBubble extends StatelessWidget {
    final Message message;
    final bool isOwn;
    final VoidCallback? onLongPress;

    // 🎯 ЭТАП B.3: reply-цитата
    final Message? replyTo;
    final VoidCallback? onReply;
    final VoidCallback? onReplyTap;

    // 🎯 ПРОФИЛЬ: тап по имени отправителя
    final VoidCallback? onSenderTap;

    const MessageBubble({
        super.key,
        required this.message,
        required this.isOwn,
        this.onLongPress,
        this.replyTo,
        this.onReply,
        this.onReplyTap,
        this.onSenderTap,
    });

    @override
    Widget build(BuildContext context) {
        // 🎯 ЭТАП D.2: изолируем перерисовку каждого пузыря.
        return RepaintBoundary(
            child: Dismissible(
                key: ValueKey('msg_${message.id}'),
                direction: DismissDirection.endToStart,
                background: _buildSwipeBackground(),
                confirmDismiss: (direction) async {
                    onReply?.call();
                    return false;
                },
                child: GestureDetector(
                    onLongPress: onLongPress,
                    child: Align(
                        alignment: isOwn
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                            margin: EdgeInsets.only(
                                left: isOwn ? 50 : 12,
                                right: isOwn ? 12 : 50,
                                top: 2,
                                bottom: 2,
                            ),
                            padding: EdgeInsets.all(
                                message.isImageMessage ? 4 : 12,
                            ),
                            decoration: BoxDecoration(
                                gradient: isOwn && !message.isImageMessage
                                    ? RastaTheme.ownBubbleGradient
                                    : null,
                                color: isOwn && message.isImageMessage
                                    ? null
                                    : (isOwn
                                        ? null
                                        : RastaTheme.bubbleOther),
                                borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft:
                                        Radius.circular(isOwn ? 18 : 6),
                                    bottomRight:
                                        Radius.circular(isOwn ? 6 : 18),
                                ),
                                boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                    ),
                                ],
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    // 🎯 АВАТАР + ИМЯ
                                    if (!isOwn &&
                                        message.senderName != null &&
                                        !message.isImageMessage)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 4,
                                            ),
                                            child: GestureDetector(
                                                onTap: onSenderTap,
                                                child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                        _buildSenderAvatar(),
                                                        const SizedBox(
                                                            width: 6,
                                                        ),
                                                        Text(
                                                            message.senderName!,
                                                            style:
                                                                const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: RastaTheme
                                                                    .rastaYellow,
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ),

                                    // 🎯 ЭТАП B.3: цитата с текстом
                                    if (message.replyToId != null)
                                        Padding(
                                            padding: EdgeInsets.only(
                                                bottom: 6,
                                                left: message.isImageMessage
                                                    ? 8
                                                    : 0,
                                                right: message.isImageMessage
                                                    ? 8
                                                    : 0,
                                                top: message.isImageMessage
                                                    ? 6
                                                    : 0,
                                            ),
                                            child: _buildReplyQuote(),
                                        ),

                                    // 🎯 РЕНДЕР ТЕЛА СООБЩЕНИЯ
                                    if (message.isImageMessage)
                                        _buildImage(message)
                                    else if (message.isVoiceMessage)
                                        _buildVoice(message, isOwn)
                                    else if (message.isFileMessage)
                                        _buildFile(message, isOwn)
                                    else if (message.isPollMessage)
                                        _buildPoll(message)
                                    else
                                        _buildText(message, isOwn),

                                    // Время + галочки + метки
                                    Padding(
                                        padding: EdgeInsets.only(
                                            top: 6,
                                            left: message.isImageMessage
                                                ? 8
                                                : 0,
                                            right: message.isImageMessage
                                                ? 8
                                                : 0,
                                            bottom: message.isImageMessage
                                                ? 6
                                                : 0,
                                        ),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                if (message.isEdited)
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                            right: 4,
                                                        ),
                                                        child: Text(
                                                            'изменено',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                                color: RastaTheme
                                                                    .textMuted,
                                                            ),
                                                        ),
                                                    ),
                                                Text(
                                                    message.formattedTime,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isOwn &&
                                                                !message
                                                                    .isImageMessage
                                                            ? Colors.black87
                                                            : RastaTheme
                                                                .textMuted,
                                                    ),
                                                ),

                                                if (isOwn) ...[
                                                    const SizedBox(width: 8),
                                                    _buildReadIcon(
                                                        isImage: message
                                                            .isImageMessage,
                                                    ),
                                                ],
                                            ],
                                        ),
                                    ),

                                    if (message.hasReactions)
                                        Padding(
                                            padding: EdgeInsets.only(
                                                top: 4,
                                                left: message.isImageMessage
                                                    ? 8
                                                    : 0,
                                                right: message.isImageMessage
                                                    ? 8
                                                    : 0,
                                                bottom: message.isImageMessage
                                                    ? 6
                                                    : 0,
                                            ),
                                            child: Wrap(
                                                spacing: 4,
                                                runSpacing: 3,
                                                children: message
                                                    .reactionCounts.entries
                                                    .map(
                                                        (entry) => Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                horizontal: 7,
                                                                vertical: 3,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.2),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                                border: Border.all(
                                                                    color: RastaTheme
                                                                        .rastaYellow
                                                                        .withValues(
                                                                            alpha:
                                                                                0.3),
                                                                    width: 0.5,
                                                                ),
                                                            ),
                                                            child: Text(
                                                                '${entry.key} ${entry.value}',
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                ),
                                                            ),
                                                        ),
                                                    )
                                                    .toList(),
                                            ),
                                        ),
                                ],
                            ),
                        ),
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 👤 МИНИ-АВАТАР ОТПРАВИТЕЛЯ
    // =====================================================
    Widget _buildSenderAvatar() {
        final hasAvatar =
            message.senderAvatar != null && message.senderAvatar!.isNotEmpty;
        final avatarUrl = hasAvatar
            ? Constants.getFullFileUrl(message.senderAvatar)
            : null;

        // Инициал из имени отправителя (первая буква)
        final initial = (message.senderName ?? '?')
            .trim()
            .substring(0, 1)
            .toUpperCase();

        return Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                        RastaTheme.rastaRed,
                        RastaTheme.rastaYellow,
                    ],
                ),
            ),
            child: ClipOval(
                child: hasAvatar
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildAvatarFallback(
                            initial,
                        ),
                        errorWidget: (context, url, error) =>
                            _buildAvatarFallback(initial),
                    )
                    : _buildAvatarFallback(initial),
            ),
        );
    }

    Widget _buildAvatarFallback(String initial) {
        return Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                        RastaTheme.rastaRed,
                        RastaTheme.rastaYellow,
                    ],
                ),
            ),
            child: Center(
                child: Text(
                    initial,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 🎯 ЭТАП B.3: ФОН СВАЙПА
    // =====================================================
    Widget _buildSwipeBackground() {
        return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RastaTheme.rastaYellow.withValues(alpha: 0.2),
                    border: Border.all(
                        color: RastaTheme.rastaYellow.withValues(alpha: 0.5),
                        width: 1.5,
                    ),
                ),
                child: const Center(
                    child: Icon(
                        Icons.reply,
                        color: RastaTheme.rastaYellow,
                        size: 22,
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 🎯 ЭТАП B.3: ЦИТАТА (reply)
    // =====================================================
    Widget _buildReplyQuote() {
        final quote = replyTo;
        final author = quote?.senderName ?? 'Сообщение';
        final preview = quote?.displayPreview ?? 'Сообщение недоступно';

        return GestureDetector(
            onTap: onReplyTap,
            child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                ),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: const Border(
                        left: BorderSide(
                            color: RastaTheme.rastaYellow,
                            width: 3,
                        ),
                    ),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Text(
                            author,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: RastaTheme.rastaYellow,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                            preview,
                            style: TextStyle(
                                fontSize: 12,
                                color: RastaTheme.textMuted
                                    .withValues(alpha: 0.95),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                        ),
                    ],
                ),
            ),
        );
    }

    // =====================================================
    // 🎯 ГАЛОЧКА ПРОЧТЕНИЯ
    // =====================================================
    Widget _buildReadIcon({required bool isImage}) {
        final Color color;
        if (isImage) {
            color = Colors.white;
        } else {
            color = message.isRead
                ? const Color(0xFF00E676)
                : Colors.black45;
        }

        return Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 18,
            color: color,
        );
    }

    // =====================================================
    // 📷 КАРТИНКА
    // =====================================================
    Widget _buildImage(Message message) {
        final url = Constants.getFullFileUrl(message.filePath!);

        return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: InstaImageViewer(
                child: _ProportionalImage(
                    url: url,
                    maxWidth: 280,
                    maxHeight: 400,
                ),
            ),
        );
    }

    // =====================================================
    // 🎤 ГОЛОСОВОЕ
    // =====================================================
    Widget _buildVoice(Message message, bool isOwn) {
        final url = Constants.getFullFileUrl(message.filePath!);

        return _VoiceMessageWidget(
            url: url,
            isOwn: isOwn,
        );
    }

    // =====================================================
    // 📄 ФАЙЛ
    // =====================================================
    Widget _buildFile(Message message, bool isOwn) {
        return _FileMessageWidget(
            filePath: message.filePath!,
            displayName: message.fileDisplayName,
            extension: message.fileExtension,
            formattedSize: message.formattedFileSize,
            isOwn: isOwn,
        );
    }

    // =====================================================
    // 📊 ПОЛЛ
    // =====================================================
    Widget _buildPoll(Message message) {
        final poll = message.poll;

        if (poll == null) {
            return Text(
                '📊 Голосование',
                style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: isOwn
                        ? RastaTheme.bubbleOwnText.withValues(alpha: 0.7)
                        : RastaTheme.bubbleOtherText.withValues(alpha: 0.7),
                ),
            );
        }

        return PollMessageWidget(
            poll: poll,
            isOwn: isOwn,
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
// 📄 ВИДЖЕТ ФАЙЛОВОГО СООБЩЕНИЯ
// =====================================================

class _FileMessageWidget extends StatefulWidget {
    final String filePath;
    final String? displayName;
    final String? extension;
    final String? formattedSize;
    final bool isOwn;

    const _FileMessageWidget({
        required this.filePath,
        required this.displayName,
        required this.extension,
        required this.formattedSize,
        required this.isOwn,
    });

    @override
    State<_FileMessageWidget> createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends State<_FileMessageWidget> {
    bool _isOpening = false;

    IconData _fileIcon(String? ext) {
        switch (ext) {
            case '.pdf':
                return Icons.picture_as_pdf_outlined;
            case '.doc':
            case '.docx':
                return Icons.description_outlined;
            case '.xls':
            case '.xlsx':
                return Icons.table_chart_outlined;
            case '.ppt':
            case '.pptx':
                return Icons.slideshow_outlined;
            case '.txt':
            case '.csv':
                return Icons.text_snippet_outlined;
            case '.zip':
            case '.rar':
            case '.7z':
                return Icons.folder_zip_outlined;
            case '.apk':
                return Icons.android;
            default:
                return Icons.insert_drive_file_outlined;
        }
    }

    Color _fileColor(String? ext) {
        switch (ext) {
            case '.pdf':
                return const Color(0xFFE53935);
            case '.doc':
            case '.docx':
                return const Color(0xFF1E88E5);
            case '.xls':
            case '.xlsx':
                return const Color(0xFF43A047);
            case '.ppt':
            case '.pptx':
                return const Color(0xFFFB8C00);
            case '.txt':
            case '.csv':
                return const Color(0xFF757575);
            case '.zip':
            case '.rar':
            case '.7z':
                return const Color(0xFFFB8C00);
            case '.apk':
                return const Color(0xFF43A047);
            default:
                return RastaTheme.rastaYellow;
        }
    }

    Future<void> _open() async {
        if (_isOpening) return;

        setState(() => _isOpening = true);

        try {
            final result = await FileDownloader.open(
                filePath: widget.filePath,
                displayName: widget.displayName,
            );

            if (!mounted) return;

            switch (result.status) {
                case FileOpenStatus.success:
                    break;

                case FileOpenStatus.noApp:
                    _showInfo(
                        result.message ??
                            'Нет приложения для открытия этого файла',
                    );
                    break;

                case FileOpenStatus.error:
                    _showError(result.message ?? 'Не удалось открыть файл');
                    break;
            }
        } catch (e) {
            if (!mounted) return;
            _showError('Ошибка открытия: $e');
        } finally {
            if (mounted) {
                setState(() => _isOpening = false);
            }
        }
    }

    void _showInfo(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
            ),
        );
    }

    void _showError(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.error,
                behavior: SnackBarBehavior.floating,
            ),
        );
    }

    @override
    Widget build(BuildContext context) {
        final name = widget.displayName ?? 'Файл';
        final ext = widget.extension?.replaceFirst('.', '').toUpperCase();
        final size = widget.formattedSize;

        final subtitleParts = <String>[];
        if (ext != null && ext.isNotEmpty) subtitleParts.add(ext);
        if (size != null && size.isNotEmpty) subtitleParts.add(size);
        final subtitle = subtitleParts.join(' · ');

        final iconColor = _fileColor(widget.extension);
        final textColor = widget.isOwn
            ? RastaTheme.bubbleOwnText
            : RastaTheme.bubbleOtherText;
        final subtitleColor = widget.isOwn
            ? Colors.black54
            : RastaTheme.textMuted;

        return GestureDetector(
            onTap: _open,
            child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                ),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.5,
                    ),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                                child: Icon(
                                    _fileIcon(widget.extension),
                                    color: iconColor,
                                    size: 24,
                                ),
                            ),
                        ),

                        const SizedBox(width: 10),

                        Flexible(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Text(
                                        name,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                            subtitle,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: subtitleColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                ],
                            ),
                        ),

                        const SizedBox(width: 8),

                        if (_isOpening)
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
                            )
                        else
                            Icon(
                                Icons.download_rounded,
                                size: 22,
                                color: textColor.withValues(alpha: 0.85),
                            ),
                    ],
                ),
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
        final ImageProvider provider =
            CachedNetworkImageProvider(widget.url);
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

        return CachedNetworkImage(
            imageUrl: widget.url,
            width: _displayWidth,
            height: _displayHeight,
            fit: BoxFit.contain,
            memCacheWidth: (_displayWidth! * 2).toInt(),
            placeholder: (context, url) => _buildLoading(),
            errorWidget: (context, url, error) => _buildError(),
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

// =====================================================
// 🎤 ВИДЖЕТ ГОЛОСОВОГО СООБЩЕНИЯ
// =====================================================

class _VoiceMessageWidget extends StatefulWidget {
    final String url;
    final bool isOwn;

    const _VoiceMessageWidget({
        required this.url,
        required this.isOwn,
    });

    @override
    State<_VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<_VoiceMessageWidget> {
    final AudioPlayer _player = AudioPlayer();

    bool _isPlaying = false;
    bool _isLoading = true;
    bool _hasError = false;
    Duration _position = Duration.zero;
    Duration _duration = Duration.zero;

    @override
    void initState() {
        super.initState();
        _initPlayer();
    }

    Future<void> _initPlayer() async {
        try {
            final dur = await _player.setUrl(widget.url);
            if (!mounted) return;
            setState(() {
                _duration = dur ?? Duration.zero;
                _isLoading = false;
            });
        } catch (e) {
            if (!mounted) return;
            setState(() {
                _hasError = true;
                _isLoading = false;
            });
        }

        _player.playerStateStream.listen((state) {
            if (!mounted) return;
            setState(() {
                _isPlaying = state.playing &&
                    state.processingState != ProcessingState.completed;
            });

            if (state.processingState == ProcessingState.completed) {
                _player.seek(Duration.zero);
                _player.pause();
            }
        });

        _player.positionStream.listen((pos) {
            if (!mounted) return;
            setState(() => _position = pos);
        });
    }

    @override
    void dispose() {
        _player.dispose();
        super.dispose();
    }

    Future<void> _togglePlay() async {
        if (_hasError) return;
        if (_isPlaying) {
            await _player.pause();
        } else {
            await _player.play();
        }
    }

    String _formatDuration(Duration d) {
        final m = d.inMinutes;
        final s = d.inSeconds % 60;
        return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    @override
    Widget build(BuildContext context) {
        final textColor = widget.isOwn
            ? RastaTheme.bubbleOwnText
            : RastaTheme.bubbleOtherText;

        return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.2),
                        ),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            Colors.white70,
                                        ),
                                ),
                            )
                            : Icon(
                                _hasError
                                    ? Icons.error_outline
                                    : (_isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow),
                                color: textColor,
                                size: 26,
                            ),
                    ),
                ),

                const SizedBox(width: 10),

                SizedBox(
                    width: 120,
                    height: 32,
                    child: CustomPaint(
                        painter: _WaveformPainter(
                            progress: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds /
                                    _duration.inMilliseconds
                                : 0.0,
                            color: textColor,
                        ),
                    ),
                ),

                const SizedBox(width: 10),

                Text(
                    _isLoading
                        ? '--:--'
                        : _formatDuration(
                            _isPlaying || _position > Duration.zero
                                ? _position
                                : _duration,
                        ),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.85),
                    ),
                ),
            ],
        );
    }
}

// =====================================================
// 🎨 ПРОСТАЯ ВОЛНА (фиксированная форма)
// =====================================================

class _WaveformPainter extends CustomPainter {
    final double progress;
    final Color color;

    _WaveformPainter({
        required this.progress,
        required this.color,
    });

    static const List<double> _bars = [
        0.30, 0.55, 0.75, 0.45, 0.90, 0.60, 0.35, 0.80,
        0.50, 0.70, 0.40, 0.85, 0.55, 0.30, 0.65, 0.45,
        0.75, 0.50, 0.80, 0.35, 0.60, 0.45, 0.70, 0.55,
    ];

    @override
    void paint(Canvas canvas, Size size) {
        const barCount = 24;
        const barWidth = 2.0;
        final gap = (size.width - barCount * barWidth) / (barCount - 1);

        final playedBars = (progress * barCount).floor();

        final paintPlayed = Paint()
            ..color = color
            ..strokeWidth = barWidth
            ..strokeCap = StrokeCap.round;

        final paintRemaining = Paint()
            ..color = color.withValues(alpha: 0.35)
            ..strokeWidth = barWidth
            ..strokeCap = StrokeCap.round;

        for (int i = 0; i < barCount; i++) {
            final x = i * (barWidth + gap) + barWidth / 2;
            final barHeight = _bars[i] * size.height;
            final top = (size.height - barHeight) / 2;
            final bottom = top + barHeight;

            canvas.drawLine(
                Offset(x, top),
                Offset(x, bottom),
                i <= playedBars ? paintPlayed : paintRemaining,
            );
        }
    }

    @override
    bool shouldRepaint(_WaveformPainter oldDelegate) {
        return oldDelegate.progress != progress ||
            oldDelegate.color != color;
    }
}