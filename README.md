# Translations Service

A Flutter package for managing remote translations with caching, fallback support, and automatic language selection.

## Features

- **Remote translations loading** from AWS S3 or any HTTP endpoint
- **ETag-based HTTP caching** with automatic validation and no unnecessary downloads
- **Fallback translations** for offline or error scenarios
- **Automatic language selection** based on device locale
- **Persistent language preferences** using SharedPreferences
- **Version management** for translation updates
- **Network error handling** with graceful degradation
- **Debug logging** to monitor cache operations

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  translations_service_integration:
    git:
      url: https://x-token-auth:ATCTT3xFfGN07-cOQ92Kwl3zUdyVcKw-8o3THCuc3ddrlxElncQiOMomlP6LTYxE7RQW-ew7v4EJaOr490WegvbhpxqlbAU6KOWiEZykAVSMtzVgcdbtlaI7U146t23P7K7wyX4y1fjKQMdhZCXBfaDe08CbHAoqD5LQoLSMdHRS0qbEaFexw94=47853FD0@bitbucket.org/serge_b/translations_manager-flutter.git
      ref: ca31e71d52cf1fc0867daae896483cd995011581
```

## Setup

### 1. Remote Structure

Your remote translations should be organized as follows:

```
your-base-url/
├── versions.json              # List of available versions
└── v1.0.0/                   # Version directory
    ├── info.json             # Available languages mapping
    ├── en.json               # English translations
    ├── es.json               # Spanish translations
    └── fr.json               # French translations
```

**versions.json** example:
```json
["v1.0.0", "v1.1.0", "v2.0.0"]
```

**info.json** example:
```json
{
  "en": "English",
  "es": "Español", 
  "fr": "Français"
}
```

**Translation files** (e.g., en.json):
```json
{
  "hello": "Hello",
  "welcome": "Welcome to our app",
  "settings": "Settings"
}
```

### 2. Initialize the Service

```dart
import 'package:translations_service_integration/main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set base URL first (replace {projectId} with your actual project ID)
  TranslationsService.baseUrl = 'https://lemon-translations-service.s3.eu-north-1.amazonaws.com/{projectId}/';

  // Then initialize with fallback translations for offline support
  // The service will automatically:
  // - Select the best language based on device locale
  // - Store the selected language in SharedPreferences
  // - Load translations for that language
  await TranslationsService.init(
    fallbackTranslations: {
      const Language('English', 'en'): {
        'hello': 'Hello',
        'welcome': 'Welcome to our app',
      },
      const Language('Español', 'es'): {
        'hello': 'Hola',
        'welcome': 'Bienvenido a nuestra aplicación',
      },
    },
  );

  runApp(MyApp());
}
```

## Debug Logging

Control cache operation logging via the `enableDebugLogs` static field. This is useful for debugging cache behavior and understanding when data is fetched from the network vs. cache.

```dart
// Defaults to kDebugMode (logs in debug builds only)
TranslationsService.enableDebugLogs = true;  // Always log
TranslationsService.enableDebugLogs = false; // Never log

// Set before calling init() to see initialization logs
TranslationsService.enableDebugLogs = true;
await TranslationsService.init(...);
```

**Example log output:**

```
[EtagCache] No cache found for https://example.com/v1.0.0/en.json, fetching fresh data
[EtagCache] 200 OK - creating cache for https://example.com/v1.0.0/en.json (New ETag: "abc123")
[EtagCache] Cache found for https://example.com/v1.0.0/en.json (ETag: "abc123")
[EtagCache] 304 Not Modified - cache is up to date for https://example.com/v1.0.0/en.json
[EtagCache] Corrupted cache detected for https://example.com/v1.0.0/fr.json, deleting and will refetch
```

## Usage

### Basic Usage

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final translations = TranslationsService.instance.currentTranslations;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(translations['welcome'] ?? 'Welcome'),
        ),
        body: Column(
          children: [
            Text(translations['hello'] ?? 'Hello'),
            // Language selector
            DropdownButton<Language>(
              value: TranslationsService.instance.selectedLanguage,
              items: TranslationsService.instance.languages.map((lang) {
                return DropdownMenuItem(
                  value: lang,
                  child: Text(lang.name),
                );
              }).toList(),
              onChanged: (Language? language) async {
                if (language != null) {
                  await TranslationsService.instance.selectLanguage(language);
                  // Note: This widget won't rebuild automatically
                  // You need to either:
                  // 1. Convert to StatefulWidget and use setState()
                  // 2. Use the Riverpod integration pattern (see below) for automatic rebuilds
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

**Note:** For reactive UI updates on language change, use the Riverpod integration pattern shown below.

### Check Initialization Status

```dart
final service = TranslationsService.instance;

