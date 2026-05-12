// lib/data/services/firebase_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show Color, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'supabase_service.dart';

// ─── Gestionnaire background FCM (top-level obligatoire) ─────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _showLocalNotification(message);
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _showLocalNotification(RemoteMessage message) async {
  const channel = AndroidNotificationChannel(
    'cargoza_channel',
    'Cargoza Notifications',
    description: "Notifications de l'application Cargoza",
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await _localNotifications.show(
    message.hashCode,
    message.notification?.title ?? 'Cargoza',
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

class AppFirebaseService {
  AppFirebaseService._();
  static final AppFirebaseService instance = AppFirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── INITIALISATION ──────────────────────────────────────────

  Future<void> init() async {
    // Initialisation de Google Sign-In (v7.x pattern)
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '263476182469-rb90c3c0braunpql4p079sfn93muugm9.apps.googleusercontent.com',
      );
    } catch (e) {
      debugPrint('[AppFirebaseService] GoogleSignIn init error: $e');
    }
    
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
      'cargoza_channel',
      'Cargoza Notifications',
      description: 'Notifications de Cargoza',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initFCM() async {
    // On ne bloque pas le démarrage pour les permissions
    _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    ).then((settings) {
      debugPrint('[AppFirebaseService] FCM Permission status: ${settings.authorizationStatus}');
    }).catchError((e) {
      debugPrint('[AppFirebaseService] FCM Permission error: $e');
    });

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
      // Ajout d'un timeout pour éviter de bloquer l'auth si FCM est lent ou indisponible
      return await _messaging.getToken().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[AppFirebaseService] Failed to get FCM token: $e');
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

  // ─── GOOGLE SIGN IN — Adaptation google_sign_in 7.x ──────────

  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('[AppFirebaseService] Starting Google Sign-In...');
      
      // Utilisation du singleton GoogleSignIn.instance et authenticate()
      final googleUser = await GoogleSignIn.instance.authenticate();

      debugPrint('[AppFirebaseService] Google User obtained: ${googleUser.email}');
      
      // googleUser.authentication n'est plus un Future dans la v7.x
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      debugPrint('[AppFirebaseService] Obtaining Firebase credential...');
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // accessToken n'est plus disponible par défaut dans GoogleSignInAuthentication v7.x
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('[AppFirebaseService] Firebase Sign-In successful: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AppFirebaseService] FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, s) {
      debugPrint('[AppFirebaseService] Unexpected Google Sign-In error: $e');
      debugPrint('$s');
      rethrow;
    }
  }

  // ─── SIGN OUT ─────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      GoogleSignIn.instance.signOut().catchError((_) {
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
