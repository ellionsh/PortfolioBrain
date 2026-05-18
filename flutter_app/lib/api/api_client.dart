import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static String _baseUrl = 'http://192.168.71.31:5000';
  static String? _token;

  static String get baseUrl => _baseUrl;

  static void configure({
    required String host,
    required int port,
    String scheme = 'http',
  }) {
    final normalizedHost = host.trim().replaceAll(RegExp(r'^https?://'), '');
    _baseUrl = '$scheme://$normalizedHost:$port';
  }

  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> _headers({bool json = false, bool auth = true}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (auth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static void _throwApiError(String label, http.Response resp) {
    final body = resp.body;
    final suffix = body.isNotEmpty ? ' $body' : '';
    throw Exception('$label API error: ${resp.statusCode}$suffix');
  }

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers(json: true, auth: false),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token != null && token.isNotEmpty) {
        _token = token;
      }
      return data;
    } else {
      final body = resp.body;
      throw Exception('Login failed: ${resp.statusCode} $body');
    }
  }

  static Future<String> chat(String query) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: _headers(json: true),
      body: jsonEncode({'query': query}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['response'] as String;
    } else {
      _throwApiError('Chat', resp);
    }
  }

  static Future<List<dynamic>> getAccounts() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/accounts'),
      headers: _headers(),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      _throwApiError('Accounts', resp);
    }
  }

  static Future<List<dynamic>> getBankDeposits() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/bank_deposits'),
      headers: _headers(),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      _throwApiError('Bank deposits', resp);
    }
  }

  static Future<List<dynamic>> getCashflows() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/cashflows'),
      headers: _headers(),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      _throwApiError('Cashflows', resp);
    }
  }

  static Future<List<dynamic>> getInsurance() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/insurance_products'),
      headers: _headers(),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      _throwApiError('Insurance', resp);
    }
  }

  static Future<List<dynamic>> getFinancialProducts() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/financial_products'),
      headers: _headers(),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      _throwApiError('Financial products', resp);
    }
  }

  static Future<List<dynamic>> getFundProducts() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/fund_products'),
      headers: _headers(),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      _throwApiError('Fund products', resp);
    }
  }

  static Future<Map<String, dynamic>> getFundMeta(String fundCode) async {
    final uri = Uri.parse('$baseUrl/fund_meta')
        .replace(queryParameters: {'fund_code': fundCode});
    final resp = await http.get(uri, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      _throwApiError('Fund meta', resp);
    }
  }

  static Future<Map<String, dynamic>> getSummary() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/summary'),
      headers: _headers(),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      _throwApiError('Summary', resp);
    }
  }

  static Future<Map<String, dynamic>> operate(String action, Map<String, dynamic> params) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/operate'),
      headers: _headers(json: true),
      body: jsonEncode({'action': action, 'params': params}),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      _throwApiError('Operate', resp);
    }
  }
}