if (service.initializedSuccessfully) {
  print('Service initialized with remote data');
  print('Using version: ${service.selectedVersion}');
} else {
  print('Service using fallback data (offline or error)');
  // You might want to retry initialization later
  // TranslationsService.baseUrl = 'your-url';
  // await TranslationsService.init(fallbackTranslations: fallback);
}
```

### Language Selection

```dart
final service = TranslationsService.instance;

// Get available languages
List<Language> availableLanguages = service.languages;

// Get currently selected language (guaranteed to be non-null)
// Note: Language is automatically selected during init() based on device locale
// and stored in SharedPreferences for persistence across app restarts
Language currentLanguage = service.selectedLanguage;

// Manually select a language (this also stores the selection)
Map<String, String> translations = await service.selectLanguage(
  const Language('Español', 'es'),
);

// Optionally, you can manually call selectBestLanguage if needed
// (though this is already called automatically during init())
Language bestLanguage = service.selectBestLanguage(
  fallback: const Language('English', 'en'),
);
```

### Riverpod Integration

For reactive UI updates when the language changes, integrate with Riverpod using a listener pattern:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translations_service_integration/main.dart';

/// State holding current language and translations
class LocalizationState {
  final Language language;
  final Map<String, String> translations;

  const LocalizationState({required this.language, required this.translations});
}

/// Provider that exposes current translations and rebuilds widgets on language change
final localizationProvider = StateNotifierProvider<LocalizationNotifier, LocalizationState>(
  (ref) => LocalizationNotifier(),
);

class LocalizationNotifier extends StateNotifier<LocalizationState> {
  VoidCallback? _removeListener;

  LocalizationNotifier()
      : super(
          LocalizationState(
            language: TranslationsService.instance.selectedLanguage,
            translations: TranslationsService.instance.currentTranslations,
          ),
        ) {
    // Listen to language changes from TranslationsService
    _removeListener = TranslationsService.addListener((language, translations) {
      state = LocalizationState(language: language, translations: translations);
    });
  }

  @override
  void dispose() {
    _removeListener?.call();
    super.dispose();
  }
}

/// Extension on String for easy translation access
extension StringLocalization on String {
  /// Get translation for this key
  /// Usage: "welcome_message".tr(ref)
  /// With replacements: "greeting".tr(ref, replace: {"name": "John"})
  String tr(WidgetRef ref, {Map<String, String> replace = const {}}) {
    final translations = ref.watch(localizationProvider).translations;
    var translation = translations[this] ?? '[$this]';

    // Replace all {{key}} patterns with values from replace map
    replace.forEach((key, value) {
      translation = translation.replaceAll('{{$key}}', value);
    });

    return translation;
  }
}
```

**Usage with Riverpod:**

```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('welcome'.tr(ref)),
        ),
        body: Column(
          children: [
            Text('hello'.tr(ref)),
            // With replacements
            Text('greeting'.tr(ref, replace: {'name': 'John'})),
            // Language selector
            DropdownButton<Language>(
              value: ref.watch(localizationProvider).language,
              items: TranslationsService.instance.languages.map((lang) {
                return DropdownMenuItem(
                  value: lang,
                  child: Text(lang.name),
                );
              }).toList(),
              onChanged: (Language? language) async {
                if (language != null) {
                  await TranslationsService.instance.selectLanguage(language);
                  // UI rebuilds automatically via localizationProvider
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

### System Localization (Calendar, Date Pickers, etc.)

To make calendar and other system widgets work with the selected language, add `flutter_localizations` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
```

