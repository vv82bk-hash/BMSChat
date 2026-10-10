// =====================================================
// 📊 BMSChat — ЭКРАН СОЗДАНИЯ ГОЛОСОВАНИЯ
// =====================================================
// Открывается из меню «📎» в чате.
// Возвращает созданный Poll через Navigator.pop.
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';

class CreatePollScreen extends StatefulWidget {
    const CreatePollScreen({super.key});

    @override
    State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
    final _questionController = TextEditingController();
    final List<TextEditingController> _optionControllers = [];

    bool _isMultiple = false;
    bool _isAnonymous = false;
    bool _isSubmitting = false;

    @override
    void initState() {
        super.initState();

        // Стартуем с двух пустых вариантов (минимум по правилам)
        _optionControllers.add(TextEditingController());
        _optionControllers.add(TextEditingController());
    }

    @override
    void dispose() {
        _questionController.dispose();
        for (final c in _optionControllers) {
            c.dispose();
        }
        super.dispose();
    }

    // =====================================================
    // 🛠️ УПРАВЛЕНИЕ ВАРИАНТАМИ
    // =====================================================

    void _addOption() {
        if (_optionControllers.length >= Constants.pollOptionsMax) return;

        setState(() {
            _optionControllers.add(TextEditingController());
        });
    }

    void _removeOption(int index) {
        // Оставляем минимум 2 варианта
        if (_optionControllers.length <= Constants.pollOptionsMin) return;

        setState(() {
            final c = _optionControllers.removeAt(index);
            c.dispose();
        });
    }

    // =====================================================
    // ✅ ВАЛИДАЦИЯ И ОТПРАВКА
    // =====================================================

    String? _validate() {
        final question = _questionController.text.trim();
        if (question.isEmpty) return 'Введите вопрос';
        if (question.length > Constants.pollQuestionMax) {
            return 'Вопрос не длиннее ${Constants.pollQuestionMax} символов';
        }

        final options = _optionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();

        if (options.length < Constants.pollOptionsMin) {
            return 'Минимум ${Constants.pollOptionsMin} варианта';
        }

        for (final opt in options) {
            if (opt.length > Constants.pollOptionMax) {
                return 'Вариант не длиннее ${Constants.pollOptionMax} символов';
            }
        }

        return null;
    }

    Future<void> _submit() async {
        if (_isSubmitting) return;

        final error = _validate();
        if (error != null) {
            _showError(error);
            return;
        }

        final question = _questionController.text.trim();
        final options = _optionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();

        setState(() => _isSubmitting = true);

        final chat = Provider.of<ChatProvider>(context, listen: false);

        final created = await chat.createPoll(
            question: question,
            options: options,
            isMultiple: _isMultiple,
            isAnonymous: _isAnonymous,
        );

        if (!mounted) return;
        setState(() => _isSubmitting = false);

        if (created == null) {
            _showError(chat.messagesError ?? 'Не удалось создать голосование');
            return;
        }

        Navigator.pop(context, created);
    }

    // =====================================================
    // 🎨 UI
    // =====================================================

