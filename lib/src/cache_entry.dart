part of 'package:translations_service_integration/main.dart';

/// Represents a cached HTTP response with ETag support
class CacheEntry {
  /// The ETag value from the server's response headers
  final String etag;

  /// The raw response body data
  final String data;

  const CacheEntry({required this.etag, required this.data});

  /// Creates a CacheEntry from JSON
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(etag: json['etag'] as String, data: json['data'] as String);
  }

  /// Converts this CacheEntry to JSON
  Map<String, dynamic> toJson() {
    return {'etag': etag, 'data': data};
  }

  /// Decodes a CacheEntry from a JSON string
  static CacheEntry fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return CacheEntry.fromJson(json);
  }

  /// Encodes this CacheEntry to a JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
