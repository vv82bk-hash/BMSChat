// =====================================================
// 🔐 BMSChat — ЭКРАН ВХОДА / РЕГИСТРАЦИИ
// =====================================================
// Единый экран для входа и регистрации.
// Переключение между режимами одной кнопкой.
//
// ФУНКЦИИ:
//   • Поля логин + пароль
//   • Показ/скрытие пароля
//   • Кнопка «Войти» / «Зарегистрироваться»
//   • Переключение режима
//   • Чекбокс «Я согласен на обработку ПД» (для регистрации)
//   • Индикатор загрузки
//   • Показ ошибок
//
// ПОСЛЕ ВХОДА:
//   Автоматический переход на ChatsScreen
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';
import '../utils/app_logger.dart';
import 'chats_screen.dart';

class LoginScreen extends StatefulWidget {
    const LoginScreen({super.key});

    @override
    State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
    // =====================================================
    // 🎛️ КОНТРОЛЛЕРЫ И СОСТОЯНИЕ
    // =====================================================
    final _usernameController = TextEditingController();
    final _passwordController = TextEditingController();
    final _displayNameController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    bool _isRegisterMode = false;      // false = вход, true = регистрация
    bool _obscurePassword = true;      // скрыт ли пароль
    bool _agreedToPrivacy = false;     // согласен на обработку ПД

    @override
    void dispose() {
        _usernameController.dispose();
        _passwordController.dispose();
        _displayNameController.dispose();
        super.dispose();
    }

