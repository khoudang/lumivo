// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'storage_adapter.dart';

class StorageAdapterImpl implements StorageAdapter {
  @override
  Future<String?> getString(String key) async {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    try {
      html.window.localStorage.remove(key);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      html.window.localStorage.clear();
    } catch (_) {}
  }
}

StorageAdapter createStorageAdapter() => StorageAdapterImpl();
