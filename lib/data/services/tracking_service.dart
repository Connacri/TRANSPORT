// lib/data/services/tracking_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'supabase_service.dart';

// ─── Entry point background isolate ─────────────────────────────
@pragma('vm:entry-point')
void backgroundTrackingEntryPoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) => service.stopSelf());

  Timer? trackingTimer;

  service.on('startTracking').listen((data) async {
    final transporterId = data?['transporter_id'] as String?;
    final requestId     = data?['request_id'] as String?;
    final intervalSec   = data?['interval_seconds'] as int? ?? 30;

    if (transporterId == null) return;

    trackingTimer?.cancel();
    trackingTimer = Timer.periodic(Duration(seconds: intervalSec), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        );

        // Mise à jour position transporteur
        await SupabaseService.instance.updateTransporterLocation(
          transporterId: transporterId,
          lat: position.latitude,
          lng: position.longitude,
        );

        // Si une course est en cours, insérer le point de tracking
        if (requestId != null) {
          await SupabaseService.instance.insertTracking(
            TrackingModel(
              id: '',
              requestId: requestId,
              transporterId: transporterId,
              lat: position.latitude,
              lng: position.longitude,
              speedKmh: position.speed * 3.6,
              heading: position.heading,
              accuracyM: position.accuracy,
              recordedAt: DateTime.now(),
            ),
          );
        }

        service.invoke('locationUpdate', {
          'lat': position.latitude,
          'lng': position.longitude,
          'speed': position.speed * 3.6,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        service.invoke('trackingError', {'error': e.toString()});
      }
    });
  });

  service.on('stopTracking').listen((_) {
    trackingTimer?.cancel();
    trackingTimer = null;
  });

  service.on('updateInterval').listen((data) {
    // TODO: restart timer avec nouvel interval
  });
}

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  final FlutterBackgroundService _bgService = FlutterBackgroundService();
  StreamSubscription? _locationSub;

  // ─── INIT SERVICE ────────────────────────────────────────────

  Future<void> initialize() async {
    await _bgService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundTrackingEntryPoint,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'tracking_channel',
        initialNotificationTitle: 'TransportHub — Tracking actif',
        initialNotificationContent: 'Votre position est partagée en temps réel',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundTrackingEntryPoint,
      ),
    );
  }

  // ─── PERMISSIONS ─────────────────────────────────────────────

  Future<bool> requestPermissions() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return false;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return false;
  }
  if (permission == LocationPermission.deniedForever) return false;
  
  // Android 11+ : demander background séparément
  if (permission == LocationPermission.whileInUse) {
    permission = await Geolocator.requestPermission();
  }
  
  return permission == LocationPermission.always ||
         permission == LocationPermission.whileInUse;
}

  // ─── DÉMARRER LE TRACKING ────────────────────────────────────

  Future<void> startTracking({
    required String transporterId,
    String? requestId,
    int intervalSeconds = 30,
  }) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) throw Exception('Permission de localisation refusée');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tracking_transporter_id', transporterId);
    if (requestId != null) await prefs.setString('tracking_request_id', requestId);

    final isRunning = await _bgService.isRunning();
    if (!isRunning) await _bgService.startService();

    _bgService.invoke('startTracking', {
      'transporter_id': transporterId,
      'request_id': requestId,
      'interval_seconds': intervalSeconds,
    });
  }

  // ─── ARRÊTER ─────────────────────────────────────────────────

  Future<void> stopTracking() async {
    _bgService.invoke('stopTracking');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tracking_transporter_id');
    await prefs.remove('tracking_request_id');
  }

  Future<void> stopService() async {
    _bgService.invoke('stopService');
  }

  // ─── STREAM POSITION (foreground) ────────────────────────────

  Stream<Map<String, dynamic>> get locationStream {
    return _bgService.on('locationUpdate').where((event) => event != null).cast<Map<String, dynamic>>();
  }

  Stream<Map<String, dynamic>?> get errorStream {
    return _bgService.on('trackingError');
  }

  // ─── POSITION UNIQUE ─────────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // ─── CALCUL DISTANCE ─────────────────────────────────────────

  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  // ─── MISE À JOUR INTERVAL PREMIUM ────────────────────────────

  void updateTrackingInterval(int newIntervalSec) {
    _bgService.invoke('updateInterval', {'interval_seconds': newIntervalSec});
  }

  void dispose() {
    _locationSub?.cancel();
  }
}
