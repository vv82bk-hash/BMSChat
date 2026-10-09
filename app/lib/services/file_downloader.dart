// =====================================================
// 📥 BMSChat — СКАЧИВАНИЕ И ОТКРЫТИЕ ФАЙЛОВ
// =====================================================
// 🎯 Назначение:
//   • Скачать файл с сервера во временную папку
//   • Открыть его системным приложением (Android/iOS)
//   • На Web — открыть в новой вкладке через url_launcher
//
// 🎯 Используется в MessageBubble для FILE:-сообщений.
//
// 🎯 Особенности:
//   • Файлы на сервере публичные (без авторизации)
//   • Кэш: если файл уже скачан — открываем сразу
//   • Имя файла берётся из displayName, если есть
// =====================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../utils/app_logger.dart';

// =====================================================
// 📊 РЕЗУЛЬТАТ ОТКРЫТИЯ
// =====================================================

enum FileOpenStatus {
    /// Файл успешно скачан и открыт
    success,

    /// Не найдено приложение для этого типа файла
    noApp,

    /// Ошибка (сеть, диск, сервер)
    error,
}

class FileOpenResult {
    final FileOpenStatus status;
    final String? message;
    final String? savedPath;

    const FileOpenResult({
        required this.status,
        this.message,
        this.savedPath,
    });

    factory FileOpenResult.success({String? savedPath}) =>
        FileOpenResult(
            status: FileOpenStatus.success,
            savedPath: savedPath,
        );

    factory FileOpenResult.noApp({String? savedPath}) =>
        FileOpenResult(
            status: FileOpenStatus.noApp,
            message: 'Нет приложения для открытия этого файла',
            savedPath: savedPath,
        );

    factory FileOpenResult.error(String message) =>
        FileOpenResult(
            status: FileOpenStatus.error,
            message: message,
        );

    bool get isSuccess => status == FileOpenStatus.success;
    bool get isNoApp => status == FileOpenStatus.noApp;
    bool get isError => status == FileOpenStatus.error;
}

// =====================================================
// 📥 СЕРВИС СКАЧИВАНИЯ
// =====================================================

class FileDownloader {
    /// 🎯 Открыть файл.
    ///
    /// [filePath] — относительный путь на сервере: `/api/files/abc123`.
    /// [displayName] — человеческое имя файла: `Отчёт.pdf`. Может быть null.
    static Future<FileOpenResult> open({
        required String filePath,
        String? displayName,
    }) async {
        // ─── Web ───
        // Прямая ссылка в новой вкладке — браузер сам решит, скачать
        // или открыть. Никакого http и OpenFilex на web нет.
        if (kIsWeb) {
            return _openOnWeb(filePath);
        }

        // ─── Android / iOS ───
        return _downloadAndOpenMobile(
            filePath: filePath,
            displayName: displayName,
        );
    }

    // =====================================================
    // 🌐 WEB
    // =====================================================

