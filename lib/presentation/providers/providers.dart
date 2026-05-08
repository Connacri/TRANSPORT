// lib/presentation/providers/transporter_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/models.dart';
import '../../data/services/supabase_service.dart';
import '../../data/services/tracking_service.dart';

class TransporterProvider extends ChangeNotifier {
  TransporterModel? _transporter;
  bool _isLoading = false;
  String? _error;
  List<PremiumOptionModel> _premiumOptions = [];
  List<RatingModel> _ratings = [];

  TransporterModel? get transporter    => _transporter;
  bool              get isLoading      => _isLoading;
  String?           get error          => _error;
  List<PremiumOptionModel> get premiumOptions => _premiumOptions;
  List<RatingModel> get ratings        => _ratings;
  bool              get isAvailable    => _transporter?.isAvailable ?? false;
  bool              get isPremium      => _transporter?.isPremium ?? false;
  int               get validationScore => _transporter?.validationScore ?? 0;

  // ─── CHARGER PROFIL TRANSPORTEUR ─────────────────────────────

  Future<void> loadTransporter(String profileId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _transporter = await SupabaseService.instance.getTransporterByProfileId(profileId);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ─── CRÉER PROFIL TRANSPORTEUR ───────────────────────────────

  Future<bool> createTransporterProfile({
    required String profileId,
    required String vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    required String vehiclePlate,
    double? capacityKg,
    double? capacityM3,
    required XFile vehiclePhoto,
    XFile? facePhoto,
    XFile? licensePhoto,
    XFile? registrationPhoto,
    XFile? insurancePhoto,
    XFile? technicalControlPhoto,
    bool offersHandling = false,
    double handlingFeeRate = 0,
    bool offersInsurance = false,
    double insuranceRate = 0,
    double? basePricePerKm,
    double? minimumPrice,
    String? regionId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload photo véhicule (obligatoire)
      final vehicleUrl = await _uploadPhoto(
        file: vehiclePhoto,
        bucket: AppConstants.bucketVehicles,
        folder: profileId,
        name: 'vehicle',
      );

      // Upload docs optionnels
      final faceUrl    = facePhoto    != null ? await _uploadPhoto(file: facePhoto,    bucket: AppConstants.bucketDocuments, folder: profileId, name: 'face')    : null;
      final licUrl     = licensePhoto != null ? await _uploadPhoto(file: licensePhoto, bucket: AppConstants.bucketDocuments, folder: profileId, name: 'license') : null;
      final regUrl     = registrationPhoto != null ? await _uploadPhoto(file: registrationPhoto, bucket: AppConstants.bucketDocuments, folder: profileId, name: 'registration') : null;
      final insUrl     = insurancePhoto    != null ? await _uploadPhoto(file: insurancePhoto,    bucket: AppConstants.bucketDocuments, folder: profileId, name: 'insurance')    : null;
      final techUrl    = technicalControlPhoto != null ? await _uploadPhoto(file: technicalControlPhoto, bucket: AppConstants.bucketDocuments, folder: profileId, name: 'technical') : null;

      _transporter = await SupabaseService.instance.createTransporter({
        'profile_id': profileId,
        'vehicle_type': vehicleType,
        'vehicle_brand': vehicleBrand,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_plate': vehiclePlate.toUpperCase(),
        'vehicle_capacity_kg': capacityKg,
        'vehicle_capacity_m3': capacityM3,
        'vehicle_photo_url': vehicleUrl,
        'face_photo_url': faceUrl,
        'license_photo_url': licUrl,
        'registration_photo_url': regUrl,
        'insurance_photo_url': insUrl,
        'technical_control_url': techUrl,
        'offers_handling': offersHandling,
        'handling_fee_rate': handlingFeeRate,
        'offers_transport_insurance': offersInsurance,
        'insurance_rate_percent': insuranceRate,
        'base_price_per_km': basePricePerKm,
        'minimum_price': minimumPrice,
        'region_id': regionId,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── TOGGLE DISPONIBILITÉ ─────────────────────────────────────

  Future<void> toggleAvailability() async {
    if (_transporter == null) return;
    final newVal = !_transporter!.isAvailable;
    try {
      await SupabaseService.instance.toggleTransporterAvailability(_transporter!.id, newVal);
      _transporter = TransporterModel.fromJson({
        ..._transporter!.toJson(),
        'id': _transporter!.id,
        'is_available': newVal,
        'is_validated': _transporter!.isValidated,
        'validation_score': _transporter!.validationScore,
        'average_rating': _transporter!.averageRating,
        'total_ratings': _transporter!.totalRatings,
        'total_transports': _transporter!.totalTransports,
        'location_interval_seconds': _transporter!.locationIntervalSeconds,
        'is_premium': _transporter!.isPremium,
        'offers_handling': _transporter!.offersHandling,
        'handling_fee_rate': _transporter!.handlingFeeRate,
        'offers_transport_insurance': _transporter!.offersTransportInsurance,
        'insurance_rate_percent': _transporter!.insuranceRatePercent,
        'vehicle_photo_url': _transporter!.vehiclePhotoUrl,
        'vehicle_plate': _transporter!.vehiclePlate,
        'vehicle_type': _transporter!.vehicleType,
        'profile_id': _transporter!.profileId,
        'created_at': _transporter!.createdAt.toIso8601String(),
      });

      // Démarrer/arrêter le tracking de position
      if (newVal) {
        await TrackingService.instance.startTracking(
          transporterId: _transporter!.id,
          intervalSeconds: _transporter!.locationIntervalSeconds,
        );
      } else {
        await TrackingService.instance.stopTracking();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── CHARGER OPTIONS PREMIUM ──────────────────────────────────

  Future<void> loadPremiumOptions({String? regionId}) async {
    try {
      _premiumOptions = await SupabaseService.instance.getPremiumOptions(regionId: regionId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  // ─── CHARGER NOTES ────────────────────────────────────────────

  Future<void> loadRatings() async {
    if (_transporter == null) return;
    try {
      _ratings = await SupabaseService.instance.getTransporterRatings(_transporter!.id);
      notifyListeners();
    } catch (_) {}
  }

  // ─── UPLOAD IMAGE ─────────────────────────────────────────────

  Future<String> _uploadPhoto({
    required XFile file,
    required String bucket,
    required String folder,
    required String name,
  }) async {
    final bytes = await file.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1080,
      minHeight: 1080,
      quality: 80,
    );
    final path = '$folder/$name.jpg';
    return await SupabaseService.instance.uploadFile(
      bucket: bucket,
      path: path,
      bytes: compressed,
      contentType: 'image/jpeg',
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════
// NOTIFICATION PROVIDER
// ═══════════════════════════════════════════════════════════════
class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  RealtimeChannelRef? _sub;

  List<NotificationModel> get notifications => _notifications;
  int                      get unreadCount   => _unreadCount;

  Future<void> init(String profileId) async {
    await _loadNotifications(profileId);
    _subscribeRealtime(profileId);
  }

  Future<void> _loadNotifications(String profileId) async {
    try {
      _notifications = await SupabaseService.instance.getNotifications(profileId);
      _unreadCount   = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (_) {}
  }

  void _subscribeRealtime(String profileId) {
    SupabaseService.instance.subscribeToNotifications(
      profileId: profileId,
      onData: (notif) {
        _notifications.insert(0, notif);
        _unreadCount++;
        notifyListeners();
      },
    );
  }

  Future<void> markRead(String notifId) async {
    await SupabaseService.instance.markNotificationRead(notifId);
    final idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx != -1) {
      _notifications[idx] = NotificationModel(
        id: _notifications[idx].id,
        recipientId: _notifications[idx].recipientId,
        title: _notifications[idx].title,
        body: _notifications[idx].body,
        data: _notifications[idx].data,
        type: _notifications[idx].type,
        isRead: true,
        sentViaFcm: _notifications[idx].sentViaFcm,
        createdAt: _notifications[idx].createdAt,
      );
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    for (final n in _notifications.where((n) => !n.isRead)) {
      await SupabaseService.instance.markNotificationRead(n.id);
    }
    _unreadCount = 0;
    notifyListeners();
  }
}

// Type dummy pour le channel
class RealtimeChannelRef {}

// ═══════════════════════════════════════════════════════════════
// ADMIN PROVIDER
// ═══════════════════════════════════════════════════════════════
class AdminProvider extends ChangeNotifier {
  List<TransporterModel>  _pendingTransporters = [];
  List<SupervisorModel>   _supervisors         = [];
  List<BusinessRuleModel> _businessRules       = [];
  List<RegionModel>       _regions             = [];
  bool _isLoading = false;
  String? _error;

  List<TransporterModel>  get pendingTransporters => _pendingTransporters;
  List<SupervisorModel>   get supervisors         => _supervisors;
  List<BusinessRuleModel> get businessRules       => _businessRules;
  List<RegionModel>       get regions             => _regions;
  bool                    get isLoading           => _isLoading;
  String?                 get error               => _error;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadPendingTransporters(),
        _loadSupervisors(),
        _loadBusinessRules(),
        _loadRegions(),
      ]);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPendingTransporters() async {
    _pendingTransporters = await SupabaseService.instance.getPendingValidationTransporters();
  }

  Future<void> _loadSupervisors() async {
    _supervisors = await SupabaseService.instance.getAllSupervisors();
  }

  Future<void> _loadBusinessRules() async {
    _businessRules = await SupabaseService.instance.getAllBusinessRules();
  }

  Future<void> _loadRegions() async {
    _regions = await SupabaseService.instance.getRegions();
  }

  Future<bool> validateTransporter({
    required String transporterId,
    required String adminProfileId,
    bool validate = true,
    String? suspensionReason,
  }) async {
    try {
      final updated = await SupabaseService.instance.validateTransporter(
        transporterId: transporterId,
        adminProfileId: adminProfileId,
        validate: validate,
        suspensionReason: suspensionReason,
      );

      // Notification au transporteur
      if (updated.profile != null) {
        await SupabaseService.instance.insertNotification(
          recipientId: updated.profile!.id,
          title: validate ? '✅ Compte validé !' : '⚠️ Compte suspendu',
          body: validate
              ? 'Félicitations ! Votre profil transporteur a été validé. Vous pouvez maintenant recevoir des demandes.'
              : 'Votre compte a été suspendu. Raison : $suspensionReason',
          type: validate ? 'validation_approved' : 'validation_rejected',
        );
      }

      _pendingTransporters.removeWhere((t) => t.id == transporterId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBusinessRule(String ruleId, Map<String, dynamic> value) async {
    try {
      await SupabaseService.instance.updateBusinessRule(ruleId, value);
      await _loadBusinessRules();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupervisorTier({
    required String supervisorId,
    required SupervisorTier tier,
  }) async {
    try {
      int maxTransporters;
      switch (tier) {
        case SupervisorTier.silver:   maxTransporters = 20;  break;
        case SupervisorTier.gold:     maxTransporters = 50;  break;
        case SupervisorTier.platinum: maxTransporters = 150; break;
      }

      await SupabaseService.instance.updateSupervisor(supervisorId, {
        'tier': tier.name,
        'max_transporters': maxTransporters,
      });
      await _loadSupervisors();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleSupervisorCommission({
    required String supervisorId,
    required bool active,
    String? reason,
  }) async {
    try {
      await SupabaseService.instance.updateSupervisor(supervisorId, {
        'is_commission_active': active,
        'commission_suspended_reason': active ? null : reason,
      });
      await _loadSupervisors();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
