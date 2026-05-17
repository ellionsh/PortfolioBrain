// lib/services/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const base = "http://localhost:5000";

  static Future<dynamic> getJson(String path) async {
    final res = await http.get(Uri.parse("$base$path"));
    return jsonDecode(res.body);
  }

  static Future<dynamic> postJson(String path, Map data) async {
    final res = await http.post(
      Uri.parse("$base$path"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }
}
