import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'l10n/app_strings.dart';

// Live backend (deployed on Render)
const String apiBase = 'https://cyberlens-api-ukku.onrender.com';

/// An error whose message is safe to show directly to the user.
/// [message] is the English text. When [key] is set, [text] shows the
/// translated version instead (see lib/l10n); [suffix] is added after it.
class ApiException implements Exception {
  final String message;
  final String? key;
  final String suffix;
  ApiException(this.message, {this.key, this.suffix = ''});

  /// Text for the user in the chosen language.
  String text(BuildContext context) =>
      key == null ? message : '${context.t(key!)}$suffix';

  @override
  String toString() => message;
}

class ApiService {
  // Render's free tier can take 50+ seconds to wake up (cold start)
  static const Duration _jsonTimeout = Duration(seconds: 180);
  static const Duration _uploadTimeout = Duration(seconds: 240);

  static const String _timeoutMessage =
      'The server took too long to respond. It may be waking up, so please try again.';
  static const String _networkMessage =
      'Could not reach the server. Check your internet connection and try again.';

  // ---------------------------------------------------------------- public API

  static Future<Map<String, dynamic>> analyzeUrl(String url) =>
      _postJson('/analyze/url', {'url': url});

  static Future<Map<String, dynamic>> analyzeEmail(String text) =>
      _postJson('/analyze/email', {'text': text});

  static Future<Map<String, dynamic>> analyzeQr(String filePath, String fileName) =>
      _upload('/analyze/qr', filePath, fileName);

  static Future<Map<String, dynamic>> analyzeApk(String filePath, String fileName) =>
      _upload('/analyze/apk', filePath, fileName);

  static Future<Map<String, dynamic>> analyzeAccount(String scenarioId) =>
      _postJson('/analyze/account', {'scenario': scenarioId});

  /// Demo scenarios for the account-takeover dropdown: [{id, description}, ...]
  static Future<List<Map<String, dynamic>>> getScenarios() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBase/analyze/account/scenarios'))
          .timeout(_jsonTimeout);
      final data = _decode(response);
      return (data['scenarios'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(_timeoutMessage, key: 'err.timeout');
    } catch (_) {
      throw ApiException(_networkMessage, key: 'err.network');
    }
  }

  // ------------------------------------------------------------------ helpers

  /// Wakes the free server up when the app opens (it sleeps after idle time).
  /// The answer is ignored; errors are ignored too.
  static Future<void> warmUp() async {
    try {
      await http
          .get(Uri.parse('$apiBase/analyze/account/scenarios'))
          .timeout(const Duration(seconds: 120));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBase$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_jsonTimeout);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(_timeoutMessage, key: 'err.timeout');
    } catch (_) {
      throw ApiException(_networkMessage, key: 'err.network');
    }
  }

  /// Multipart upload. The backend expects the form field to be named "file".
  static Future<Map<String, dynamic>> _upload(
      String path, String filePath, String fileName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$apiBase$path'));
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );
      final streamed = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(_timeoutMessage, key: 'err.timeout');
    } catch (_) {
      throw ApiException(_networkMessage, key: 'err.network');
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    // bodyBytes + utf8 so non-ASCII characters in reports are not garbled
    final text = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      return jsonDecode(text) as Map<String, dynamic>;
    }

    // FastAPI errors look like {"detail": "message"}
    // A "detail" text comes from the server and stays in English.
    String message = 'Server error (${response.statusCode}). Please try again.';
    String? key = 'err.server';
    String suffix = ' (${response.statusCode})';
    try {
      final body = jsonDecode(text);
      if (body is Map && body['detail'] is String) {
        message = body['detail'] as String;
        key = null;
      } else if (body is Map && body['detail'] is List) {
        message = 'The request was not valid. Please check your input.';
        key = 'err.invalid';
        suffix = '';
      }
    } catch (_) {}
    throw ApiException(message, key: key, suffix: suffix);
  }
}
