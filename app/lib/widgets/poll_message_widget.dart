// =====================================================
// 📊 BMSChat — ВИДЖЕТ ГОЛОСОВАНИЯ
// =====================================================
// Карточка голосования внутри пузыря сообщения.
//
// Особенности:
//   • Прогресс-бары для каждого варианта
//   • Подсветка выбранного варианта
//   • Кнопка «Голосовать» / «Отменить голос»
//   • Кнопка «Закрыть» для автора/админа
//   • Отображение списка голосовавших (если не анонимное)
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/poll.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';

class PollMessageWidget extends StatefulWidget {
    final Poll poll;
    final bool isOwn;

    const PollMessageWidget({
        super.key,
        required this.poll,
        required this.isOwn,
    });

    @override
    State<PollMessageWidget> createState() => _PollMessageWidgetState();
}

class _PollMessageWidgetState extends State<PollMessageWidget> {
    /// Локально выбранные варианты до нажатия «Голосовать»
    /// (только в режиме multiple)
    final Set<int> _selectedOptionIds = {};

    /// Флаг процесса голосования
    bool _isVoting = false;

    /// Флаг процесса закрытия
    bool _isClosing = false;

    @override
    void initState() {
        super.initState();
        _selectedOptionIds.addAll(widget.poll.myVotes);
    }

    @override
    void didUpdateWidget(PollMessageWidget oldWidget) {
        super.didUpdateWidget(oldWidget);

        // Если полл обновился (например, через socket) — синхронизируем
        // выбранные варианты с серверными значениями, если пользователь
        // не находится в процессе изменения.
        if (!_isVoting && !_isClosing) {
            final oldVotes = oldWidget.poll.myVotes.toSet();
            final newVotes = widget.poll.myVotes.toSet();
            if (!_setEquals(oldVotes, newVotes)) {
                setState(() {
                    _selectedOptionIds
                        ..clear()
                        ..addAll(newVotes);
                });
            }
        }
    }

    bool _setEquals(Set<int> a, Set<int> b) {
        if (a.length != b.length) return false;
        for (final item in a) {
            if (!b.contains(item)) return false;
        }
        return true;
    }

    /// Тап по варианту.
    /// - Одиночный: сразу отправляем голос (или отменяем, если уже выбран).
    /// - Множественный: переключаем выбор локально, отправка по кнопке.
    Future<void> _onOptionTap(int optionId) async {
        if (widget.poll.isClosed) return;
        if (_isVoting) return;

        final isMultiple = widget.poll.isMultiple;

        if (!isMultiple) {
            // Одиночный режим
            final alreadyVoted = widget.poll.myVotes.contains(optionId);

            if (alreadyVoted) {
                await _unvote();
            } else {
                await _vote([optionId]);
            }
            return;
        }

        // Множественный — только локальный toggle
        setState(() {
            if (_selectedOptionIds.contains(optionId)) {
                _selectedOptionIds.remove(optionId);
            } else {
                _selectedOptionIds.add(optionId);
            }
        });
    }

    Future<void> _vote(List<int> optionIds) async {
        if (_isVoting) return;
        setState(() => _isVoting = true);

        final chat = Provider.of<ChatProvider>(context, listen: false);
        final success = await chat.votePoll(widget.poll.id, optionIds);

        if (!mounted) return;
        setState(() => _isVoting = false);

        if (!success) {
            _showError('Не удалось проголосовать');
        }
    }

    Future<void> _unvote() async {
        if (_isVoting) return;
        setState(() => _isVoting = true);

        final chat = Provider.of<ChatProvider>(context, listen: false);
        final success = await chat.unvotePoll(widget.poll.id);

        if (!mounted) return;
        setState(() => _isVoting = false);

        if (!success) {
            _showError('Не удалось отменить голос');
        }
    }

    Future<void> _submitMultipleVote() async {
        if (_selectedOptionIds.isEmpty) {
            _showInfo('Выберите хотя бы один вариант');
            return;
        }
        await _vote(_selectedOptionIds.toList());
    }

