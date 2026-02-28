import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';

  static String _generateMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    debugPrint("DEBUG: Token saved successfully: $token");
  }

  static Future<void> _saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_username', username);
    debugPrint("DEBUG: Username saved: $username");
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_username');
  }

  static Future<void> logout() async {
    try {
      final token = await getToken();
      final username = await getUsername();
      
      debugPrint("DEBUG: Attempting logout for: $username with token: ${token ?? 'NULL'}");

      if (token != null && username != null) {
        final response = await http.post(
          Uri.parse("$baseUrl/logout"),
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "username": username,
          }),
        );
        debugPrint("DEBUG: Logout Response: ${response.statusCode} - ${response.body}");
      } else {
        debugPrint("DEBUG: Skipping API logout: Missing token or username");
      }
    } catch (e) {
      debugPrint("DEBUG: Logout Error: $e");
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('last_username');
      debugPrint("DEBUG: Local session data cleared");
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "username": email,
          "password": _generateMd5(password),
        }),
      );

      final data = jsonDecode(response.body);
      debugPrint("DEBUG: Login Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final responseData = data['data'] ?? data;
        final bool mfaActive = responseData['mfa_active'] ?? false;
        
        await _saveUsername(email);

        if (!mfaActive && responseData['token'] != null) {
          await _saveToken(responseData['token']);
        }

        return {
          "success": true,
          "mfa_active": mfaActive,
          "data": data,
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? data['error_message'] ?? "Login Failed",
        };
      }
    } catch (e) {
      debugPrint("DEBUG: Login Exception: $e");
      return {"success": false, "message": "Connection Error"};
    }
  }

  static Future<Map<String, dynamic>> verifyMfa({required String token, required String userId}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/verify-mfa"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "username": userId,
          "token": token,
        }),
      );

      final data = jsonDecode(response.body);
      debugPrint("DEBUG: MFA Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final responseData = data['data'] ?? data;
        if (responseData['token'] != null) {
          await _saveToken(responseData['token']);
        }
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? "Invalid MFA Token"};
      }
    } catch (e) {
      debugPrint("DEBUG: MFA Exception: $e");
      return {"success": false, "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final token = await getToken();
      debugPrint("DEBUG: Fetching user info with token: ${token ?? 'NULL'}");
      
      if (token == null) return {"success": false, "message": "No token found"};

      final response = await http.get(
        Uri.parse("$baseUrl/user-info"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);
      debugPrint("DEBUG: User Info Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        return {"success": true, "data": data['data']};
      } else {
        return {"success": false, "message": "Failed to fetch user info"};
      }
    } catch (e) {
      debugPrint("DEBUG: User Info Exception: $e");
      return {"success": false, "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final hashedPassword = _generateMd5(password);
      
      final response = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": hashedPassword,
          "password_confirmation": hashedPassword,
        }),
      );

      final data = jsonDecode(response.body);
      debugPrint("DEBUG: Register Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? "Registration Failed"};
      }
    } catch (e) {
      debugPrint("DEBUG: Register Exception: $e");
      return {"success": false, "message": "Connection error"};
    }
  }
}
