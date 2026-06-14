# BCP 47 Locale Resolution — Implementation Plan

## Goal

Upgrade language auto-selection from ISO 639-1 exact match to full BCP 47 resolution with CLDR parent traversal, sibling look-ahead, and a version-level default language fallback.

---

## Changes to `info.json` (server-side contract)

Add `defaultLanguage` field:
```json
{
  "languages": { "en": "English", "es-419": "Spanish (Latin America)" },
  "defaultLanguage": "en"
}
```

---

## File changes

### 1. New file: `lib/src/parent_locales.dart`

Embed `parentLocales.json` as a Dart `const Map<String, String>` so there is no asset I/O at runtime.

```dart
part of 'package:translations_service_integration/main.dart';

const _parentLocales = <String, String>{
  'en-150': 'en-001',
  'en-AG': 'en-001',
  // ... full contents of parentLocales.json ...
};
```

Add `part` directive in `main.dart`:
```dart
part 'package:translations_service_integration/src/parent_locales.dart';
```

---

### 2. `lib/main.dart` — core changes

#### 2a. `_languages` type: `Set<Language>` → `List<Language>`

Preserves server-defined order, which is used as tiebreaker in sibling scan.

Everywhere `_languages` is constructed (both service classes and `TranslationsService._internal`), switch to `List`.

#### 2b. Parse `defaultLanguage` from `info.json`

In `NormalTranslationsService._initialize()`:
```dart
final infoJson = jsonDecode(await _httpClient.get('$baseUrl$selectedVersion/info.json'))
    as Map<dynamic, dynamic>;

final languages = (infoJson['languages'] as Map<dynamic, dynamic>)
    .entries
    .map((e) => Language(e.value.toString(), e.key.toString()))
    .toList(); // List, not Set — preserves server order

final defaultLanguage = infoJson['defaultLanguage'] as String?;
```

Store `defaultLanguage` on `NormalTranslationsService` as `final String? defaultLanguage`.

#### 2c. New `resolve()` function (top-level or static)

```dart
/// Resolves a BCP 47 tag against a list of available languages.
/// Resolution order per tag:
///   1. Exact match (case-insensitive)
///   2. Walk CLDR parent chain (stop at "und" or no entry)
///   3. Sibling scan: available languages starting with tag + '-'
///   4. Strip last segment, recurse
/// Returns null if nothing found.
Language? _resolveLocale(String tag, List<Language> available) {
  final normalised = tag.toLowerCase();

  // 1. Exact match
  final exact = available.firstWhereOrNull(
    (l) => l.code.toLowerCase() == normalised,
  );
  if (exact != null) return exact;

  // 2. Parent chain
  String? current = normalised;
  final visited = <String>{};
  while (true) {
    final parent = _parentLocales[current]?.toLowerCase();
    if (parent == null || parent == 'und' || !visited.add(parent)) break;
    final parentMatch = available.firstWhereOrNull(
      (l) => l.code.toLowerCase() == parent,
    );
    if (parentMatch != null) return parentMatch;
    current = parent;
  }

  // 3. Sibling scan (prefix match at current truncation level)
  final prefix = '$normalised-';
  final sibling = available.firstWhereOrNull(
    (l) => l.code.toLowerCase().startsWith(prefix),
  );
  if (sibling != null) return sibling;

  // 4. Strip last segment and recurse
  final lastDash = normalised.lastIndexOf('-');
  if (lastDash == -1) return null;
  return _resolveLocale(normalised.substring(0, lastDash), available);
}
```

**Notes:**
- `available` is already in server-defined order → `firstWhereOrNull` on siblings gives deterministic, meaningful tiebreaking.
- `visited` set in parent chain guards against malformed data cycles.
- Case-insensitive throughout via `.toLowerCase()` normalisation.

#### 2d. Update `selectBestLanguage()`

```dart
Language selectBestLanguage({Language? fallback, String? defaultLanguage}) {
  // 1. Try each device locale through full resolution
  for (final locale in PlatformDispatcher.instance.locales) {
    final tag = locale.toLanguageTag(); // full BCP 47, e.g. "en-GB", "zh-Hant-HK"
    final resolved = _resolveLocale(tag, _languages);
    if (resolved != null) return resolved;
  }

  // 2. Empty locales or nothing matched — try version default
  if (defaultLanguage != null) {
    final resolved = _resolveLocale(defaultLanguage, _languages);
    if (resolved != null) return resolved;
  }

  // 3. Try English as universal fallback
  final en = _resolveLocale('en', _languages);
  if (en != null) return en;

  // 4. Absolute last resort
  return fallback ?? _languages.first;
}
```

#### 2e. Pass `defaultLanguage` into `selectBestLanguage()` calls

In `NormalTranslationsService._init()`:
```dart
_selectedLanguage = selectBestLanguage(defaultLanguage: defaultLanguage);
```

`FallbackTranslationsService` calls `selectBestLanguage()` without `defaultLanguage` (it never fetched `info.json`). No change needed there.

#### 2f. Saved language preference uses `resolve()` instead of exact match

In `NormalTranslationsService._init()`:
```dart
// Before: exact match only
_selectedLanguage = prefs.getString(_languageStorageKey)?.let((code) {
  return _languages.firstWhereOrNull((l) => l.code == code);
});

// After: full resolution on saved code
_selectedLanguage = prefs.getString(_languageStorageKey)?.let((code) {
  return _resolveLocale(code, _languages);
});
```

If the saved code (`es-MX`) is gone but a parent/sibling (`es-419`) exists, the preference is honoured rather than discarded.

---

## Resolution examples

| Device locale | Available languages | Result | Via |
|---|---|---|---|
| `es-MX` | `[es-419, es-ES]` | `es-419` | CLDR parent |
| `en-GB` | `[en-US, de-DE]` | `en-US` | Strip → sibling |
| `en-AT` | `[en-001, de-DE]` | `en-001` | CLDR chain (en-AT→en-150→en-001) |
| `zh-Hant-HK` | `[zh-Hant-TW, zh-Hans-CN]` | `zh-Hant-TW` | Strip to zh-Hant → sibling |
| `en` | `[en-GB, en-US]` | `en-GB` | Sibling (server order wins) |
| `uk-UA` | `[de-DE]` (default=`ru`, not avail.) | `de-DE` | en fallback → none → first |

---

## What does NOT change

- `FallbackTranslationsService` — no changes beyond inheriting the updated `selectBestLanguage()`.
- `EtagCacheClient`, `CacheEntry`, version selection logic — untouched.
- The `selectLanguage()` / `_fetchTranslations()` flow — untouched.
- Language codes stored in `SharedPreferences` — still written as-is (exact code the user selected).
