// lib/data/services/firebase_service.dart
import 'package:flutter/material.dart' show Color;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'supabase_service.dart';
import 'package:flutter/foundation.dart';


// ─── Gestionnaire background FCM (top-level obligatoire) ─────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _showLocalNotification(message);
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _showLocalNotification(RemoteMessage message) async {
  const channel = AndroidNotificationChannel(
    'transport_hub_channel',
    'TransportHub Notifications',
    description: "Notifications de l'application TransportHub",
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await _localNotifications.show(
    message.hashCode,
    message.notification?.title ?? 'TransportHub',
    message.notification?.body ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFFF6B35),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation:
            BigTextStyleInformation(message.notification?.body ?? ''),
      ),
    ),
    payload: message.data.toString(),
  );
}

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ─── PAS de GoogleSignIn comme champ de classe ────────────────
  // Instanciation locale dans signInWithGoogle() — pattern check31
  // qui évite le bug "popup ne revient pas"

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── INITIALISATION ──────────────────────────────────────────

  Future<void> init() async {
    await _initLocalNotifications();
    await _initFCM();
  }

  Future<void> _initLocalNotifications() async {
    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    const channel = AndroidNotificationChannel(
      'transport_hub_channel',
      'TransportHub Notifications',
      description: 'Notifications de TransportHub',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initFCM() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) async {
      await _showLocalNotification(message);
    });

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<String?> getFcmToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  void onTokenRefresh(void Function(String) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }

  // ─── AUTH EMAIL/PASSWORD ──────────────────────────────────────

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // ─── GOOGLE SIGN IN — pattern check31 ────────────────────────
  // Instanciation locale de GoogleSignIn() dans la méthode.
  // Retourne null si l'utilisateur annule → géré proprement par AuthProvider.

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Instanciation locale — clé du fix check31
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // Utilisateur a annulé la popup → on retourne null proprement
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e, s) {
      debugPrint('[FirebaseService] Google Sign-In error: $e\n$s');
      rethrow;
    }
  }

  // ─── SIGN OUT ─────────────────────────────────────────────────

  Future<void> signOut() async {
  await Future.wait([
    _auth.signOut(),
    GoogleSignIn().signOut().catchError((_) {
      return null;
    }),
  ]);

  await _messaging.deleteToken();
}

  // ─── UPDATE PROFILE ───────────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  // ─── SEND FCM NOTIFICATION via Supabase Edge Function ────────

  Future<void> sendNotificationToUser({
    required String recipientProfileId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await SupabaseService.instance.client.functions.invoke(
        'send-notification',
        body: {
          'recipient_profile_id': recipientProfileId,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
    } catch (_) {
      // Fallback : notification DB uniquement
      await SupabaseService.instance.insertNotification(
        recipientId: recipientProfileId,
        title: title,
        body: body,
        data: data?.cast<String, dynamic>(),
      );
    }
  }
}