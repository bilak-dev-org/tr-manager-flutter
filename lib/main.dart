import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
part 'package:translations_service_integration/src/cache_entry.dart';
part 'package:translations_service_integration/src/etag_cache_client.dart';
part 'package:translations_service_integration/src/utils.dart';

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

typedef LanguageUpdateListener = dynamic Function(Language language, Map<String, String> translations);

abstract class TranslationsService {
  static const _languageStorageKey = 'translations_service_selected_language';

  /// Path to project folder, ends with /
  static String? baseUrl;

  /// Enable debug logging for cache operations. Defaults to kDebugMode.
  static bool enableDebugLogs = kDebugMode;

  static TranslationsService? _instance;

  static final Set<LanguageUpdateListener> _listeners = {};

  /// Add listener that will be called when language is changed
  /// Return [VoidCallback] to remove listener
  static VoidCallback addListener(LanguageUpdateListener listener) {
    _listeners.add(listener);

    return () => _listeners.remove(listener);
  }

  static void _notifyListeners() {
    for (var func in _listeners) {
      try {
        func(instance.selectedLanguage, instance.currentTranslations);
      } catch (e, stack) {
        _print('Error in listener callback: $e');
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  static TranslationsService get instance => _instance!;
  static late EtagCacheClient _httpClient;

  /// Selected version from remote, empty on initialization error (typically network error)
  final String selectedVersion;

  /// Translations for available languages
  final Map<Language, Map<String, String>> _translations = {};
  final Set<Language> _languages;

  TranslationsService._internal({required this.selectedVersion, required Set<Language> languages})
    : _languages = languages;

  List<Language> get languages => _languages.toList();

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
    fallback ??= _languages.first;

    // Get device locales in order of preference
    final deviceLocales = PlatformDispatcher.instance.locales;

    // Try to find exact language code match in order of device preference
    for (final deviceLocale in deviceLocales) {
      final languageCode = deviceLocale.languageCode.toLowerCase();

      // Check for exact match
      final lang = _languages.firstWhereOrNull((it) => it.code.toLowerCase() == languageCode);
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
    // Language code -> translations
    Map<Language, Map<String, String>> fallbackTranslations = const {},
  }) async {
    _print('Initializing...');
    _httpClient = await EtagCacheClient.create();
    if (baseUrl == null) {
      throw _TranslationsIntegrationException('Set baseUrl with [TranslationsService.baseUrl] first!');
    }
    if (!baseUrl!.endsWith('/')) {
      baseUrl = "$baseUrl/";
    }
    if (!_isValidUrl(baseUrl!)) {
      throw _TranslationsIntegrationException('Invalid URL: $baseUrl');
    }

    try {
      TranslationsService._instance = await NormalTranslationsService._initialize(baseUrl: baseUrl!);
    } catch (e, stack) {
      _print('Initialization error: $e');
      debugPrintStack(stackTrace: stack);
      _print('Will use fallback data');
      _print('Try calling init() again after network is available');
      TranslationsService._instance = FallbackTranslationsService._internal(
        selectedVersion: "",
        fallbackTranslations: fallbackTranslations,
        languages: fallbackTranslations.keys.toSet(),
      );
    }
  }
}

class NormalTranslationsService extends TranslationsService {
  final SharedPreferences prefs;
  Language? _selectedLanguage;

  NormalTranslationsService._internal({
    required super.selectedVersion,
    required this.prefs,
    required super.languages,
  }) : super._internal();

  @override
  Language get selectedLanguage => _selectedLanguage!;

  @override
  Future<Map<String, String>> selectLanguage(Language language) async {
    _print('Selected $language, initializing...');

    if (!_translations.containsKey(language)) {
      final translations = await _fetchTranslations(language);
      _translations[language] = translations;
      _print('$language loaded');
    } else {
      _print('Initialized $language from cache');
    }

    _selectedLanguage = language;
    await prefs.setString(TranslationsService._languageStorageKey, language.code);
    TranslationsService._notifyListeners();

    return _translations[language]!;
  }

  Future<void> _init() async {
    _selectedLanguage = prefs.getString(TranslationsService._languageStorageKey)?.let((code) {
      return _languages.firstWhereOrNull((lng) => lng.code == code);
    });
    if (_selectedLanguage == null) {
      _selectedLanguage = selectBestLanguage();
      _print('No saved language found, chose $_selectedLanguage');
    }
    await selectLanguage(_selectedLanguage!);
  }

  /// Fetch translations from remote or cache
  Future<Map<String, String>> _fetchTranslations(Language language) async {
    final url = '${TranslationsService.baseUrl}$selectedVersion/${language.code}.json';
    _print('Fetching $language from $url');
    final responseBody = await TranslationsService._httpClient.get(url);
    return (jsonDecode(responseBody) as Map<dynamic, dynamic>).cast<String, String>();
  }

  /// Try to get all data from remote and return [TranslationsService] instance
  /// On fails use fallback data
  static Future<NormalTranslationsService> _initialize({required String baseUrl}) async {
    _print('Fetching versions from ${baseUrl}versions.json ...');
    final versions = await TranslationsService._httpClient
        .get("${baseUrl}versions.json")
        .then((it) => (jsonDecode(it) as List<dynamic>).map((it) => it.toString()).toList());
    final selectedVersion = await _findMostSuitableVersion(versions);
    _print('Selected version: $selectedVersion, all versions: $versions');

    _print('Fetching languages...');
    final languages = await TranslationsService._httpClient.get('$baseUrl$selectedVersion/info.json').then((
      it,
    ) {
      return ((jsonDecode(it) as Map<dynamic, dynamic>)["languages"] as Map<dynamic, dynamic>).entries
          .map((entry) => Language(entry.value.toString(), entry.key.toString()))
          .toSet();
    });
    _print('Found languages: $languages');

    final instance = NormalTranslationsService._internal(
      selectedVersion: selectedVersion,
      prefs: await SharedPreferences.getInstance(),
      languages: languages,
    );
    await instance._init();
    return instance;
  }
}

class FallbackTranslationsService extends TranslationsService {
  /// In-memory selected language (not persisted)
  Language? _selectedLanguage;

  FallbackTranslationsService._internal({
    required super.selectedVersion,
    required Map<Language, Map<String, String>> fallbackTranslations,
    required super.languages,
  }) : super._internal() {
    _translations.addAll(fallbackTranslations);
    _selectedLanguage = selectBestLanguage(fallback: _languages.first);
  }

  @override
  Language get selectedLanguage => _selectedLanguage!;

  @override
  bool get initializedSuccessfully => false;

  @override
  Future<Map<String, String>> selectLanguage(Language language) {
    if (!_translations.containsKey(language)) {
      throw _TranslationsIntegrationException('Translations for $language not found');
    }
    _selectedLanguage = language;

    TranslationsService._notifyListeners();
    return Future.value(_translations[language]!);
  }
}
