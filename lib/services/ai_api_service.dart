import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/food_identification_result.dart';
import '../models/meal_analysis.dart';
import 'backend_settings.dart';

class AiApiService {
  const AiApiService._();

  static const AiApiService instance = AiApiService._();
  static const Duration _timeout = Duration(seconds: 120);
  static const int _maxImageBytes = 8 * 1024 * 1024;

  String get currentBaseUrl => BackendSettings.instance.baseUrl;

  Future<BackendHealth> checkHealth() async {
    final responseJson = await _requestJson('GET', '/health');
    if (responseJson['ok'] != true) {
      throw const AiApiException(
        AiApiErrorType.invalidResponse,
        detail: 'health 응답에 ok: true가 없습니다.',
      );
    }

    return BackendHealth(
      provider: responseJson['provider'] as String? ?? 'unknown',
      model: responseJson['model'] as String? ?? 'unknown',
      hasGeminiKey: responseJson['hasGeminiKey'] == true,
    );
  }

  Future<FoodIdentificationResult> identifyFoodCandidates(
    Uint8List? imageBytes,
  ) async {
    if (imageBytes == null || imageBytes.isEmpty) {
      return const FoodIdentificationResult();
    }
    _validateImageSize(imageBytes);

    final responseJson = await _postJson('/api/identify-food', {
      'imageBase64': base64Encode(imageBytes),
      'mimeType': 'image/jpeg',
    });
    _ensureGeminiResponse(responseJson);

    final rawCandidates = responseJson['candidates'];
    if (rawCandidates is! List) {
      throw const AiApiException(
        AiApiErrorType.invalidResponse,
        detail: 'candidates 목록이 없습니다.',
      );
    }

    final candidates = rawCandidates
        .whereType<String>()
        .map((candidate) => candidate.trim())
        .where((candidate) => candidate.isNotEmpty)
        .take(5)
        .toList();

    final profiles = <CalibrationProfileSummary>[];
    final rawProfiles = responseJson['profiles'];
    if (rawProfiles is List) {
      for (final rawProfile in rawProfiles.whereType<Map>()) {
        final profile = CalibrationProfileSummary.fromJson(
          Map<String, dynamic>.from(rawProfile),
        );
        if (profile.id.isNotEmpty && profile.name.isNotEmpty) {
          profiles.add(profile);
        }
      }
    }

    final rawSuggestedProfileId = responseJson['suggestedProfileId'];
    final suggestedProfileId =
        rawSuggestedProfileId is String &&
            rawSuggestedProfileId.trim().isNotEmpty
        ? rawSuggestedProfileId.trim()
        : null;

    return FoodIdentificationResult(
      candidates: candidates,
      profiles: profiles,
      suggestedProfileId: suggestedProfileId,
    );
  }

  Future<MealAnalysis> analyzeMeal({
    required String foodName,
    Uint8List? imageBytes,
    String? calibrationProfileId,
  }) async {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      _validateImageSize(imageBytes);
    }

    final responseJson = await _postJson('/api/analyze-meal', {
      'foodName': foodName,
      if (imageBytes != null && imageBytes.isNotEmpty)
        'imageBase64': base64Encode(imageBytes),
      if (imageBytes != null && imageBytes.isNotEmpty) 'mimeType': 'image/jpeg',
      if (calibrationProfileId != null &&
          calibrationProfileId.trim().isNotEmpty)
        'calibrationProfileId': calibrationProfileId.trim(),
    });
    _ensureGeminiResponse(responseJson);

