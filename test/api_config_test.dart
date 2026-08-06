import 'package:flutter_test/flutter_test.dart';
import 'package:food_ai_app/config/api_config.dart';

void main() {
  test('uses the deployed Render service by default', () {
    expect(ApiConfig.defaultBaseUrl, 'https://food-ai-app-332i.onrender.com');
  });

  group('ApiConfig.buildUri', () {
    test('removes a trailing slash and a leading path slash', () {
      final uri = ApiConfig.buildUri('https://example.com/', '/health');
      expect(uri.toString(), 'https://example.com/health');
    });

    test('adds exactly one slash when both sides omit it', () {
      final uri = ApiConfig.buildUri('https://example.com', 'api/analyze-meal');
      expect(uri.toString(), 'https://example.com/api/analyze-meal');
    });

    test('rejects a cleartext backend address', () {
      expect(
        () => ApiConfig.normalizeBaseUrl('http://example.com'),
        throwsFormatException,
      );
    });
  });
}
