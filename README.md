# Translations Service

A Flutter package for managing remote translations with caching, fallback support, and automatic language selection.

## Features

- **Remote translations loading** from AWS S3 or any HTTP endpoint
- **Intelligent caching** with HTTP cache support
- **Fallback translations** for offline or error scenarios
- **Automatic language selection** based on device locale
- **Persistent language preferences** using SharedPreferences
- **Version management** for translation updates
- **Network error handling** with graceful degradation

## Installation

Add the following dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  collection: ^1.17.0
  http: ^1.1.0
  http_cache_client: ^2.2.1
  http_cache_core: ^1.1.0
  http_cache_file_store: ^1.1.0
  package_info_plus: ^4.2.0
  shared_preferences: ^2.2.2
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
import 'package:your_package/translations_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize with fallback translations for offline support
  await TranslationsService.init(
    baseUrl: 'https://your-s3-bucket.amazonaws.com/translations',
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

## Usage

### Basic Usage

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, String> translations = {};
  
  @override
  void initState() {
    super.initState();
    _loadCurrentTranslations();
  }
  
  void _loadCurrentTranslations() {
    setState(() {
      translations = TranslationsService.instance.currentTranslations;
    });
  }
  
  @override
  Widget build(BuildContext context) {
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
                  final trans = await TranslationsService.instance.selectLanguage(language);
                  setState(() {
                    translations = trans;
                  });
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

### Check Initialization Status

```dart
final service = TranslationsService.instance;

if (service.initializedSuccessfully) {
  print('Service initialized with remote data');
  print('Using version: ${service.selectedVersion}');
} else {
  print('Service using fallback data (offline or error)');
  // You might want to retry initialization later
  // await TranslationsService.init(baseUrl: baseUrl, fallbackTranslations: fallback);
}
```

### Language Selection

```dart
final service = TranslationsService.instance;

// Get available languages
List<Language> availableLanguages = service.languages;

// Get currently selected language (guaranteed to be non-null)
Language currentLanguage = service.selectedLanguage;

// Select best language based on device locale
Language bestLanguage = service.selectBestLanguage(
  fallback: const Language('English', 'en'),
);

// Manually select a language
Map<String, String> translations = await service.selectLanguage(
  const Language('Español', 'es'),
);
```

## API Reference

### TranslationsService

#### Static Methods

- `static Future<void> init({required String baseUrl, Map<Language, Map<String, String>> fallbackTranslations})`
    - Initializes the service with remote URL and fallback data

#### Instance Properties

- `List<Language> get languages` - Available languages
- `Map<String, string> get currentTranslations` - Translations for selected language
- `Language get selectedLanguage` - Currently selected language (never null after initialization)
- `String get selectedVersion` - Remote version being used
- `bool get initializedSuccessfully` - Whether initialization succeeded

#### Instance Methods

- `Future<Map<String, String>> selectLanguage(Language language)`
    - Selects and loads translations for a language
- `Language selectBestLanguage({Language? fallback})`
    - Finds best language match based on device locale

### Language Class

```dart
class Language {
  final String name;    // Display name (e.g., "English")
  final String code;    // Language code (e.g., "en")
  
  const Language(this.name, this.code);
}
```

## Caching

The package uses HTTP caching with the following features:

- **File-based cache** stored locally
- **Refresh policy** - Always tries to get fresh data but falls back to cache
- **Network failure handling** - Returns cached data on network errors
- **Error code handling** - Returns cached data on 403/500 errors
- **No expiration** - Cached data never expires (relies on version changes)

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
3. **Cache translation maps** in your app state management solution
4. **Test offline scenarios** to ensure fallback translations work
5. **Use semantic versioning** for your translation versions
6. **Implement retry logic** for network failures

## Contributing

When contributing to this package:

1. Ensure all translation files follow the same JSON structure
2. Test both online and offline scenarios
3. Verify caching behavior
4. Update version numbers appropriately
5. Test with different device locales
6. 