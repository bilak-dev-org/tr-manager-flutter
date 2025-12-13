part of 'package:translations_service_integration/main.dart';

/// HTTP client with ETag-based caching support
///
/// This client automatically handles HTTP caching using ETags and the
/// If-None-Match header. When a resource is requested:
/// 1. If cached, sends If-None-Match header with the stored ETag
/// 2. On 304 response, returns cached data
/// 3. On 200 response, updates cache atomically
/// 4. Corrupted cache files are automatically deleted and refetched
class EtagCacheClient {
  final http.Client _httpClient = http.Client();
  final Directory _cacheDirectory;

  EtagCacheClient._internal(this._cacheDirectory);

  /// Creates an EtagCacheClient with cache directory from path_provider
  static Future<EtagCacheClient> create() async {
    final appCacheDir = await getApplicationCacheDirectory();
    final cacheDir = Directory('${appCacheDir.path}/translations_service_cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return EtagCacheClient._internal(cacheDir);
  }

  /// Converts a URL to a valid cache filename using SHA256 hash
  String _urlToFilename(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Returns the cache file for the given URL
  File _getCacheFile(String url) {
    final filename = _urlToFilename(url);
    return File('${_cacheDirectory.path}/$filename');
  }

  /// Returns the temporary file path for atomic writes
  File _getTempFile(String url) {
    final filename = _urlToFilename(url);
    return File('${_cacheDirectory.path}/$filename.tmp');
  }

  /// Checks if a cache entry exists for the given URL
  bool cacheExists(String url) {
    final file = _getCacheFile(url);
    return file.existsSync();
  }

  /// Loads a cache entry from disk
  ///
  /// Returns null if cache doesn't exist or is corrupted
  CacheEntry? _loadCache(String url) {
    try {
      final file = _getCacheFile(url);
      if (!file.existsSync()) {
        return null;
      }

      final contents = file.readAsStringSync();
      return CacheEntry.fromJsonString(contents);
    } catch (e) {
      // Corrupted cache - delete it
      _debugLog('[EtagCache] Corrupted cache detected for $url, deleting and will refetch (Error: $e)');
      try {
        _getCacheFile(url).deleteSync();
      } catch (_) {
        // Ignore deletion errors
      }
      return null;
    }
  }

  /// Saves a cache entry to disk atomically
  ///
  /// Writes to a temporary file first, then renames to ensure atomicity
  void _saveCache(String url, CacheEntry entry) {
    try {
      final tempFile = _getTempFile(url);
      final cacheFile = _getCacheFile(url);

      // Write to temp file
      tempFile.writeAsStringSync(entry.toJsonString());

      // Atomic rename
      tempFile.renameSync(cacheFile.path);
    } catch (e) {
      // Clean up temp file if it exists
      try {
        _getTempFile(url).deleteSync();
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  /// Performs an HTTP GET request with ETag caching
  ///
  /// Flow:
  /// 1. Check if cache exists, load ETag if present
  /// 2. Make HTTP request with If-None-Match header (if ETag available)
  /// 3. On 304 Not Modified: return cached data
  /// 4. On 200 OK: save new data and ETag to cache, return data
  /// 5. On other status codes: throw HttpException
  ///
  /// If cache is corrupted, it's automatically deleted and data is refetched
  Future<String> get(String url) async {
    // Try to load existing cache
    final cachedEntry = _loadCache(url);

    if (cachedEntry != null) {
      _debugLog('[EtagCache] Cache found for $url (ETag: ${cachedEntry.etag})');
    } else {
      _debugLog('[EtagCache] No cache found for $url, fetching fresh data');
    }

    // Prepare headers
    final headers = <String, String>{};
    if (cachedEntry != null) {
      headers['If-None-Match'] = cachedEntry.etag;
    }

    // Make HTTP request
    http.Response response;
    try {
      response = await _httpClient.get(Uri.parse(url), headers: headers);
    } catch (e) {
      if (cachedEntry == null) {
        _print('[EtagCache] Connection error and no cache found for $url');
        rethrow;
      } else {
        _print('[EtagCache] Connection error but cache found for $url');
        return cachedEntry.data;
      }
    }

    // Handle 304 Not Modified - use cache
    if (response.statusCode == 304) {
      _debugLog('[EtagCache] 304 Not Modified - cache is up to date for $url');
      if (cachedEntry != null) {
        return cachedEntry.data;
      }
      // This shouldn't happen (server sent 304 but we have no cache)
      // Fall through to refetch without If-None-Match
      _debugLog('[EtagCache] WARNING: Server sent 304 but no cache exists, refetching');
      return get(url);
    }

    // Handle 200 OK - update cache
    if (response.statusCode == 200) {
      final etag = response.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        _debugLog(
          '[EtagCache] 200 OK - ${cachedEntry != null ? 'updating' : 'creating'} cache for $url (New ETag: $etag)',
        );
        final entry = CacheEntry(etag: etag, data: response.body);
        _saveCache(url, entry);
      } else {
        _debugLog('[EtagCache] 200 OK - no ETag header from server for $url, not caching');
      }
      return response.body;
    }

    // Handle other status codes
    throw HttpException('HTTP request failed with status ${response.statusCode}', uri: Uri.parse(url));
  }

  /// Clears all cached entries
  void clearCache() {
    try {
      if (_cacheDirectory.existsSync()) {
        final files = _cacheDirectory.listSync();
        for (final file in files) {
          if (file is File) {
            try {
              file.deleteSync();
            } catch (_) {
              // Ignore individual file deletion errors
            }
          }
        }
      }
    } catch (_) {
      // Ignore cache clear errors
    }
  }

  /// Removes a specific cached entry for the given URL
  void removeCache(String url) {
    try {
      final file = _getCacheFile(url);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Ignore deletion errors
    }
  }

  /// Closes the underlying HTTP client
  void close() {
    _httpClient.close();
  }
}
