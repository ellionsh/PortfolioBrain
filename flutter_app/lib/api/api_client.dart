import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://192.168.71.31:5000';

  static Future<String> chat(String query) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['response'] as String;
    } else {
      throw Exception('Chat API error: ${resp.statusCode}');
    }
  }

  static Future<List<dynamic>> getAccounts() async {
    final resp = await http.get(Uri.parse('$baseUrl/accounts'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Accounts API error');
    }
  }

  static Future<List<dynamic>> getBankDeposits() async {
    final resp = await http.get(Uri.parse('$baseUrl/bank_deposits'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Bank deposits API error');
    }
  }

  static Future<List<dynamic>> getCashflows() async {
    final resp = await http.get(Uri.parse('$baseUrl/cashflows'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Cashflows API error');
    }
  }

  static Future<List<dynamic>> getInsurance() async {
    final resp = await http.get(Uri.parse('$baseUrl/insurance_products'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Insurance API error');
    }
  }

  static Future<List<dynamic>> getFinancialProducts() async {
    final resp = await http.get(Uri.parse('$baseUrl/financial_products'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Financial products API error');
    }
  }

  static Future<Map<String, dynamic>> getSummary() async {
    final resp = await http.get(Uri.parse('$baseUrl/summary'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Summary API error');
    }
  }

  static Future<Map<String, dynamic>> operate(String action, Map<String, dynamic> params) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/operate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': action, 'params': params}),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Operate API error: ${resp.statusCode}');
    }
  }
}
