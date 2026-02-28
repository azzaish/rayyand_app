import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static String _generateMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  static Future<void> _saveToken(String token) async {
    final p = await prefs;
    await p.setString('auth_token', token);
    debugPrint("DEBUG: Token saved successfully");
  }

  static Future<void> _saveUsername(String username) async {
    final p = await prefs;
    await p.setString('last_username', username);
    debugPrint("DEBUG: Username saved: $username");
  }

  static Future<String?> getToken() async {
    final p = await prefs;
    return p.getString('auth_token');
  }

  static Future<String?> getUsername() async {
    final p = await prefs;
    return p.getString('last_username');
  }

  static Future<void> logout() async {
    try {
      final token = await getToken();
      final username = await getUsername();
      
      if (token != null && username != null) {
        await http.post(
          Uri.parse("$baseUrl/logout"),
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({"username": username}),
        );
      }
    } catch (e) {
      debugPrint("DEBUG: Logout Error: $e");
    } finally {
      final p = await prefs;
      await p.remove('auth_token');
      await p.remove('last_username');
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

      if (response.statusCode == 200) {
        final responseData = data['data'] ?? data;
        final bool mfaActive = responseData['mfa_active'] ?? false;
        
        await _saveUsername(email);

        final String? token = responseData['access_token'] ?? responseData['token'];
        if (!mfaActive && token != null) {
          await _saveToken(token);
        }

        return {"success": true, "mfa_active": mfaActive, "data": data};
      } else {
        return {
          "success": false,
          "message": data['message'] ?? data['error_message'] ?? "Login Failed",
        };
      }
    } catch (e) {
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

      if (response.statusCode == 200) {
        final responseData = data['data'] ?? data;
        final String? authToken = responseData['access_token'] ?? responseData['token'];
        if (authToken != null) {
          await _saveToken(authToken);
        }
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? "Invalid MFA Token"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> resendMfaToken(String username) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/resend-mfa-token"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"username": username}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'] ?? "Token resent successfully"};
      } else {
        return {"success": false, "message": data['message'] ?? "Failed to resend token"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final token = await getToken();
      if (token == null) return {"success": false, "message": "No token found"};

      final response = await http.get(
        Uri.parse("$baseUrl/user-info"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "data": data['data']};
      } else {
        return {"success": false, "message": "Failed to fetch user info"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> resetPasswordAuto(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/reset-password-auto"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"username": email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'] ?? "Password reset link sent!"};
      } else {
        return {"success": false, "message": data['message'] ?? "Failed to reset password"};
      }
    } catch (e) {
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

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? "Registration Failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection error"};
    }
  }
}
