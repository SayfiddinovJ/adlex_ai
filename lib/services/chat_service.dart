import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

/// Barcha chat va audio logika shu yerda.
/// ChatScreen faqat UI bilan shug'ullanadi.
class ChatService {
  // ── 1. O'z backend URL ingizni shu yerga qo'ying ────────────
  static const String _baseUrl = 'https://your-backend.com/api';
  // ────────────────────────────────────────────────────────────

  late final Dio _dio;
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordPath;

  ChatService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        // 'Authorization': 'Bearer YOUR_TOKEN', // Token kerak bo'lsa
      },
    ));

    // Request/Response loglar (debug uchun)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  // ── Matn xabar yuborish ──────────────────────────────────────
  /// Backend'ga matn yuborib, AI javobini qaytaradi.
  Future<String> sendMessage(String text) async {
    try {
      final response = await _dio.post(
        '/chat',  // → https://your-backend.com/api/chat
        data: {
          'message': text,
          'language': 'uz',
        },
      );

      // Backend qanday JSON qaytarishiga qarab moslashtiring:
      // { "reply": "..." }  →  response.data['reply']
      // { "answer": "..." } →  response.data['answer']
      // { "text": "..." }   →  response.data['text']
      return response.data['reply'] as String? ??
          response.data['answer'] as String? ??
          response.data['text'] as String? ??
          "Javob olishda xatolik yuz berdi.";
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── Yozuvni boshlash ─────────────────────────────────────────
  Future<bool> startRecording() async {
    // Mikrofon ruxsatini so'rash
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    // Saqlash yo'li
    final dir = await getTemporaryDirectory();
    _currentRecordPath =
    '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,  // M4A/AAC — barcha backend qabul qiladi
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _currentRecordPath!,
    );
    return true;
  }

  // ── Yozuvni to'xtatish ───────────────────────────────────────
  /// To'xtatadi va fayl yo'lini qaytaradi.
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path ?? _currentRecordPath;
  }

  // ── Yozuvni bekor qilish ─────────────────────────────────────
  Future<void> cancelRecording() async {
    await _recorder.cancel();
    // Yaratilgan faylni o'chirib tashlash
    if (_currentRecordPath != null) {
      final file = File(_currentRecordPath!);
      if (await file.exists()) await file.delete();
      _currentRecordPath = null;
    }
  }

  // ── Audio yuborish ───────────────────────────────────────────
  /// Audio faylni multipart/form-data sifatida yuboradi.
  Future<String> sendAudio(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Audio fayl topilmadi');
      }

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          filePath,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        ),
        'language': 'uz',
      });

      final response = await _dio.post(
        '/chat/audio',  // → https://your-backend.com/api/chat/audio
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          // Progress kuzatish (ixtiyoriy)
          // print('Upload: ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );

      return response.data['reply'] as String? ??
          response.data['answer'] as String? ??
          response.data['transcription'] as String? ??
          "Ovoz xabar qayta ishlandi.";
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── Xato qayta ishlash ───────────────────────────────────────
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Serverga ulanish vaqti tugadi. Internet aloqasini tekshiring.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401) return 'Avtorizatsiya xatosi. Iltimos qayta kiring.';
        if (code == 429) return 'Juda ko\'p so\'rov. Biroz kuting.';
        if (code != null && code >= 500) return 'Server xatosi ($code). Keyinroq urinib ko\'ring.';
        return 'Server xatosi: ${e.response?.statusMessage}';
      case DioExceptionType.connectionError:
        return 'Internet aloqasi yo\'q. Ulanishni tekshiring.';
      default:
        return 'Noma\'lum xatolik yuz berdi. Qayta urinib ko\'ring.';
    }
  }

  void dispose() {
    _recorder.dispose();
    _dio.close();
  }
}
