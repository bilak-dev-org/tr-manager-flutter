part of 'package:translations_service_integration/main.dart';

bool _isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);

    // Check if scheme is http or https and host is not empty
    if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    // Uri.parse throws if URL is invalid
    return false;
  }
}

class _TranslationsIntegrationException implements Exception {
  final String message;

  const _TranslationsIntegrationException(this.message);

  @override
  String toString() => 'TranslationsIntegrationException: $message';
}

/// Compares two version strings and returns:
/// -1 if version1 < version2
/// 0 if version1 == version2
/// 1 if version1 > version2
int _compareVersions(String version1, String version2) {
  List<int> v1Parts = version1.split('.').map((e) => int.parse(e)).toList();
  List<int> v2Parts = version2.split('.').map((e) => int.parse(e)).toList();

  // Pad shorter version with zeros
  int maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
  while (v1Parts.length < maxLength) v1Parts.add(0);
  while (v2Parts.length < maxLength) v2Parts.add(0);

  for (int i = 0; i < maxLength; i++) {
    if (v1Parts[i] < v2Parts[i]) return -1;
    if (v1Parts[i] > v2Parts[i]) return 1;
  }
  return 0;
}

/// Finds the most suitable previous version from available versions
/// Returns null if no suitable version is found
Future<String> _findMostSuitableVersion(List<String> availableVersions) async {
  if (availableVersions.length == 1) {
    return availableVersions.first;
  }
  // Get current app version
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final String currentVersion = packageInfo.version;

  // Filter versions that are less than current version
  final List<String> previousVersions = availableVersions
      .where((version) => _compareVersions(version, currentVersion) < 0)
      .toList();
  if (previousVersions.isEmpty) {
    throw _TranslationsIntegrationException('No previous versions found, current: $currentVersion');
  }

  // Sort in descending order and return the highest previous version
  previousVersions.sort((a, b) => _compareVersions(b, a));
  return previousVersions.first;
}

void _print(String message) {
  debugPrint('[TranslationsService] $message');
}

void _debugLog(String message) {
  if (TranslationsService.enableDebugLogs) {
    debugPrint(message);
  }
}

extension Let<T> on T {
  R? let<R>(R? Function(T it) op) => op(this);
}
