abstract interface class StorageAdapter {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
}
