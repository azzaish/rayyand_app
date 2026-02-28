import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  static Future<void> initialize() async {
    if (!isSupported) {
      debugPrint('DEBUG: Push Notifications are not supported on this platform.');
      return;
    }

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('DEBUG: User granted notification permission');
        
        String? token = await messaging.getToken();
        if (token != null) {
          debugPrint("DEBUG: FCM Token: $token");
          await _sendTokenToServer(token);
        }

        messaging.onTokenRefresh.listen(_sendTokenToServer);

        const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
        await _localNotifications.initialize(initSettings);

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showLocalNotification(message);
        });
      }
    } catch (e) {
      debugPrint("DEBUG: Error initializing NotificationService: $e");
    }
  }

  static Future<void> _sendTokenToServer(String token) async {
    final String? authToken = await AuthService.getToken();
    final String? username = await AuthService.getUsername();

    if (authToken != null && username != null) {
      try {
        debugPrint("DEBUG: Registering push token for: $username");
        final response = await http.post(
          Uri.parse("${AuthService.baseUrl}/push/register-token"), // Updated endpoint
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer $authToken",
          },
          body: jsonEncode({
            "username": username,
            "token": token, // Updated key to 'token'
          }),
        );
        debugPrint("DEBUG: Push Token Sync Status: ${response.statusCode} - ${response.body}");
      } catch (e) {
        debugPrint("DEBUG: Error syncing Push token: $e");
      }
    } else {
      debugPrint("DEBUG: Skipping Push Token Sync: Missing Auth Token or Username");
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }
}