    @override
    Widget build(BuildContext context) {
        final canAddMore =
            _optionControllers.length < Constants.pollOptionsMax;
        final canRemove =
            _optionControllers.length > Constants.pollOptionsMin;

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('Новое голосование'),
                actions: [
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                RastaTheme.rastaYellow,
                                            ),
                                    ),
                                )
                                : const Text(
                                    'Создать',
                                    style: TextStyle(
                                        color: RastaTheme.rastaYellow,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                    ),
                                ),
                        ),
                    ),
                ],
            ),
            body: SafeArea(
                child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                        // ─── Вопрос ───
                        const Text(
                            'Вопрос',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: RastaTheme.textMuted,
                                letterSpacing: 0.5,
                            ),
                        ),
                        const SizedBox(height: 8),
                        _buildQuestionField(),
                        const SizedBox(height: 20),

                        // ─── Варианты ───
                        Row(
                            children: [
                                const Expanded(
                                    child: Text(
                                        'Варианты',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: RastaTheme.textMuted,
                                            letterSpacing: 0.5,
                                        ),
                                    ),
                                ),
                                Text(
                                    '${_optionControllers.length} / '
                                    '${Constants.pollOptionsMax}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: RastaTheme.textMuted,
                                    ),
                                ),
                            ],
                        ),
                        const SizedBox(height: 8),
                        ..._buildOptionFields(canRemove),
                        const SizedBox(height: 8),

                        if (canAddMore)
                            TextButton.icon(
                                onPressed: _addOption,
                                icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: RastaTheme.rastaYellow,
                                ),
                                label: const Text(
                                    'Добавить вариант',
                                    style: TextStyle(
                                        color: RastaTheme.rastaYellow,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                    ),
                                ),
                            ),

                        const SizedBox(height: 20),

                        // ─── Опции ───
                        _buildSwitchTile(
                            icon: Icons.checklist,
                            title: 'Можно выбрать несколько',
                            subtitle: 'Участники смогут отметить '
                                'несколько вариантов',
                            value: _isMultiple,
                            onChanged: (v) =>
                                setState(() => _isMultiple = v),
                        ),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                            icon: Icons.visibility_off_outlined,
                            title: 'Анонимное голосование',
                            subtitle: 'Скрыть имена проголосовавших',
                            value: _isAnonymous,
                            onChanged: (v) =>
                                setState(() => _isAnonymous = v),
                        ),

                        const SizedBox(height: 24),

                        // ─── Подсказка про лимиты ───
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: RastaTheme.surfaceSecondary,
                                borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Icon(
                                        Icons.info_outline,
                                        color: RastaTheme.textMuted,
                                        size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                        child: Text(
                                            'Максимум ${Constants.pollOptionsMax} вариантов. '
                                            'Вопрос — до ${Constants.pollQuestionMax} символов, '
                                            'вариант — до ${Constants.pollOptionMax}.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: RastaTheme.textMuted,
                                                height: 1.4,
                                            ),
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    // =====================================================
    // 🧱 ПОЛЕ ВОПРОСА
    // =====================================================
    Widget _buildQuestionField() {
        return TextField(
            controller: _questionController,
            maxLines: 4,
            minLines: 2,
            maxLength: Constants.pollQuestionMax,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
                color: RastaTheme.textPrimary,
                fontSize: 16,
            ),
            inputFormatters: [
                LengthLimitingTextInputFormatter(
                    Constants.pollQuestionMax,
                ),
            ],
            decoration: InputDecoration(
                hintText: 'Например: Где проводим следующую игру?',
                hintStyle: const TextStyle(
                    color: RastaTheme.textMuted,
                    fontSize: 15,
                ),
                filled: true,
                fillColor: RastaTheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(
                    color: RastaTheme.textMuted,
                    fontSize: 11,
                ),
            ),
        );
    }

    // =====================================================
    // 🧱 ПОЛЯ ВАРИАНТОВ
    // =====================================================
    List<Widget> _buildOptionFields(bool canRemove) {
        return List.generate(_optionControllers.length, (index) {
            return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                    children: [
                        // Номер варианта
                        Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                                color: RastaTheme.surfaceSecondary,
                                shape: BoxShape.circle,
                            ),
                            child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: RastaTheme.textMuted,
                                ),
                            ),
                        ),
                        const SizedBox(width: 10),

                        // Поле
                        Expanded(
                            child: TextField(
                                controller: _optionControllers[index],
                                maxLength: Constants.pollOptionMax,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(
                                    color: RastaTheme.textPrimary,
                                    fontSize: 15,
                                ),
                                inputFormatters: [
                                    LengthLimitingTextInputFormatter(
                                        Constants.pollOptionMax,
                                    ),
                                ],
                                decoration: InputDecoration(
                                    hintText: 'Вариант ${index + 1}',
                                    hintStyle: const TextStyle(
                                        color: RastaTheme.textMuted,
                                        fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: RastaTheme.surface,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                    ),
                                    counterText: '',
                                ),
                            ),
                        ),

                        // Кнопка «Удалить» (начиная с 3-го варианта)
                        if (canRemove && index >= Constants.pollOptionsMin)
                            IconButton(
                                onPressed: () => _removeOption(index),
                                icon: const Icon(
                                    Icons.close,
                                    color: RastaTheme.textMuted,
                                    size: 22,
                                ),
                                tooltip: 'Удалить вариант',
                            )
                        else if (canRemove)
                            // Занимаем место, чтобы поля выравнивались
                            const SizedBox(width: 48),
                    ],
                ),
            );
        });
    }

    // =====================================================
    // 🧱 ПЕРЕКЛЮЧАТЕЛЬ
    // =====================================================
    Widget _buildSwitchTile({
        required IconData icon,
        required String title,
        required String subtitle,
        required bool value,
        required ValueChanged<bool> onChanged,
    }) {
        return Container(
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
                value: value,
                onChanged: onChanged,
                activeThumbColor: RastaTheme.rastaYellow,
                secondary: Icon(
                    icon,
                    color: value
                        ? RastaTheme.rastaYellow
                        : RastaTheme.textMuted,
                ),
                title: Text(
                    title,
                    style: const TextStyle(
                        color: RastaTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                    ),
                ),
                subtitle: Text(
                    subtitle,
                    style: const TextStyle(
                        color: RastaTheme.textMuted,
                        fontSize: 12,
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 🔔 SNACKBAR
    // =====================================================
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
}