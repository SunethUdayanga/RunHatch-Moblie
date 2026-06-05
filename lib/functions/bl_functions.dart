import 'package:shared_preferences/shared_preferences.dart';

class HutchSettings {
  const HutchSettings({
    required this.url,
    required this.intervalSeconds,
  });

  final String url;
  final int intervalSeconds;
}

class ServiceStatus {
  const ServiceStatus({
    required this.isActive,
    required this.requestCount,
    this.lastStatus,
  });

  final bool isActive;
  final int requestCount;
  final String? lastStatus;
}

class BlFunctions {
  BlFunctions._();

  static const String defaultUrl =
      'https://selfcare.hutch.lk/selfcare/login.html';
  static const int defaultIntervalSeconds = 30;

  static const String _urlKey = 'hutch_request_url';
  static const String _intervalKey = 'hutch_request_interval';
  static const String _serviceActiveKey = 'hutch_service_active';
  static const String _requestCountKey = 'hutch_request_count';
  static const String _lastStatusKey = 'hutch_last_status';

  static Future<HutchSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return HutchSettings(
      url: prefs.getString(_urlKey) ?? defaultUrl,
      intervalSeconds:
          prefs.getInt(_intervalKey) ?? defaultIntervalSeconds,
    );
  }

  static Future<void> saveSettings({
    required String url,
    required int intervalSeconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url.trim());
    await prefs.setInt(_intervalKey, intervalSeconds);
  }

  static Future<ServiceStatus> loadServiceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return ServiceStatus(
      isActive: prefs.getBool(_serviceActiveKey) ?? false,
      requestCount: prefs.getInt(_requestCountKey) ?? 0,
      lastStatus: prefs.getString(_lastStatusKey),
    );
  }

  static Future<void> saveServiceStatus({
    required bool isActive,
    required int requestCount,
    String? lastStatus,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceActiveKey, isActive);
    await prefs.setInt(_requestCountKey, requestCount);
    if (lastStatus != null) {
      await prefs.setString(_lastStatusKey, lastStatus);
    }
  }

  static Future<void> resetServiceStatus() async {
    await saveServiceStatus(
      isActive: true,
      requestCount: 0,
      lastStatus: 'Starting...',
    );
  }

  static String normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return defaultUrl;
    }
    return trimmed;
  }
}
