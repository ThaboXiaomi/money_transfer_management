import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/config.dart';
import '../models/transfer.dart';

class ApiService {
  static Future<Map<String, dynamic>> uploadTransfer(
    Transfer t, {
    String destination = '',
    String txRef = '',
  }) async {
    final uri = Uri.parse('${AppConfig.backendBase}/transfers');
    final request = http.MultipartRequest('POST', uri);
    request.fields['agentName'] = t.agentName;
    if ((t as dynamic).agentId != null && (t as dynamic).agentId != '') {
      request.fields['agentId'] = (t as dynamic).agentId;
    }
    request.fields['senderNumber'] = t.senderNumber;
    request.fields['receiverNumber'] = t.receiverNumber;
    request.fields['amount'] = t.amount.toString();
    request.fields['charge'] = t.charge.toString();
    request.fields['agentFee'] = t.agentFee.toString();
    if (destination.isNotEmpty) request.fields['destination'] = destination;
    if (txRef.isNotEmpty) request.fields['txRef'] = txRef;
    if (t.screenshotPath.isNotEmpty) {
      try {
        request.files.add(
          await http.MultipartFile.fromPath('file', t.screenshotPath),
        );
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Upload failed: ${resp.statusCode} ${resp.body}');
  }

  static Future<List<Transfer>> fetchTransfers() async {
    final uri = Uri.parse('${AppConfig.backendBase}/transfers');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');
    final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List<dynamic>;
      return list.map((m) {
        final map = m as Map<String, dynamic>;
        return Transfer(
          id: map['id'] as int?,
          agentName: map['agentName'] ?? '',
          senderNumber: map['senderNumber'] ?? '',
          receiverNumber: map['receiverNumber'] ?? '',
          amount: (map['amount'] as num).toDouble(),
          charge: (map['charge'] as num).toDouble(),
          agentFee: (map['agentFee'] as num).toDouble(),
          screenshotPath:
              '${AppConfig.backendBase}/uploads/${map['screenshotPath']}',
          status: map['status'] ?? 'pending',
        );
      }).toList();
    }
    throw Exception('Fetch failed: ${resp.statusCode}');
  }

  static Future<void> login(String username, String password) async {
    final uri = Uri.parse('${AppConfig.backendBase}/token');
    final resp = await http.post(
      uri,
      body: {'username': username, 'password': password},
    );
    if (resp.statusCode == 200) {
      final m = json.decode(resp.body) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', m['access_token'] as String);
      return;
    }
    throw Exception('Login failed: ${resp.statusCode} ${resp.body}');
  }

  static Future<void> register(
    String username,
    String password,
    String role,
  ) async {
    final uri = Uri.parse('${AppConfig.backendBase}/register');
    final resp = await http.post(
      uri,
      body: {'username': username, 'password': password, 'role': role},
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }
    throw Exception('Register failed: ${resp.statusCode} ${resp.body}');
  }

  // best-effort helper used by the exchange rates manager UI; backend may not
  // expose a /rates endpoint so caller should ignore failures.
  static Future<void> _postRate(String pair, double rate) async {
    final uri = Uri.parse('${AppConfig.backendBase}/rates');
    final resp = await http.post(
      uri,
      body: {'pair': pair, 'rate': rate.toString()},
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw Exception('Post rate failed: ${resp.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    // best-effort: if backend exposes /users fetch, else return empty
    try {
      final uri = Uri.parse('${AppConfig.backendBase}/users');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt');
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}