    Future<void> _closePoll() async {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Закрыть голосование?',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: const Text(
                    'После закрытия голосовать будет нельзя.',
                    style: TextStyle(color: RastaTheme.textSecondary),
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
                            'Закрыть',
                            style: TextStyle(color: RastaTheme.error),
                        ),
                    ),
                ],
            ),
        );

        if (confirmed != true || !mounted) return;

        setState(() => _isClosing = true);

        final chat = Provider.of<ChatProvider>(context, listen: false);
        final success = await chat.closePoll(widget.poll.id);

        if (!mounted) return;
        setState(() => _isClosing = false);

        if (!success) {
            _showError('Не удалось закрыть голосование');
        }
    }

    void _showError(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.error,
                behavior: SnackBarBehavior.floating,
            ),
        );
    }

    void _showInfo(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: RastaTheme.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
            ),
        );
    }

    bool get _canClose {
        // Автор + админ чата. Проверка админа будет через AuthProvider.
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final me = auth.user;
        if (me == null) return false;

        if (widget.poll.createdBy == me.id) return true;
        if (me.isAdmin || me.isCommander) return true;

        return false;
    }

    @override
    Widget build(BuildContext context) {
        final poll = widget.poll;

        // Цвета текста зависят от того, свой пузырь или чужой
        final textColor = widget.isOwn
            ? RastaTheme.bubbleOwnText
            : RastaTheme.bubbleOtherText;

        final mutedColor = widget.isOwn
            ? Colors.black54
            : RastaTheme.textMuted;

        return Container(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                    // ─── Заголовок: 📊 + вопрос + статус ───
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            const Text('📊', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(
                                    poll.question,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                        height: 1.3,
                                    ),
                                ),
                            ),
                            if (poll.isClosed) ...[
                                const SizedBox(width: 6),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                        color: RastaTheme.error
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                        'закрыто',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: RastaTheme.error,
                                        ),
                                    ),
                                ),
                            ],
                        ],
                    ),

                    // ─── Бейджи: «несколько», «анонимное» ───
                    if (poll.isMultiple || poll.isAnonymous) ...[
                        const SizedBox(height: 6),
                        Wrap(
                            spacing: 6,
                            children: [
                                if (poll.isMultiple)
                                    _buildBadge('несколько', mutedColor),
                                if (poll.isAnonymous)
                                    _buildBadge('анонимное', mutedColor),
                            ],
                        ),
                    ],

                    const SizedBox(height: 10),

                    // ─── Варианты ───
                    ...poll.options.map(_buildOption),

                    const SizedBox(height: 8),

                    // ─── Итоги ───
                    Text(
                        _buildFooterText(poll),
                        style: TextStyle(
                            fontSize: 11,
                            color: mutedColor,
                        ),
                    ),

                    // ─── Кнопки ───
                    if (!poll.isClosed) ...[
                        const SizedBox(height: 8),
                        if (poll.isMultiple)
                            _buildSubmitMultipleButton()
                        else if (poll.hasVoted)
                            _buildUnvoteButton(),
                    ],

                    // ─── Кнопка «Закрыть» для автора/админа ───
                    if (!poll.isClosed && _canClose) ...[
                        const SizedBox(height: 6),
                        _buildCloseButton(),
                    ],
                ],
            ),
        );
    }

    Widget _buildBadge(String text, Color color) {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
                text,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                ),
            ),
        );
    }

    Widget _buildOption(PollOption option) {
        final poll = widget.poll;
        final textColor = widget.isOwn
            ? RastaTheme.bubbleOwnText
            : RastaTheme.bubbleOtherText;
        final mutedColor = widget.isOwn
            ? Colors.black54
            : RastaTheme.textMuted;

        final isMine = _selectedOptionIds.contains(option.id);
        final totalVotes = poll.totalVotes;
        final percent = totalVotes > 0
            ? (option.votesCount / totalVotes)
            : 0.0;

        // Визуально выбран свой или нет
        final borderColor = isMine
            ? RastaTheme.rastaYellow
            : Colors.transparent;

        return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
                onTap: poll.isClosed || _isVoting
                    ? null
                    : () => _onOptionTap(option.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                    ),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: borderColor,
                            width: 1.5,
                        ),
                    ),
                    child: Stack(
                        children: [
                            // Прогресс-бар (фон)
                            Positioned.fill(
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                            widthFactor: percent.clamp(
                                                0.0,
                                                1.0,
                                            ),
                                            child: Container(
                                                color: RastaTheme.rastaYellow
                                                    .withValues(alpha: 0.25),
                                            ),
                                        ),
                                    ),
                                ),
                            ),

                            // Содержимое
                            Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                ),
                                child: Row(
                                    children: [
                                        // Индикатор выбора
                                        if (isMine)
                                            const Padding(
                                                padding: EdgeInsets.only(
                                                    right: 6,
                                                ),
                                                child: Icon(
                                                    Icons.check_circle,
                                                    size: 16,
                                                    color: RastaTheme
                                                        .rastaYellow,
                                                ),
                                            ),

                                        // Текст варианта
                                        Expanded(
                                            child: Text(
                                                option.text,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isMine
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    color: textColor,
                                                ),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                            ),
                                        ),

                                        const SizedBox(width: 6),

                                        // Счётчик / процент
                                        Text(
                                            '${option.votesCount} · '
                                            '${(percent * 100).round()}%',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: mutedColor,
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

    String _buildFooterText(Poll poll) {
        final parts = <String>[];

        parts.add('Всего голосов: ${poll.totalVotes}');
        parts.add('Проголосовало: ${poll.distinctVoters}');

        return parts.join(' · ');
    }

    Widget _buildUnvoteButton() {
        return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                onPressed: _isVoting ? null : _unvote,
                icon: _isVoting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                RastaTheme.rastaYellow,
                            ),
                        ),
                    )
                    : const Icon(Icons.close, size: 16),
                label: const Text('Отменить голос'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: RastaTheme.rastaYellow,
                    side: const BorderSide(
                        color: RastaTheme.rastaYellow,
                        width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                ),
            ),
        );
    }

    Widget _buildSubmitMultipleButton() {
        final hasChanges = !_setEquals(
            _selectedOptionIds,
            widget.poll.myVotes.toSet(),
        );

        return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                onPressed:
                    _isVoting || !hasChanges ? null : _submitMultipleVote,
                icon: _isVoting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                            ),
                        ),
                    )
                    : const Icon(Icons.how_to_vote, size: 18),
                label: Text(
                    widget.poll.hasVoted
                        ? 'Обновить голос'
                        : 'Голосовать',
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: RastaTheme.rastaYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                ),
            ),
        );
    }

    Widget _buildCloseButton() {
        return TextButton.icon(
            onPressed: _isClosing ? null : _closePoll,
            icon: _isClosing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            RastaTheme.error,
                        ),
                    ),
                )
                : const Icon(Icons.lock_outline, size: 16),
            label: const Text('Закрыть голосование'),
            style: TextButton.styleFrom(
                foregroundColor: RastaTheme.error,
                padding: const EdgeInsets.symmetric(vertical: 6),
            ),
        );
    }
}