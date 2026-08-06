const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://desktop-hong-home.tail5a779f.ts.net',
);

class ApiConfig {
  const ApiConfig._();

  static String get defaultBaseUrl => normalizeBaseUrl(apiBaseUrl);

  static String normalizeBaseUrl(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);

    if (normalized.isEmpty ||
        uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('https://로 시작하는 올바른 백엔드 주소를 입력해주세요.');
    }

    return normalized;
  }

  static Uri buildUri(String baseUrl, String path) {
    final normalizedBaseUrl = normalizeBaseUrl(baseUrl);
    final normalizedPath = path.trim().replaceFirst(RegExp(r'^/+'), '');
    if (normalizedPath.isEmpty) return Uri.parse(normalizedBaseUrl);
    return Uri.parse('$normalizedBaseUrl/$normalizedPath');
  }
}
