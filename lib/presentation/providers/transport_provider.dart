// lib/presentation/providers/transport_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/models.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/supabase_service.dart';
import '../../data/services/tracking_service.dart';

enum TransportProviderState { idle, loading, success, error }

class TransportProvider extends ChangeNotifier {
  // ─── STATE ───────────────────────────────────────────────────
  TransportProviderState _state = TransportProviderState.idle;
  String? _errorMessage;

  // ─── DONNÉES ─────────────────────────────────────────────────
  List<TransporterModel> _nearbyTransporters = [];
  TransportRequestModel? _activeRequest;
  List<TransportRequestModel> _requestHistory = [];
  List<TrackingModel> _trackingPoints = [];
  LatLng? _transporterCurrentPos;

  // ─── ABONNEMENTS REALTIME ─────────────────────────────────────
  RealtimeChannel? _trackingChannel;
  RealtimeChannel? _requestChannel;
  RealtimeChannel? _newRequestsChannel;
  StreamSubscription? _bgLocationSub;

  // ─── GETTERS ─────────────────────────────────────────────────
  TransportProviderState get state           => _state;
  String?               get errorMessage     => _errorMessage;
  bool                  get isLoading        => _state == TransportProviderState.loading;
  List<TransporterModel> get nearbyTransporters => _nearbyTransporters;
  TransportRequestModel? get activeRequest   => _activeRequest;
  List<TransportRequestModel> get requestHistory => _requestHistory;
  List<TrackingModel>   get trackingPoints   => _trackingPoints;
  LatLng?               get transporterPos   => _transporterCurrentPos;

  // ─── CHERCHER TRANSPORTEURS À PROXIMITÉ ───────────────────────

