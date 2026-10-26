/// Utility for identifying and scrubbing sensitive secrets and credentials
/// across Lumivo persistence, backup export, and memory models.
class SecretSanitizer {
  const SecretSanitizer._();

  static const Set<String> _sensitiveTokens = {
    'wifipassword',
    'wifipass',
    'password',
    'passphrase',
    'authtoken',
    'accesstoken',
    'refreshtoken',
    'apikey',
    'privatekey',
    'secret',
    'credential',
    'authcode',
  };

  /// Returns true if [key] contains sensitive keywords or tokens.
  static bool isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    final normalized = lower.replaceAll(RegExp(r'[-_\s]'), '');
    for (final token in _sensitiveTokens) {
      if (normalized.contains(token) || lower.contains(token)) {
        return true;
      }
    }
    // Also catch 'token' and 'auth' patterns
    if (lower.contains('token') || lower.contains('auth')) {
      return true;
    }
    return false;
  }

  /// Deeply sanitizes [value] by recursively removing sensitive keys from
  /// nested Maps and Lists of Maps.
  static dynamic sanitizeValue(dynamic value) {
    if (value is Map) {
      return sanitizeMap(Map<String, dynamic>.from(value));
    } else if (value is List) {
      return value.map(sanitizeValue).toList();
    }
    return value;
  }

  /// Deeply sanitizes [source] by recursively removing sensitive keys and
  /// sanitizing nested data structures.
  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      if (isSensitiveKey(entry.key)) {
        continue;
      }
      result[entry.key] = sanitizeValue(entry.value);
    }
    return result;
  }
}
