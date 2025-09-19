import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_cache_client/http_cache_client.dart';
import 'package:http_cache_core/http_cache_core.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'utils.dart';

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);

  @override
  bool operator ==(Object other) => other is Language && other.code == code && other.name == name;

  @override
  int get hashCode => Object.hash(name, code);

  @override
  String toString() => 'Language(code: $code, name: $name)';
}

abstract class TranslationsService {
  static const _languageStorageKey = 'translations_service_selected_language';

  static TranslationsService? _instance;
  static final CacheClient _httpClient = CacheClient(
    http.Client(),
    options: CacheOptions(
      store: FileCacheStore('translations_service'),
      policy: CachePolicy.refresh,
      // Return cached value on network error or offline
      hitCacheOnNetworkFailure: true,
      // Return cached value on 403 or 500 errors
      hitCacheOnErrorCodes: [403, 500],
      maxStale: null,
    ),
  );

  /// Path to project folder, ends with /
  final String baseUrl;

  /// Selected version from remote, empty on initialization error (typically network error)
  final String selectedVersion;

  /// Translations for available languages
  final Map<Language, Map<String, String>> _translations = {};

  TranslationsService._internal({required this.baseUrl, required this.selectedVersion});

  static TranslationsService get instance => _instance!;

  List<Language> get languages => _translations.keys.toList();

  Language get selectedLanguage;

  Map<String, String> get currentTranslations => {..._translations[selectedLanguage]!};

  /// Select a language, load translations and save into storage
  /// Saves into storage ONLY if translations were fetched successfully
  Future<Map<String, String>> selectLanguage(Language language);

  /// If false - [_translations] and [_languages] contain only fallback values provided to [init] function
  bool get initializedSuccessfully => selectedVersion.isNotEmpty;

  /// Determines the most suitable locale from available options
  /// based on the device's locale preferences.
  /// Will NOT save it anywhere, just return the best match
  Language selectBestLanguage({Language? fallback}) {
    fallback ??= _translations.keys.first;

    // Get device locales in order of preference
    final deviceLocales = PlatformDispatcher.instance.locales;

    // Try to find exact language code match in order of device preference
    for (final deviceLocale in deviceLocales) {
      final languageCode = deviceLocale.languageCode.toLowerCase();

      // Check for exact match
      final lang = _translations.keys.firstWhereOrNull((it) => it.code.toLowerCase() == languageCode);
      if (lang != null) {
        return lang;
      }
    }

    // If no exact match found, return fallback
    return fallback;
  }

  /// [baseUrl] aws bucket base url
  /// [fallbackTranslations] translations to use in case of network errors
  /// Call again if network was not available first time
  static Future<void> init({
    required String baseUrl,
    // Language code -> translations
    Map<Language, Map<String, String>> fallbackTranslations = const {},
  }) async {
    _print('Initializing...');
    if (!baseUrl.endsWith('/')) {
      baseUrl = "$baseUrl/";
    }
    if (!_isValidUrl(baseUrl)) {
      throw _TranslationsIntegrationException('Invalid URL: $baseUrl');
    }
    try {
      TranslationsService._instance = await NormalTranslationsService._initialize(baseUrl: baseUrl);
    } catch (e, stack) {
      _print('Initialization error: $e');
      debugPrintStack(stackTrace: stack);
      _print('Will use fallback data');
      _print('Try calling init() again after network is available');
      TranslationsService._instance = FallbackTranslationsService._internal(
        baseUrl: baseUrl,
        selectedVersion: "",
        fallbackTranslations: fallbackTranslations,
      );
    }
  }
}

class NormalTranslationsService extends TranslationsService {
  final SharedPreferences prefs;
  Language? _selectedLanguage;

  NormalTranslationsService._internal({
    required super.baseUrl,
    required super.selectedVersion,
    required this.prefs,
  }) : super._internal();

  @override
  Language get selectedLanguage => _selectedLanguage!;

  @override
  Future<Map<String, String>> selectLanguage(Language language) async {
    _print('Selected $language, initializing...');
    if (_translations.containsKey(language)) {
      return _translations[language]!;
    }
    final translations = await _fetchTranslations(language);
    _translations[language] = translations;
    await prefs.setString(TranslationsService._languageStorageKey, language.code);
    _print('$language loaded');
    return translations;
  }

  Future<void> _init() async {
    if (_selectedLanguage == null) {
      _selectedLanguage = selectBestLanguage();
      _print('No saved language found, chose $_selectedLanguage');
    }
    await selectLanguage(_selectedLanguage!);
  }

  /// Fetch translations from remote or cache
  Future<Map<String, String>> _fetchTranslations(Language language) async {
    final res = await TranslationsService._httpClient.get(
      Uri.parse('$baseUrl$selectedVersion/${language.code}.json'),
    );
    return (jsonDecode(res.body) as Map<dynamic, dynamic>).cast<String, String>();
  }

  /// Try to get all data from remote and return [TranslationsService] instance
  /// On fails use fallback data
  static Future<NormalTranslationsService> _initialize({required String baseUrl}) async {
    _print('Fetching versions...');
    final versions = await TranslationsService._httpClient
        .get(Uri.parse("$baseUrl/versions.json"))
        .then((it) => (jsonDecode(it.body) as List<dynamic>).map((it) => it.toString()).toList());
    final selectedVersion = await _findMostSuitableVersion(versions);
    _print('Selected version: $selectedVersion, all versions: $versions');

    _print('Fetching languages...');
    final languages = await TranslationsService._httpClient
        .get(Uri.parse('$baseUrl$selectedVersion/info.json'))
        .then((it) {
          return (jsonDecode(it.body) as Map<dynamic, dynamic>).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          );
        });
    _print('Found languages: $languages');

    final instance = NormalTranslationsService._internal(
      baseUrl: baseUrl,
      selectedVersion: selectedVersion,
      prefs: await SharedPreferences.getInstance(),
    );
    await instance._init();
    return instance;
  }
}

class FallbackTranslationsService extends TranslationsService {
  /// In-memory selected language (not persisted)
  Language? _selectedLanguage;

  FallbackTranslationsService._internal({
    required super.baseUrl,
    required super.selectedVersion,
    required Map<Language, Map<String, String>> fallbackTranslations,
  }) : super._internal() {
    _translations.addAll(fallbackTranslations);
    _selectedLanguage = selectBestLanguage(fallback: _translations.keys.first);
  }

  @override
  Language get selectedLanguage => _selectedLanguage!;

  @override
  bool get initializedSuccessfully => false;

  @override
  Future<Map<String, String>> selectLanguage(Language language) {
    _selectedLanguage = language;
    if (!_translations.containsKey(language)) {
      throw _TranslationsIntegrationException('Translations for $language not found');
    }
    return Future.value(_translations[language]!);
  }
}