Then update your MaterialApp:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationProvider);

    return MaterialApp(
      locale: Locale(localization.language.code),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: TranslationsService.instance.languages
          .map((lang) => Locale(lang.code))
          .toList(),
      home: Scaffold(
        // Your app content
      ),
    );
  }
}
```

## API Reference

### TranslationsService

#### Static Properties

- `static String? baseUrl` - Base URL for translations (must be set before calling `init()`)
- `static bool enableDebugLogs` - Enable/disable debug logging for cache operations (defaults to `kDebugMode`)

#### Static Methods

- `static Future<void> init({Map<Language, Map<String, String>> fallbackTranslations = const {}})`
    - Initializes the service with fallback data
    - Note: Set `baseUrl` property before calling this method
    - Automatically calls `selectBestLanguage()` based on device locale
    - Stores the selected language in SharedPreferences for persistence
- `static VoidCallback addListener(LanguageUpdateListener listener)`
    - Adds a listener that will be called when language changes
    - Returns a `VoidCallback` to remove the listener
    - Listener signature: `void Function(Language language, Map<String, String> translations)`

#### Instance Properties

- `List<Language> get languages` - Available languages
- `Map<String, String> get currentTranslations` - Translations for selected language
- `Language get selectedLanguage` - Currently selected language (never null after initialization)
- `String get selectedVersion` - Remote version being used
- `bool get initializedSuccessfully` - Whether initialization succeeded

#### Instance Methods

- `Future<Map<String, String>> selectLanguage(Language language)`
    - Selects and loads translations for a language
    - Stores the selection in SharedPreferences
    - Notifies all registered listeners
- `Language selectBestLanguage({Language? fallback})`
    - Finds best language match based on device locale
    - Note: Called automatically during `init()`, typically no need to call manually

### Language Class

```dart
class Language {
  final String name;    // Display name (e.g., "English")
  final String code;    // Language code (e.g., "en")
  
  const Language(this.name, this.code);
}
```

## Caching

The package uses **ETag-based HTTP caching** for efficient bandwidth usage and fast loading. Here's how it works:

### How ETag Caching Works

1. **First Request**: When fetching a file for the first time:
   - Makes HTTP GET request to server
   - Server responds with `200 OK` and includes an `ETag` header (e.g., `"abc123"`)
   - Response body and ETag are saved to cache

2. **Subsequent Requests**: When fetching the same file again:
   - Loads ETag from cache
   - Makes HTTP GET request with `If-None-Match: "abc123"` header
   - Server checks if file changed:
     - **304 Not Modified**: File unchanged → returns cached data (no download!)
     - **200 OK**: File changed → downloads new data, updates cache with new ETag

### Cache Storage

- **Location**: `<app_cache_dir>/translations_service_cache/`
  - iOS: `Library/Caches/translations_service_cache/`
  - Android: `/data/data/{package}/cache/translations_service_cache/`
- **Filename**: SHA256 hash of the URL (e.g., `a3f5b2c1...`)
- **Format**: JSON with `etag` and `data` fields

### Cache Features

- **Atomic writes**: Uses temporary files then renames to prevent corruption
- **Corruption recovery**: Automatically detects and deletes corrupted cache files
- **No expiration**: Cache never expires (relies on ETag validation)
- **Organized storage**: Dedicated subdirectory prevents conflicts with other app cache

## Error Handling

The service gracefully handles various error scenarios:

1. **Network unavailable during init**: Falls back to provided fallback translations
2. **Invalid URLs**: Throws `_TranslationsIntegrationException`
3. **Missing translations**: Throws exception when selecting unavailable language
4. **Server errors**: Returns cached data if available

## Version Management

The service automatically selects the most suitable version from the `versions.json` file.

## Best Practices

1. **Always provide fallback translations** for critical app strings
2. **Handle initialization errors** gracefully in your UI
3. **Test offline scenarios** to ensure fallback translations work
4. **Use semantic versioning** for your translation versions
5. **Implement retry logic** for network failures
6. **Use Riverpod or similar state management** to automatically rebuild UI when language changes