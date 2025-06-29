// lib/core/storage/local_storage.dart
class LocalStorage {
  static Future<void> save(String key, dynamic value) async {
    await _box.put(key, value);
  }
}
