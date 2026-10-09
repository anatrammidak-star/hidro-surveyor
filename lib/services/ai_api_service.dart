import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client untuk API SiCA AI Backend di Cloud Run.
/// Gunakan hanya data uji sampai autentikasi backend diterapkan.
class AiApiService {
  AiApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl =
      'https://sica-ai-backend-116632445268.asia-southeast2.run.app';
  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client;

  Future<Map<String, dynamic>> checkHealth() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/health'))
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  /// Mengirim payload analisis. Jangan kirim foto/video lokal melalui local_path;
  /// backend belum memiliki endpoint upload media.
  Future<Map<String, dynamic>> analyze(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/v1/analyze'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw AiApiException(
        'Server mengirim respons yang bukan JSON (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiApiException(
        'Permintaan gagal (HTTP ${response.statusCode}): ${decoded is Map ? decoded['detail'] ?? response.body : response.body}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw AiApiException('Format respons server tidak sesuai.');
    }
    return decoded;
  }

  void close() => _client.close();
}

class AiApiException implements Exception {
  AiApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