  Future<void> loadNearbyTransporters({
    required double lat,
    required double lng,
    double radius = 50,
    String? vehicleType,
  }) async {
    _setState(TransportProviderState.loading);
    try {
      _nearbyTransporters = await SupabaseService.instance.getNearbyTransporters(
        lat: lat,
        lng: lng,
        radiusKm: radius,
        vehicleType: vehicleType,
      );
      _setState(TransportProviderState.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ─── CRÉER UNE DEMANDE (client) ───────────────────────────────

  Future<TransportRequestModel?> createRequest({
    required String clientId,
    required String transporterId,
    required double pickupLat,
    required double pickupLng,
    required String? pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String? dropoffAddress,
    required double estimatedDistanceKm,
    required int estimatedDurationMin,
    String? cargoDescription,
    double? cargoWeightKg,
    bool needsHandling = false,
    bool needsTransportInsurance = false,
    required double basePrice,
    required double handlingFee,
    required double insuranceFee,
    String currency = 'DZD',
    String? regionId,
  }) async {
    _setState(TransportProviderState.loading);
    try {
      final total = basePrice + handlingFee + insuranceFee;

      final request = await SupabaseService.instance.createRequest({
        'client_id': clientId,
        'transporter_id': transporterId,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'pickup_address': pickupAddress,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'dropoff_address': dropoffAddress,
        'estimated_distance_km': estimatedDistanceKm,
        'estimated_duration_min': estimatedDurationMin,
        'cargo_description': cargoDescription,
        'cargo_weight_kg': cargoWeightKg,
        'needs_handling': needsHandling,
        'needs_transport_insurance': needsTransportInsurance,
        'base_price': basePrice,
        'handling_fee': handlingFee,
        'insurance_fee': insuranceFee,
        'total_price': total,
        'currency': currency,
        'region_id': regionId,
      });

      _activeRequest = request;

      // Notifier le transporteur via FCM
      await AppFirebaseService.instance.sendNotificationToUser(
        recipientProfileId: transporterId,
        title: '🚛 Nouvelle demande de transport',
        body: 'De: $pickupAddress → $dropoffAddress\nPrix: ${total.toStringAsFixed(0)} $currency',
        data: {'type': 'new_request', 'request_id': request.id},
      );

      // Abonner aux mises à jour de la demande
      _subscribeToRequest(request.id);

      _setState(TransportProviderState.success);
      return request;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // ─── ACCEPTER UNE DEMANDE (transporteur) ─────────────────────

  Future<bool> acceptRequest({
    required String requestId,
    required String transporterId,
    required String clientId,
  }) async {
    try {
      _activeRequest = await SupabaseService.instance.updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.accepted,
        extra: {'transporter_id': transporterId},
      );

      // Notifier le client
      await AppFirebaseService.instance.sendNotificationToUser(
        recipientProfileId: clientId,
        title: '✅ Demande acceptée !',
        body: 'Votre transporteur est en route. Suivez-le en temps réel.',
        data: {'type': 'request_accepted', 'request_id': requestId},
      );

      _setState(TransportProviderState.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ─── DÉMARRER LE TRANSPORT ───────────────────────────────────

  Future<bool> startTransport({
    required String requestId,
    required String transporterId,
    required String clientId,
    int intervalSeconds = 30,
  }) async {
    try {
      _activeRequest = await SupabaseService.instance.updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.inProgress,
      );

      // Démarrer tracking background
      await TrackingService.instance.startTracking(
        transporterId: transporterId,
        requestId: requestId,
        intervalSeconds: intervalSeconds,
      );

      // Abonner au stream de position en foreground
      _bgLocationSub = TrackingService.instance.locationStream.listen((data) {
        _transporterCurrentPos = LatLng(
          (data['lat'] as num).toDouble(),
          (data['lng'] as num).toDouble(),
        );
        notifyListeners();
      });

      // Souscrire au tracking Supabase Realtime
      _subscribeToTracking(requestId, transporterId);

      // Notifier client
      await AppFirebaseService.instance.sendNotificationToUser(
        recipientProfileId: clientId,
        title: '🚚 Transport démarré !',
        body: 'Le transporteur est en route vers vous.',
        data: {'type': 'transport_started', 'request_id': requestId},
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ─── TERMINER LE TRANSPORT ───────────────────────────────────

  Future<bool> completeTransport({
    required String requestId,
    required String clientId,
  }) async {
    try {
      _activeRequest = await SupabaseService.instance.updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.completed,
      );

      await TrackingService.instance.stopTracking();
      _bgLocationSub?.cancel();
      _unsubscribeAll();

      // Notifier client
      await AppFirebaseService.instance.sendNotificationToUser(
        recipientProfileId: clientId,
        title: '🎉 Transport terminé !',
        body: 'Merci d\'utiliser Cargoza. Notez votre transporteur !',
        data: {'type': 'transport_completed', 'request_id': requestId},
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ─── ANNULER ─────────────────────────────────────────────────

  Future<bool> cancelRequest({
    required String requestId,
    required String reason,
    required String otherPartyProfileId,
  }) async {
    try {
      _activeRequest = await SupabaseService.instance.updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.cancelled,
        extra: {'cancellation_reason': reason},
      );

      await TrackingService.instance.stopTracking();
      _bgLocationSub?.cancel();
      _unsubscribeAll();

      await AppFirebaseService.instance.sendNotificationToUser(
        recipientProfileId: otherPartyProfileId,
        title: '❌ Transport annulé',
        body: reason,
        data: {'type': 'request_cancelled', 'request_id': requestId},
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ─── NOTER (client) ───────────────────────────────────────────

  Future<bool> submitRating({
    required String requestId,
    required String transporterId,
    required String clientId,
    required int score,
    String? comment,
  }) async {
    try {
      await SupabaseService.instance.createRating(
        requestId: requestId,
        transporterId: transporterId,
        clientId: clientId,
        score: score,
        comment: comment,
      );
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ─── HISTORIQUE ───────────────────────────────────────────────

  Future<void> loadHistory({required String profileId, required UserRole role}) async {
    _setState(TransportProviderState.loading);
    try {
      if (role == UserRole.transporter) {
        final transporter = await SupabaseService.instance.getTransporterByProfileId(profileId);
        if (transporter != null) {
          _requestHistory = await SupabaseService.instance.getTransporterRequests(transporter.id);
        }
      } else {
        _requestHistory = await SupabaseService.instance.getClientRequests(profileId);
      }
      _setState(TransportProviderState.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ─── SUBSCRIPTIONS REALTIME ──────────────────────────────────

  void _subscribeToTracking(String requestId, String transporterId) {
    _trackingChannel?.unsubscribe();
    _trackingChannel = SupabaseService.instance.subscribeToTracking(
      requestId: requestId,
      onData: (tracking) {
        _trackingPoints.add(tracking);
        _transporterCurrentPos = LatLng(tracking.lat, tracking.lng);
        notifyListeners();
      },
    );
  }

  void _subscribeToRequest(String requestId) {
    _requestChannel?.unsubscribe();
    _requestChannel = SupabaseService.instance.subscribeToRequest(
      requestId: requestId,
      onData: (request) {
        _activeRequest = request;
        // Si le transport démarre, on s'abonne au tracking
        if (request.status == RequestStatus.inProgress &&
            request.transporterId != null) {
          _subscribeToTracking(request.id, request.transporterId!);
        }
        notifyListeners();
      },
    );
  }

  /// Transporteur écoute les nouvelles demandes entrant
  void subscribeToIncomingRequests(void Function(TransportRequestModel) onNew) {
    _newRequestsChannel?.unsubscribe();
    _newRequestsChannel = SupabaseService.instance.subscribeToNewRequests(onData: onNew);
  }

  void _unsubscribeAll() {
    _trackingChannel?.unsubscribe();
    _requestChannel?.unsubscribe();
    _newRequestsChannel?.unsubscribe();
    _trackingChannel = null;
    _requestChannel  = null;
  }

  void clearActiveRequest() {
    _activeRequest = null;
    _trackingPoints = [];
    _transporterCurrentPos = null;
    notifyListeners();
  }

  // ─── HELPERS ──────────────────────────────────────────────────

  void _setState(TransportProviderState s) {
    _state = s;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _state = TransportProviderState.error;
    _errorMessage = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    _unsubscribeAll();
    _bgLocationSub?.cancel();
    super.dispose();
  }

  void setActiveRequestDirectly(TransportRequestModel request) {
    _activeRequest = request;
    _subscribeToRequest(request.id);

    // Si déjà en cours, lancer l'abonnement tracking
    if (request.status == RequestStatus.inProgress &&
        request.transporterId != null) {
      _subscribeToTracking(request.id, request.transporterId!);
    }

    notifyListeners();
  }
}
