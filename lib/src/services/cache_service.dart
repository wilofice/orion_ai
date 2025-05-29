import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String _boxName = 'orion_cache';

  Future<Box> _openBox() async {
    return await Hive.openBox(_boxName);
  }

  Future<void> saveObject(String key, Map<String, dynamic> value) async {
    final box = await _openBox();
    await box.put(key, value);
  }

  Future<Map<String, dynamic>?> getObject(String key) async {
    final box = await _openBox();
    final result = box.get(key);
    if (result is Map) {
      return Map<String, dynamic>.from(result as Map);
    }
    return null;
  }

  Future<void> saveList(String key, List<Map<String, dynamic>> list) async {
    final box = await _openBox();
    await box.put(key, list);
  }

  Future<List<Map<String, dynamic>>> getList(String key) async {
    final box = await _openBox();
    final result = box.get(key);
    if (result is List) {
      return List<Map<String, dynamic>>.from(
          result.map((e) => Map<String, dynamic>.from(e as Map)));
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> delete(String key) async {
    final box = await _openBox();
    await box.delete(key);
  }
}
