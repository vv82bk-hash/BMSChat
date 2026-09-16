// =====================================================
// 🎨 BMSChat — ТЕМА ПРИЛОЖЕНИЯ
// =====================================================
// Фирменный стиль: iPhone + Rasta.
//
// ВДОХНОВЕНИЕ:
//   • iPhone — минимализм, крупные отступы, скругления
//   • Rasta  — красно-жёлто-зелёные акценты
//
// ИСПОЛЬЗОВАНИЕ:
//   import 'package:bmschat/themes/rasta_theme.dart';
//   color: RastaTheme.rastaYellow
// =====================================================

import 'package:flutter/material.dart';

class RastaTheme {
    // =====================================================
    // 🎨 ЦВЕТА РАСТА (флаг)
    // =====================================================
    /// Красный — энергия, страсть
    static const Color rastaRed = Color(0xFFE31E24);

    /// Жёлтый — радость, оптимизм, акцент
    static const Color rastaYellow = Color(0xFFFED100);

    /// Зелёный — спокойствие, доверие
    static const Color rastaGreen = Color(0xFF00843D);

    // =====================================================
    // 🌑 ТЁМНАЯ ТЕМА (iPhone Dark)
    // =====================================================
    /// Основной фон — чистый чёрный (OLED)
    static const Color background = Color(0xFF000000);

    /// Карточки — iOS dark gray
    static const Color surface = Color(0xFF1C1C1E);

    /// Вторичные элементы — iOS dark gray 2
    static const Color surfaceSecondary = Color(0xFF2C2C2E);

    /// Разделители
    static const Color separator = Color(0xFF38383A);

    // =====================================================
    // 📝 ТЕКСТ
    // =====================================================
    /// Основной текст
    static const Color textPrimary = Color(0xFFFFFFFF);

    /// Вторичный текст
    static const Color textSecondary = Color(0xFFEBEBF5);

    /// Приглушённый текст (iOS gray)
    static const Color textMuted = Color(0xFF8E8E93);

    /// Акцент (жёлтый)
    static const Color textGold = rastaYellow;

    // =====================================================
    // 💬 СООБЩЕНИЯ
    // =====================================================
    /// Своё сообщение — жёлтый (раста-акцент)
    static const Color bubbleOwn = rastaYellow;

    /// Чужое сообщение — серый (iOS)
    static const Color bubbleOther = surfaceSecondary;

    /// Текст в своём сообщении — чёрный
    static const Color bubbleOwnText = Color(0xFF000000);

    /// Текст в чужом сообщении — белый
    static const Color bubbleOtherText = Color(0xFFFFFFFF);

    // =====================================================
    // 🎯 СТАТУСЫ
    // =====================================================
    /// Онлайн (iOS green)
    static const Color online = Color(0xFF34C759);

    /// Офлайн (iOS gray)
    static const Color offline = Color(0xFF8E8E93);

    /// Ошибка (раста-красный)
    static const Color error = rastaRed;

    /// Предупреждение (раста-жёлтый)
    static const Color warning = rastaYellow;

    /// Успех (раста-зелёный)
    static const Color success = rastaGreen;

    // =====================================================
    // 📐 РАЗМЕРЫ (iPhone-стандарты)
    // =====================================================
    /// Малое скругление (кнопки, поля)
    static const double radiusSmall = 8.0;

    /// Среднее скругление
    static const double radius = 12.0;

    /// Большое скругление (карточки)
    static const double radiusLarge = 18.0;

    /// Скругление пузырей сообщений
    static const double radiusBubble = 20.0;

    /// Малый отступ
    static const double paddingSmall = 8.0;

    /// Обычный отступ (стандарт iPhone)
    static const double padding = 16.0;

    /// Большой отступ
    static const double paddingLarge = 20.0;

    // =====================================================
    // ✨ ГРАДИЕНТЫ
    // =====================================================
    /// Градиент раста (красный → жёлтый → зелёный)
    static const LinearGradient rastaGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [rastaRed, rastaYellow, rastaGreen],
    );

    /// Градиент для своих сообщений (жёлтый → оранжевый)
    static const LinearGradient ownBubbleGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
            Color(0xFFFED100), // Жёлтый
            Color(0xFFFFA500), // Оранжевый
        ],
    );

    // =====================================================
    // 🌓 ТЕМА MATERIAL
    // =====================================================
    static ThemeData get darkTheme => ThemeData(
        // Базовая тема
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: rastaYellow,

        // Цветовая схема
        colorScheme: const ColorScheme.dark(
            primary: rastaYellow,
            secondary: rastaGreen,
            surface: surface,
            error: error,
            onPrimary: Color(0xFF000000),
            onSecondary: Color(0xFFFFFFFF),
            onSurface: textPrimary,
            onError: Color(0xFFFFFFFF),
        ),

        // Использовать Material 3
        useMaterial3: true,

        // =====================================================
        // 🔝 APPBAR
        // =====================================================
        appBarTheme: const AppBarTheme(
            backgroundColor: background,
            foregroundColor: textPrimary,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textPrimary,
                letterSpacing: -0.4,
            ),
            iconTheme: IconThemeData(
                color: textGold,
                size: 22,
            ),
        ),

        // =====================================================
        // 🎯 КНОПКИ
        // =====================================================
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: rastaYellow,
                foregroundColor: const Color(0xFF000000),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                ),
                textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                ),
            ),
        ),

        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: rastaYellow,
                textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                ),
            ),
        ),

        // =====================================================
        // 📝 ПОЛЯ ВВОДА
        // =====================================================
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surfaceSecondary,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: const BorderSide(
                    color: rastaYellow,
                    width: 1.5,
                ),
            ),
            hintStyle: const TextStyle(
                color: textMuted,
                fontSize: 16,
            ),
            labelStyle: const TextStyle(
                color: textMuted,
                fontSize: 16,
            ),
        ),

        // =====================================================
        // 📱 BOTTOM NAVIGATION BAR
        // =====================================================
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1C1C1E),
            selectedItemColor: rastaYellow,
            unselectedItemColor: textMuted,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(fontSize: 10),
        ),

        // =====================================================
        // 🃏 КАРТОЧКИ
        // =====================================================
        cardTheme: CardThemeData(
            color: surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
        ),

        // =====================================================
        // 📏 РАЗДЕЛИТЕЛИ
        // =====================================================
        dividerTheme: const DividerThemeData(
            color: separator,
            thickness: 0.5,
            space: 0,
        ),

        // =====================================================
        // 🖼️ ИКОНКИ
        // =====================================================
        iconTheme: const IconThemeData(
            color: textPrimary,
            size: 22,
        ),

        // =====================================================
        // 📝 ТЕКСТ
        // =====================================================
        textTheme: const TextTheme(
            // Заголовок (большой)
            displayLarge: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: textPrimary,
            ),
            // Заголовок экрана
            titleLarge: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textPrimary,
            ),
            // Заголовок секции
            titleMedium: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textPrimary,
            ),
            // Обычный текст
            bodyLarge: TextStyle(
                fontSize: 17,
                color: textPrimary,
            ),
            bodyMedium: TextStyle(
                fontSize: 15,
                color: textPrimary,
            ),
            // Мелкий текст
            bodySmall: TextStyle(
                fontSize: 13,
                color: textMuted,
            ),
        ),

        // =====================================================
        // 🌊 SPLASH
        // =====================================================
        splashColor: rastaYellow.withValues(alpha: 0.1),
        highlightColor: rastaYellow.withValues(alpha: 0.05),
    );
}