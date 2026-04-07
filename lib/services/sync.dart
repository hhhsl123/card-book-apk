import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/data.dart';

class SyncService {
  static const _url = 'https://card-sync.cardsync.workers.dev';

  /// Pull latest data from cloud
  static Future<AppData?> pull() async {
    try {
      final resp = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return AppData.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  /// Smart merge: POST local data, server merges with remote, returns merged result
  static Future<AppData?> merge(AppData local) async {
    try {
      final resp = await http.post(
        Uri.parse(_url),
        headers: {'Content-Type': 'application/json'},
        body: local.toJsonString(),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return AppData.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  /// Overwrite cloud data entirely (PUT)
  static Future<bool> overwrite(AppData data) async {
    try {
      final resp = await http.put(
        Uri.parse(_url),
        headers: {'Content-Type': 'application/json'},
        body: data.toJsonString(),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {}
    return false;
  }
}
