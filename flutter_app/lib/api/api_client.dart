import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';

class ApiClient {
  static String _baseUrl = 'http://192.168.71.31:5000';
  static String? _token;
  static String? _refreshToken;
  static Future<bool>? _refreshFuture;
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _chatTimeout = Duration(minutes: 3);

  static String get baseUrl => _baseUrl;

  static void configure({
    required String host,
    required int port,
    String scheme = 'http',
  }) {
    final normalizedHost = host.trim().replaceAll(RegExp(r'^https?://'), '');
    _baseUrl = '$scheme://$normalizedHost:$port';
  }

  static void setTokens(String? accessToken, String? refreshToken) {
    _token = accessToken;
    _refreshToken = refreshToken;
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

  static String _readBody(http.Response resp) {
    return utf8.decode(resp.bodyBytes);
  }

  static String _prettyErrorBody(String body) {
    if (body.isEmpty) return body;
    if (body.trimLeft().toLowerCase().startsWith('<!doctype html') ||
        body.trimLeft().toLowerCase().startsWith('<html')) {
      return '服务器响应异常';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
      if (decoded is String) {
        return decoded;
      }
    } catch (_) {}
    return body;
  }

  static Never _throwApiError(String label, http.Response resp) {
    final body = _prettyErrorBody(_readBody(resp));
    final suffix = body.isNotEmpty ? ' $body' : '';
    final friendly = resp.statusCode >= 500 && body.isEmpty ? '服务器繁忙，请稍后再试' : '';
    final finalSuffix = friendly.isNotEmpty ? ' $friendly' : suffix;
    throw Exception('$label API error: ${resp.statusCode}$finalSuffix');
  }

  static Future<bool> _refreshAccessToken() {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return Future.value(false);
    }
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }
    _refreshFuture = _doRefresh();
    return _refreshFuture!.whenComplete(() {
      _refreshFuture = null;
    });
  }

  static Future<bool> _doRefresh() async {
    final resp = await http.post(
      Uri.parse('$baseUrl/refresh'),
      headers: _headers(json: true, auth: false),
      body: jsonEncode({'refresh_token': _refreshToken}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(_readBody(resp)) as Map<String, dynamic>;
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access != null &&
          access.isNotEmpty &&
          refresh != null &&
          refresh.isNotEmpty) {
        setTokens(access, refresh);
        await AuthStorage.saveTokens(access, refresh);
        return true;
      }
    }
    await AuthStorage.clearTokens();
    setTokens(null, null);
    return false;
  }

  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() send, {
    Duration? timeout,
    String? timeoutLabel,
  }) async {
    http.Response resp;
    try {
      resp = await send().timeout(timeout ?? _defaultTimeout);
    } on TimeoutException {
      final label = (timeoutLabel == null || timeoutLabel.isEmpty)
          ? 'Request'
          : timeoutLabel;
      throw Exception('$label超时，请稍后再试');
    }
    if (resp.statusCode != 401) {
      return resp;
    }
    final refreshed = await _refreshAccessToken();
    if (!refreshed) {
      return resp;
    }
    return await send();
  }

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers(json: true, auth: false),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(_readBody(resp)) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      if (token != null && token.isNotEmpty) {
        if (refreshToken != null && refreshToken.isNotEmpty) {
          setTokens(token, refreshToken);
        } else {
          _token = token;
        }
      }
      return data;
    } else {
      final body = _prettyErrorBody(_readBody(resp));
      throw Exception('Login failed: ${resp.statusCode} $body');
    }
  }

  static Future<String> chat(String query) async {
    final resp = await _requestWithRetry(() {
      return http.post(
        Uri.parse('$baseUrl/chat'),
        headers: _headers(json: true),
        body: jsonEncode({'query': query}),
      );
    }, timeout: _chatTimeout, timeoutLabel: '对话请求');
    if (resp.statusCode == 200) {
      final data = jsonDecode(_readBody(resp));
      return data['response'] as String;
    } else {
      _throwApiError('Chat', resp);
    }
  }

  static Future<List<dynamic>> getAccounts() async {
    final resp = await _requestWithRetry(() {
      return http.get(
        Uri.parse('$baseUrl/accounts'),
        headers: _headers(),
      );
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as List<dynamic>;
    } else {
      _throwApiError('Accounts', resp);
    }
  }

  static Future<List<dynamic>> getBankDeposits() async {
    final resp = await _requestWithRetry(() {
      return http.get(
        Uri.parse('$baseUrl/bank_deposits'),
        headers: _headers(),
      );
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as List<dynamic>;
    } else {
      _throwApiError('Bank deposits', resp);
    }
  }

  static Future<List<dynamic>> getCashflows() async {
    final resp = await _requestWithRetry(() {
      return http.get(
        Uri.parse('$baseUrl/cashflows'),
        headers: _headers(),
      );
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as List<dynamic>;
    } else {
      _throwApiError('Cashflows', resp);
    }
  }

  static Future<List<dynamic>> getInsurance() async {
    final resp = await _requestWithRetry(() {
      return http.get(
        Uri.parse('$baseUrl/insurance_products'),
        headers: _headers(),
      );
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as List<dynamic>;
    } else {
      _throwApiError('Insurance', resp);
    }
  }

  static Future<List<dynamic>> getFinancialProducts() async {
    final resp = await _requestWithRetry(() {
      return http.get(
        Uri.parse('$baseUrl/financial_products'),
        headers: _headers(),
      );
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as List<dynamic>;
    } else {
      _throwApiError('Financial products', resp);
    }
  }

  static Future<List<dynamic>> getFundProducts() async {
    final resp = await _requestWithRetry(() {
      return http.get(
        Uri.parse('$baseUrl/fund_products'),
        headers: _headers(),
      );
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as List<dynamic>;
    } else {
      _throwApiError('Fund products', resp);
    }
  }

  static Future<Map<String, dynamic>> getFundMeta(String fundCode) async {
    final uri = Uri.parse('$baseUrl/fund_meta')
        .replace(queryParameters: {'fund_code': fundCode});
    final resp = await _requestWithRetry(() {
      return http.get(uri, headers: _headers());
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as Map<String, dynamic>;
    } else {
      _throwApiError('Fund meta', resp);
    }
  }

  static Future<Map<String, dynamic>> getSummary() async {
    final resp = await _requestWithRetry(() {
      return http.get(
        Uri.parse('$baseUrl/summary'),
        headers: _headers(),
      );
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as Map<String, dynamic>;
    } else {
      _throwApiError('Summary', resp);
    }
  }

  static Future<Map<String, dynamic>> operate(String action, Map<String, dynamic> params) async {
    final resp = await _requestWithRetry(() {
      return http.post(
        Uri.parse('$baseUrl/operate'),
        headers: _headers(json: true),
        body: jsonEncode({'action': action, 'params': params}),
      );
    });
    if (resp.statusCode == 200) {
      return jsonDecode(_readBody(resp)) as Map<String, dynamic>;
    } else {
      _throwApiError('Operate', resp);
    }
  }
}