    // =====================================================
    // 🔑 ВХОД / РЕГИСТРАЦИЯ
    // =====================================================
    Future<void> _submit() async {
        // Валидация
        if (!_formKey.currentState!.validate()) return;

        // Проверка чекбокса при регистрации
        if (_isRegisterMode && !_agreedToPrivacy) {
            _showError('Необходимо согласие на обработку персональных данных');
            return;
        }

        final auth = Provider.of<AuthProvider>(context, listen: false);
        final chat = Provider.of<ChatProvider>(context, listen: false);
        final username = _usernameController.text.trim();
        final password = _passwordController.text;
        final displayName = _displayNameController.text.trim();

        // ═══════════════════════════════════════════
        // РЕЖИМ РЕГИСТРАЦИИ
        // ═══════════════════════════════════════════
        if (_isRegisterMode) {
            final success = await auth.register(
                username,
                password,
                displayName.isEmpty ? username : displayName,
            );

            if (!mounted) return;

            if (success) {
                _showSuccess('Регистрация успешна! Ожидайте подтверждения командира.');
                setState(() {
                    _isRegisterMode = false;
                    _passwordController.clear();
                    _displayNameController.clear();
                    _agreedToPrivacy = false;
                });
            } else {
                _showError(auth.error ?? 'Ошибка регистрации');
            }
            return;
        }

        // ═══════════════════════════════════════════
        // РЕЖИМ ВХОДА
        // ═══════════════════════════════════════════
        final success = await auth.login(username, password);

        if (!mounted) return;

        if (success) {
            AppLogger.success('Вход выполнен, переход на ChatsScreen');

            // Инициализируем Socket-слушатели в ChatProvider
            chat.initSocketListeners();

            // Переходим на ChatsScreen
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => const ChatsScreen(),
                ),
            );
        } else {
            _showError(auth.error ?? 'Ошибка входа');
        }
    }

    // =====================================================
    // 📢 SNACKBARS
    // =====================================================
    void _showError(String message) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Row(
                    children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(child: Text(message)),
                    ],
                ),
                backgroundColor: RastaTheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
            ),
        );
    }

    void _showSuccess(String message) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Row(
                    children: [
                        const Icon(Icons.check_circle_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(child: Text(message)),
                    ],
                ),
                backgroundColor: RastaTheme.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
            ),
        );
    }

    // =====================================================
    // 📄 PRIVACY.md
    // =====================================================
    void _openPrivacyPolicy() {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                backgroundColor: RastaTheme.surface,
                title: const Text(
                    'Политика обработки ПД',
                    style: TextStyle(color: RastaTheme.textPrimary),
                ),
                content: const SingleChildScrollView(
                    child: Text(
                        'Политика обработки персональных данных\n\n'
                        'Дата последнего обновления: 16.09.2026\n\n'
                        '1. Общие положения\n'
                        'Настоящая Политика описывает, как приложение BMSChat '
                        'работает с персональными данными.\n\n'
                        '2. Какие данные мы обрабатываем\n'
                        '• Логин (username)\n'
                        '• Пароль (хранится в виде хеша)\n'
                        '• Отображаемое имя\n'
                        '• Сообщения и их метаданные\n\n'
                        '3. Цели обработки\n'
                        '• Идентификация в приложении\n'
                        '• Обеспечение работы мессенджера\n'
                        '• Связь внутри команды\n\n'
                        '4. Хранение\n'
                        'Данные хранятся на серверах, расположенных на территории РФ.\n\n'
                        '5. Ваши права\n'
                        'Вы можете запросить удаление своих данных.\n\n'
                        '6. Согласие\n'
                        'Используя приложение, вы соглашаетесь с обработкой данных '
                        'в указанных целях.',
                        style: TextStyle(color: RastaTheme.textSecondary),
                    ),
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                            'Понятно',
                            style: TextStyle(color: RastaTheme.rastaYellow),
                        ),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 🎨 UI
    // =====================================================
    @override
    Widget build(BuildContext context) {
        final auth = Provider.of<AuthProvider>(context);

        return Scaffold(
            backgroundColor: RastaTheme.background,
            body: SafeArea(
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                            key: _formKey,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    // ══════════════════════════════════
                                    // ЛОГОТИП
                                    // ══════════════════════════════════
                                    _buildLogo(),

                                    const SizedBox(height: 40),

                                    // ══════════════════════════════════
                                    // ЗАГОЛОВОК РЕЖИМА
                                    // ══════════════════════════════════
                                    Text(
                                        _isRegisterMode ? 'Регистрация' : 'Вход',
                                        style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: RastaTheme.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                    ),

                                    const SizedBox(height: 24),

                                    // ══════════════════════════════════
                                    // ПОЛЕ: ЛОГИН
                                    // ══════════════════════════════════
                                    TextFormField(
                                        controller: _usernameController,
                                        enabled: !auth.isLoading,
                                        style: const TextStyle(
                                            color: RastaTheme.textPrimary,
                                        ),
                                        decoration: const InputDecoration(
                                            labelText: 'Логин',
                                            hintText: 'Введите логин',
                                            prefixIcon: Icon(
                                                Icons.person_outline,
                                                color: RastaTheme.textMuted,
                                            ),
                                        ),
                                        validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                                return 'Введите логин';
                                            }
                                            if (value.trim().length < 3) {
                                                return 'Логин минимум 3 символа';
                                            }
                                            if (!RegExp(r'^[a-zA-Z0-9_]+$')
                                                .hasMatch(value.trim())) {
                                                return 'Только латиница, цифры и _';
                                            }
                                            return null;
                                        },
                                    ),

                                    const SizedBox(height: 16),

                                    // ══════════════════════════════════
                                    // ПОЛЕ: ОТОБРАЖАЕМОЕ ИМЯ (только для регистрации)
                                    // ══════════════════════════════════
                                    if (_isRegisterMode) ...[
                                        TextFormField(
                                            controller: _displayNameController,
                                            enabled: !auth.isLoading,
                                            style: const TextStyle(
                                                color: RastaTheme.textPrimary,
                                            ),
                                            decoration: const InputDecoration(
                                                labelText: 'Отображаемое имя',
                                                hintText: 'Например: Боб Марли',
                                                prefixIcon: Icon(
                                                    Icons.badge_outlined,
                                                    color: RastaTheme.textMuted,
                                                ),
                                            ),
                                        ),
                                        const SizedBox(height: 16),
                                    ],

                                    // ══════════════════════════════════
                                    // ПОЛЕ: ПАРОЛЬ
                                    // ══════════════════════════════════
                                    TextFormField(
                                        controller: _passwordController,
                                        enabled: !auth.isLoading,
                                        obscureText: _obscurePassword,
                                        style: const TextStyle(
                                            color: RastaTheme.textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                            labelText: 'Пароль',
                                            hintText: 'Введите пароль',
                                            prefixIcon: const Icon(
                                                Icons.lock_outline,
                                                color: RastaTheme.textMuted,
                                            ),
                                            suffixIcon: IconButton(
                                                icon: Icon(
                                                    _obscurePassword
                                                        ? Icons.visibility_outlined
                                                        : Icons.visibility_off_outlined,
                                                    color: RastaTheme.textMuted,
                                                ),
                                                onPressed: () {
                                                    setState(() {
                                                        _obscurePassword = !_obscurePassword;
                                                    });
                                                },
                                            ),
                                        ),
                                        validator: (value) {
                                            if (value == null || value.isEmpty) {
                                                return 'Введите пароль';
                                            }
                                            if (value.length < 6) {
                                                return 'Пароль минимум 6 символов';
                                            }
                                            return null;
                                        },
                                    ),

                                    // ══════════════════════════════════
                                    // ЧЕКБОКС ПД (только при регистрации)
                                    // ══════════════════════════════════
                                    if (_isRegisterMode) ...[
                                        const SizedBox(height: 16),
                                        _buildPrivacyCheckbox(),
                                    ],

                                    const SizedBox(height: 24),

                                    // ══════════════════════════════════
                                    // КНОПКА ВХОДА / РЕГИСТРАЦИИ
                                    // ══════════════════════════════════
                                    SizedBox(
                                        height: 56,
                                        child: ElevatedButton(
                                            onPressed: auth.isLoading ? null : _submit,
                                            child: auth.isLoading
                                                ? const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<Color>(
                                                                RastaTheme.background),
                                                    ),
                                                )
                                                : Text(
                                                    _isRegisterMode
                                                        ? '📝 Зарегистрироваться'
                                                        : '🔑 Войти',
                                                    style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w700,
                                                    ),
                                                ),
                                        ),
                                    ),

                                    const SizedBox(height: 16),

                                    // ══════════════════════════════════
                                    // ПЕРЕКЛЮЧЕНИЕ РЕЖИМА
                                    // ══════════════════════════════════
                                    TextButton(
                                        onPressed: auth.isLoading
                                            ? null
                                            : () {
                                                setState(() {
                                                    _isRegisterMode = !_isRegisterMode;
                                                });
                                            },
                                        child: Text(
                                            _isRegisterMode
                                                ? 'Уже есть аккаунт? Войти'
                                                : 'Нет аккаунта? Создать',
                                            style: const TextStyle(
                                                color: RastaTheme.rastaYellow,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 24),

                                    // ══════════════════════════════════
                                    // ФУТЕР
                                    // ══════════════════════════════════
                                    Text(
                                        '🌿 One Love ✌️',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: RastaTheme.textMuted
                                                .withValues(alpha: 0.7),
                                        ),
                                        textAlign: TextAlign.center,
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
    // 🎨 ЛОГОТИП
    // =====================================================
    Widget _buildLogo() {
        return Column(
            children: [
                // Круг с градиентом и эмодзи
                Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                                RastaTheme.rastaRed,
                                RastaTheme.rastaYellow,
                                RastaTheme.rastaGreen,
                            ],
                        ),
                        boxShadow: [
                            BoxShadow(
                                color: RastaTheme.rastaYellow.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 3,
                            ),
                        ],
                    ),
                    child: const Center(
                        child: Text('🎯', style: TextStyle(fontSize: 48)),
                    ),
                ),

                const SizedBox(height: 16),

                // Название
                const Text(
                    'BMSChat',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: RastaTheme.rastaYellow,
                        letterSpacing: -1,
                    ),
                ),

                const SizedBox(height: 4),

                // Подзаголовок
                Text(
                    'Отряд Боба Марли',
                    style: TextStyle(
                        fontSize: 14,
                        color: RastaTheme.textSecondary.withValues(alpha: 0.7),
                        letterSpacing: 1.5,
                    ),
                ),

                const SizedBox(height: 12),

                // Раста-полоска
                Container(
                    height: 3,
                    width: 100,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                            colors: [
                                RastaTheme.rastaRed,
                                RastaTheme.rastaYellow,
                                RastaTheme.rastaGreen,
                            ],
                        ),
                    ),
                ),
            ],
        );
    }

    // =====================================================
    // ☑️ ЧЕКБОКС ПД
    // =====================================================
    Widget _buildPrivacyCheckbox() {
        return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Чекбокс
                SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                        value: _agreedToPrivacy,
                        onChanged: (value) {
                            setState(() {
                                _agreedToPrivacy = value ?? false;
                            });
                        },
                        activeColor: RastaTheme.rastaYellow,
                        checkColor: RastaTheme.background,
                        side: const BorderSide(
                            color: RastaTheme.textMuted,
                            width: 1.5,
                        ),
                    ),
                ),

                const SizedBox(width: 8),

                // Текст
                Expanded(
                    child: GestureDetector(
                        onTap: () {
                            setState(() {
                                _agreedToPrivacy = !_agreedToPrivacy;
                            });
                        },
                        child: Wrap(
                            children: [
                                const Text(
                                    'Я согласен на ',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: RastaTheme.textSecondary,
                                    ),
                                ),
                                GestureDetector(
                                    onTap: _openPrivacyPolicy,
                                    child: const Text(
                                        'обработку персональных данных',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: RastaTheme.rastaYellow,
                                            decoration: TextDecoration.underline,
                                            decorationColor: RastaTheme.rastaYellow,
                                        ),
                                    ),
                                ),
                            ],
                        ),
                    ),
                ),
            ],
        );
    }
}