    try {
      return MealAnalysis.fromJson(responseJson);
    } on Object catch (error) {
      throw AiApiException(
        AiApiErrorType.invalidResponse,
        detail: '분석 결과 구조를 읽을 수 없습니다: $error',
      );
    }
  }

  void _validateImageSize(Uint8List imageBytes) {
    if (imageBytes.lengthInBytes > _maxImageBytes) {
      throw const AiApiException(
        AiApiErrorType.imageTooLarge,
        detail: '이미지는 8MB 이하여야 합니다.',
      );
    }
  }

  void _ensureGeminiResponse(Map<String, dynamic> responseJson) {
    if (responseJson['source'] == 'mock') {
      throw const AiApiException(
        AiApiErrorType.gemini,
        detail: '백엔드가 Gemini 결과 대신 대체 응답을 반환했습니다.',
      );
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) {
    return _requestJson('POST', path, body: body);
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    final uri = ApiConfig.buildUri(currentBaseUrl, path);

    try {
      _debugRequest(method, uri, body);
      final request = method == 'GET'
          ? await client.getUrl(uri).timeout(_timeout)
          : await client.postUrl(uri).timeout(_timeout);

      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        final payload = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.contentLength = payload.length;
        request.add(payload);
      }

      final response = await request.close().timeout(_timeout);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);

      Object? decoded;
      try {
        decoded = responseBody.isEmpty ? null : jsonDecode(responseBody);
      } on FormatException {
        throw AiApiException(
          AiApiErrorType.invalidResponse,
          statusCode: response.statusCode,
          detail: '서버가 JSON이 아닌 응답을 반환했습니다.',
        );
      }

      _debugResponse(response.statusCode, responseBody.length, decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpException(response.statusCode, decoded);
      }
      if (decoded is! Map) {
        throw const AiApiException(
          AiApiErrorType.invalidResponse,
          detail: '서버 응답이 JSON 객체가 아닙니다.',
        );
      }

      return Map<String, dynamic>.from(decoded);
    } on AiApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw AiApiException(AiApiErrorType.timeout, detail: '$error');
    } on SocketException catch (error) {
      final lowerMessage = error.message.toLowerCase();
      final looksOffline =
          lowerMessage.contains('failed host lookup') ||
          lowerMessage.contains('network is unreachable') ||
          lowerMessage.contains('no address associated');
      throw AiApiException(
        looksOffline ? AiApiErrorType.internet : AiApiErrorType.backend,
        detail: error.message,
      );
    } on HandshakeException catch (error) {
      throw AiApiException(AiApiErrorType.backend, detail: error.message);
    } on HttpException catch (error) {
      throw AiApiException(AiApiErrorType.backend, detail: error.message);
    } on Object catch (error) {
      throw AiApiException(AiApiErrorType.backend, detail: '$error');
    } finally {
      client.close(force: true);
    }
  }

  AiApiException _httpException(int statusCode, Object? decoded) {
    var detail = '요청을 처리하지 못했습니다.';
    if (decoded is Map) {
      final error = decoded['error'];
      final serverDetail = decoded['detail'];
      detail = [error, serverDetail]
          .whereType<Object>()
          .map((value) => '$value'.trim())
          .where((value) => value.isNotEmpty)
          .join(' · ');
      if (detail.isEmpty) detail = '요청을 처리하지 못했습니다.';
    }

    final lowerDetail = detail.toLowerCase();
    if (statusCode == 413) {
      return AiApiException(
        AiApiErrorType.imageTooLarge,
        statusCode: statusCode,
        detail: detail,
      );
    }
    if (lowerDetail.contains('gemini')) {
      return AiApiException(
        AiApiErrorType.gemini,
        statusCode: statusCode,
        detail: detail,
      );
    }
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return AiApiException(
        AiApiErrorType.backend,
        statusCode: statusCode,
        detail: detail,
      );
    }
    return AiApiException(
      AiApiErrorType.http,
      statusCode: statusCode,
      detail: detail,
    );
  }

  void _debugRequest(String method, Uri uri, Map<String, dynamic>? body) {
    if (!kDebugMode) return;
    final keys = body?.keys.toList() ?? const <String>[];
    final imageLength = body?['imageBase64'] is String
        ? (body!['imageBase64'] as String).length
        : 0;
    debugPrint(
      '[AiApiService] request $method $uri keys=$keys '
      'encodedImageBytes=$imageLength (values redacted)',
    );
  }

  void _debugResponse(int statusCode, int byteLength, Object? decoded) {
    if (!kDebugMode) return;
    final keys = decoded is Map ? decoded.keys.toList() : const <Object>[];
    debugPrint(
      '[AiApiService] response status=$statusCode bytes=$byteLength keys=$keys',
    );
  }
}

class BackendHealth {
  const BackendHealth({
    required this.provider,
    required this.model,
    required this.hasGeminiKey,
  });

  final String provider;
  final String model;
  final bool hasGeminiKey;
}

enum AiApiErrorType {
  internet,
  backend,
  timeout,
  gemini,
  invalidResponse,
  imageTooLarge,
  http,
}

class AiApiException implements Exception {
  const AiApiException(this.type, {this.statusCode, this.detail});

  final AiApiErrorType type;
  final int? statusCode;
  final String? detail;

  String get title => switch (type) {
    AiApiErrorType.internet => '인터넷 연결 실패',
    AiApiErrorType.backend => '백엔드 서버 연결 실패',
    AiApiErrorType.timeout => '요청 시간 초과',
    AiApiErrorType.gemini => 'Gemini API 처리 실패',
    AiApiErrorType.invalidResponse => '잘못된 서버 응답',
    AiApiErrorType.imageTooLarge => '이미지 크기 초과',
    AiApiErrorType.http => 'HTTP 요청 실패',
  };

  String get displayMessage {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    final safeDetail = detail?.trim();
    if (safeDetail == null || safeDetail.isEmpty) return '$title$code';
    return '$title$code\n$safeDetail';
  }

  @override
  String toString() => displayMessage;
}