    static Future<FileOpenResult> _openOnWeb(String filePath) async {
        try {
            final fullUrl = _buildFullUrl(filePath);
            final uri = Uri.parse(fullUrl);

            final launched = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
            );

            if (!launched) {
                return FileOpenResult.error(
                    'Не удалось открыть ссылку в браузере',
                );
            }

            return FileOpenResult.success();
        } catch (e) {
            AppLogger.error('Ошибка открытия файла на web', e);
            return FileOpenResult.error('Ошибка открытия: $e');
        }
    }

    // =====================================================
    // 📱 MOBILE (Android / iOS)
    // =====================================================

    static Future<FileOpenResult> _downloadAndOpenMobile({
        required String filePath,
        String? displayName,
    }) async {
        try {
            final fullUrl = _buildFullUrl(filePath);

            // 1. Готовим папку для скачанных файлов
            final rootDir = await getTemporaryDirectory();
            final appDir = Directory('${rootDir.path}/bmschat_files');

            if (!await appDir.exists()) {
                await appDir.create(recursive: true);
            }

            // 2. Формируем безопасное имя файла
            final safeName = _sanitizeName(displayName, filePath);
            final file = File('${appDir.path}/$safeName');

            // 3. Если файл уже скачан — открываем сразу
            if (await file.exists() && await file.length() > 0) {
                AppLogger.info('📂 Файл из кэша: ${file.path}');
                return _openWithSystem(file);
            }

            // 4. Скачиваем
            AppLogger.info('📥 Скачивание: $fullUrl → ${file.path}');

            final response = await http
                .get(Uri.parse(fullUrl))
                .timeout(const Duration(seconds: 60));

            if (response.statusCode != 200) {
                AppLogger.warn(
                    'Скачивание не удалось: HTTP ${response.statusCode}',
                );
                return FileOpenResult.error(
                    'Сервер вернул ошибку ${response.statusCode}',
                );
            }

            if (response.bodyBytes.isEmpty) {
                return FileOpenResult.error('Файл пустой');
            }

            // 5. Записываем байты
            await file.writeAsBytes(response.bodyBytes, flush: true);

            AppLogger.success(
                '✅ Файл скачан: ${file.path} '
                '(${response.bodyBytes.length} байт)',
            );

            // 6. Открываем
            return _openWithSystem(file);
        } on TimeoutException {
            AppLogger.error('Таймаут скачивания файла');
            return FileOpenResult.error('Сервер не отвечает');
        } on SocketException {
            AppLogger.error('Ошибка сети при скачивании');
            return FileOpenResult.error('Нет соединения с сервером');
        } on FileSystemException catch (e) {
            AppLogger.error('Ошибка файловой системы', e);
            return FileOpenResult.error(
                'Не удалось сохранить файл: ${e.message}',
            );
        } catch (e) {
            AppLogger.error('Ошибка скачивания файла', e);
            return FileOpenResult.error('Ошибка: $e');
        }
    }

    // =====================================================
    // 🔧 ОТКРЫТИЕ СИСТЕМНЫМ ПРИЛОЖЕНИЕМ
    // =====================================================

    static Future<FileOpenResult> _openWithSystem(File file) async {
        try {
            final result = await OpenFilex.open(file.path);

            AppLogger.info(
                'OpenFilex: type=${result.type}, message=${result.message}',
            );

            switch (result.type) {
                case ResultType.done:
                    return FileOpenResult.success(savedPath: file.path);

                case ResultType.noAppToOpen:
                    return FileOpenResult.noApp(savedPath: file.path);

                case ResultType.fileNotFound:
                    return FileOpenResult.error(
                        'Файл не найден на устройстве',
                    );

                case ResultType.permissionDenied:
                    return FileOpenResult.error(
                        'Нет прав на открытие файла',
                    );

                case ResultType.error:
                    return FileOpenResult.error(
                        result.message.isNotEmpty
                            ? result.message
                            : 'Не удалось открыть файл',
                    );
            }
        } catch (e) {
            AppLogger.error('Ошибка OpenFilex', e);
            return FileOpenResult.error('Ошибка открытия: $e');
        }
    }

    // =====================================================
    // 🛠️ УТИЛИТЫ
    // =====================================================

    /// Собирает полный URL: `{baseUrl}{filePath}`.
    /// Если filePath уже абсолютный — возвращает как есть.
    static String _buildFullUrl(String filePath) {
        if (filePath.startsWith('http://') ||
            filePath.startsWith('https://')) {
            return filePath;
        }
        final base = Constants.baseUrl;
        final path = filePath.startsWith('/') ? filePath : '/$filePath';
        return '$base$path';
    }

    /// Безопасное имя файла.
    /// Приоритет: [displayName] → последний сегмент [filePath] → fallback.
    ///
    /// Запрещённые символы для файловых систем (`/ \ : * ? " < > |`)
    /// заменяются на `_`.
    static String _sanitizeName(String? displayName, String filePath) {
        String name;

        if (displayName != null && displayName.trim().isNotEmpty) {
            name = displayName.trim();
        } else {
            // Последний сегмент пути
            final segments = filePath.split('/');
            name = segments.isNotEmpty && segments.last.isNotEmpty
                ? segments.last
                : 'file_${DateTime.now().millisecondsSinceEpoch}';
        }

        // Убираем запрещённые символы
        name = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');

        // Ограничиваем длину (200 символов — с запасом для ext4/NTFS)
        if (name.length > 200) {
            final extIdx = name.lastIndexOf('.');
            if (extIdx > 0) {
                final ext = name.substring(extIdx);
                name = name.substring(0, 200 - ext.length) + ext;
            } else {
                name = name.substring(0, 200);
            }
        }

        // Если осталось пустое — fallback
        if (name.isEmpty) {
            name = 'file_${DateTime.now().millisecondsSinceEpoch}';
        }

        return name;
    }
}