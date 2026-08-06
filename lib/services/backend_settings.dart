import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class BackendSettings extends ChangeNotifier {
  BackendSettings._();

  static final BackendSettings instance = BackendSettings._();
  static const String _storageKey = 'backend_base_url_v2';

  String _baseUrl = ApiConfig.defaultBaseUrl;

  String get baseUrl => _baseUrl;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedValue = preferences.getString(_storageKey);
    if (savedValue == null) return;

    try {
      final normalized = ApiConfig.normalizeBaseUrl(savedValue);
      final host = Uri.parse(normalized).host.toLowerCase();
      final isLegacyTunnel =
          host.endsWith('.trycloudflare.com') || host.endsWith('.ts.net');
      if (isLegacyTunnel) {
        await preferences.remove(_storageKey);
        _baseUrl = ApiConfig.defaultBaseUrl;
      } else {
        _baseUrl = normalized;
      }
    } on FormatException {
      await preferences.remove(_storageKey);
      _baseUrl = ApiConfig.defaultBaseUrl;
    }
  }

  Future<String> save(String value) async {
    final normalized = ApiConfig.normalizeBaseUrl(value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, normalized);
    _baseUrl = normalized;
    notifyListeners();
    return normalized;
  }

  Future<String> reset() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    _baseUrl = ApiConfig.defaultBaseUrl;
    notifyListeners();
    return _baseUrl;
  }
}
