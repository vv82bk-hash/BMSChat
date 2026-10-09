// =====================================================
// 🎤 BMSChat — СЕРВИС ЗАПИСИ ГОЛОСОВЫХ СООБЩЕНИЙ
// =====================================================
// Формат: OGG/Opus (как в Telegram) — совместим с Android и iOS.
// Используется пакет record 6.x.
// =====================================================

import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  String? _currentPath;

  // Стрим длительности — для UI (таймер записи)
  final _durationController = StreamController<int>.broadcast();
  Stream<int> get durationStream => _durationController.stream;

  bool get isRecording => _timer != null;

  /// Начать запись. Возвращает true, если запись стартовала.
  Future<bool> startRecording() async {
    if (isRecording) return false;

    try {
      if (!await _recorder.hasPermission()) {
        return false;
      }

      final dir = await getTemporaryDirectory();
      _currentPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.ogg';

      // ⚠️ Ключевое: OGG/Opus — как в Telegram
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 48000,     // 48 kbps — оптимум для речи
          sampleRate: 48000,  // 48 kHz
          numChannels: 1,     // моно — как в Telegram
        ),
        path: _currentPath!,
      );

      _seconds = 0;
      _durationController.add(0);

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _seconds++;
        _durationController.add(_seconds);

        // Telegram ограничивает голосовые ~5 минутами
        if (_seconds >= 300) {
          stopRecording();
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Остановить запись. Возвращает (path, seconds) или null, если файла нет.
  Future<({String path, int seconds})?> stopRecording() async {
    if (!isRecording) return null;

    _timer?.cancel();
    _timer = null;

    try {
      final path = await _recorder.stop();
      if (path == null) return null;

      final seconds = _seconds;
      _seconds = 0;

      return (path: path, seconds: seconds);
    } catch (e) {
      return null;
    }
  }

  /// Отмена — файл удаляется.
  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    _seconds = 0;

    try {
      await _recorder.stop();
    } catch (_) {}
  }

  void dispose() {
    _timer?.cancel();
    _durationController.close();
    _recorder.dispose();
  }
}