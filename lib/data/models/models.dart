// lib/data/models/profile_model.dart
import 'package:flutter/material.dart';

enum UserRole { admin, supervisor, transporter, public }

enum BadgeLevel { bronze, silver, gold, platinum }

enum RequestStatus { pending, accepted, inProgress, completed, cancelled }

enum PaymentStatus { pending, paid, refunded }

enum CommissionStatus { pending, paid, cancelled }

enum SupervisorTier { silver, gold, platinum }

enum PremiumType { visibility, locationInterval, badgeBoost }

enum ListingType { product, service }

enum ListingStatus { active, sold, paused, removed }

enum BoutiqueStatus { pending, validated, suspended }

// ─────────────────────────────────────────────────────────────────
// PROFILE
// ─────────────────────────────────────────────────────────────────
class ProfileModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final bool isActive;
  final bool isEmailVerified;
  final String? regionId;
  final DateTime? lastSeen;
  final DateTime createdAt;

  const ProfileModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.isActive = true,
    this.isEmailVerified = false,
    this.regionId,
    this.lastSeen,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> j) => ProfileModel(
        id: j['id'] as String,
        firebaseUid: j['firebase_uid'] as String,
        email: j['email'] as String,
        fullName: j['full_name'] as String?,
        phone: j['phone'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        role: UserRole.values.firstWhere((e) => e.name == j['role'], orElse: () => UserRole.public),
        isActive: j['is_active'] as bool? ?? true,
        isEmailVerified: j['is_email_verified'] as bool? ?? false,
        regionId: j['region_id'] as String?,
        lastSeen: j['last_seen'] != null ? DateTime.parse(j['last_seen'] as String) : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'firebase_uid': firebaseUid,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'role': role.name,
        'is_active': isActive,
        'region_id': regionId,
      };

  ProfileModel copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    UserRole? role,
    bool? isActive,
    String? regionId,
  }) =>
      ProfileModel(
        id: id,
        firebaseUid: firebaseUid,
        email: email,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        isEmailVerified: isEmailVerified,
        regionId: regionId ?? this.regionId,
        lastSeen: lastSeen,
        createdAt: createdAt,
      );

  String get displayName => fullName ?? email.split('@').first;

  Color get roleColor {
    switch (role) {
      case UserRole.admin:       return const Color(0xFFE53935);
      case UserRole.supervisor:  return const Color(0xFF9C27B0);
      case UserRole.transporter: return const Color(0xFFFF6B35);
      case UserRole.public:      return const Color(0xFF2196F3);
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.admin:       return 'Administrateur';
      case UserRole.supervisor:  return 'Superviseur';
      case UserRole.transporter: return 'Transporteur';
      case UserRole.public:      return 'Client';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// TRANSPORTER
// ─────────────────────────────────────────────────────────────────
class TransporterModel {
  final String id;
  final String profileId;
  final String vehicleType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final int? vehicleYear;
  final String vehiclePlate;
  final double? vehicleCapacityKg;
  final double? vehicleCapacityM3;
  final String vehiclePhotoUrl;

  // Docs optionnels
  final String? facePhotoUrl;
  final String? licensePhotoUrl;
  final String? registrationPhotoUrl;
  final String? insurancePhotoUrl;
  final String? technicalControlUrl;

  // Validation
  final bool isValidated;
  final int validationScore;
  final BadgeLevel? badge;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? suspensionReason;

  // Disponibilité & services
  final bool isAvailable;
  final bool offersHandling;
  final double handlingFeeRate;
  final bool offersTransportInsurance;
  final double insuranceRatePercent;

  // Tarifs
  final double? basePricePerKm;
  final double? minimumPrice;

  // Premium
  final bool isPremium;
  final DateTime? premiumUntil;
  final PremiumType? premiumType;
  final int locationIntervalSeconds;

  // Stats
  final double averageRating;
  final int totalRatings;
  final int totalTransports;

  // Localisation
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastLocationAt;
  final double? distanceKm; // calculé côté client ou SQL

  // Profil associé (JOIN)
  final ProfileModel? profile;

  final String? regionId;
  final DateTime createdAt;

  const TransporterModel({
    required this.id,
    required this.profileId,
    required this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    required this.vehiclePlate,
    this.vehicleCapacityKg,
    this.vehicleCapacityM3,
    required this.vehiclePhotoUrl,
    this.facePhotoUrl,
    this.licensePhotoUrl,
    this.registrationPhotoUrl,
    this.insurancePhotoUrl,
    this.technicalControlUrl,
    this.isValidated = false,
    this.validationScore = 0,
    this.badge,
    this.validatedBy,
    this.validatedAt,
    this.suspensionReason,
    this.isAvailable = false,
    this.offersHandling = false,
    this.handlingFeeRate = 0,
    this.offersTransportInsurance = false,
    this.insuranceRatePercent = 0,
    this.basePricePerKm,
    this.minimumPrice,
    this.isPremium = false,
    this.premiumUntil,
    this.premiumType,
    this.locationIntervalSeconds = 30,
    this.averageRating = 0,
    this.totalRatings = 0,
    this.totalTransports = 0,
    this.currentLat,
    this.currentLng,
    this.lastLocationAt,
    this.distanceKm,
    this.profile,
    this.regionId,
    required this.createdAt,
  });

  factory TransporterModel.fromJson(Map<String, dynamic> j) => TransporterModel(
        id: j['id'] as String,
        profileId: j['profile_id'] as String,
        vehicleType: j['vehicle_type'] as String,
        vehicleBrand: j['vehicle_brand'] as String?,
        vehicleModel: j['vehicle_model'] as String?,
        vehicleYear: j['vehicle_year'] as int?,
        vehiclePlate: j['vehicle_plate'] as String,
        vehicleCapacityKg: (j['vehicle_capacity_kg'] as num?)?.toDouble(),
        vehicleCapacityM3: (j['vehicle_capacity_m3'] as num?)?.toDouble(),
        vehiclePhotoUrl: j['vehicle_photo_url'] as String,
        facePhotoUrl: j['face_photo_url'] as String?,
        licensePhotoUrl: j['license_photo_url'] as String?,
        registrationPhotoUrl: j['registration_photo_url'] as String?,
        insurancePhotoUrl: j['insurance_photo_url'] as String?,
        technicalControlUrl: j['technical_control_url'] as String?,
        isValidated: j['is_validated'] as bool? ?? false,
        validationScore: j['validation_score'] as int? ?? 0,
        badge: j['badge'] != null
            ? BadgeLevel.values.firstWhere((e) => e.name == j['badge'], orElse: () => BadgeLevel.bronze)
            : null,
        validatedBy: j['validated_by'] as String?,
        validatedAt: j['validated_at'] != null ? DateTime.parse(j['validated_at'] as String) : null,
        suspensionReason: j['suspension_reason'] as String?,
        isAvailable: j['is_available'] as bool? ?? false,
        offersHandling: j['offers_handling'] as bool? ?? false,
        handlingFeeRate: (j['handling_fee_rate'] as num?)?.toDouble() ?? 0,
        offersTransportInsurance: j['offers_transport_insurance'] as bool? ?? false,
        insuranceRatePercent: (j['insurance_rate_percent'] as num?)?.toDouble() ?? 0,
        basePricePerKm: (j['base_price_per_km'] as num?)?.toDouble(),
        minimumPrice: (j['minimum_price'] as num?)?.toDouble(),
        isPremium: j['is_premium'] as bool? ?? false,
        premiumUntil: j['premium_until'] != null ? DateTime.parse(j['premium_until'] as String) : null,
        premiumType: j['premium_type'] != null
            ? PremiumType.values.firstWhere((e) => e.name == j['premium_type'], orElse: () => PremiumType.visibility)
            : null,
        locationIntervalSeconds: j['location_interval_seconds'] as int? ?? 30,
        averageRating: (j['average_rating'] as num?)?.toDouble() ?? 0,
        totalRatings: j['total_ratings'] as int? ?? 0,
        totalTransports: j['total_transports'] as int? ?? 0,
        currentLat: (j['current_lat'] as num?)?.toDouble(),
        currentLng: (j['current_lng'] as num?)?.toDouble(),
        lastLocationAt: j['last_location_at'] != null ? DateTime.parse(j['last_location_at'] as String) : null,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        profile: j['profiles'] != null
            ? ProfileModel.fromJson(j['profiles'] as Map<String, dynamic>)
            : null,
        regionId: j['region_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'vehicle_type': vehicleType,
        'vehicle_brand': vehicleBrand,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_plate': vehiclePlate,
        'vehicle_capacity_kg': vehicleCapacityKg,
        'vehicle_capacity_m3': vehicleCapacityM3,
        'vehicle_photo_url': vehiclePhotoUrl,
        'face_photo_url': facePhotoUrl,
        'license_photo_url': licensePhotoUrl,
        'registration_photo_url': registrationPhotoUrl,
        'insurance_photo_url': insurancePhotoUrl,
        'technical_control_url': technicalControlUrl,
        'is_available': isAvailable,
        'offers_handling': offersHandling,
        'handling_fee_rate': handlingFeeRate,
        'offers_transport_insurance': offersTransportInsurance,
        'insurance_rate_percent': insuranceRatePercent,
        'base_price_per_km': basePricePerKm,
        'minimum_price': minimumPrice,
        'region_id': regionId,
      };

  Color get badgeColor {
    switch (badge) {
      case BadgeLevel.platinum: return const Color(0xFFB0BEC5);
      case BadgeLevel.gold:     return const Color(0xFFFFD700);
      case BadgeLevel.silver:   return const Color(0xFF9E9E9E);
      case BadgeLevel.bronze:   return const Color(0xFFCD7F32);
      case null:                return const Color(0xFFEEEEEE);
    }
  }

  String get badgeLabel {
    switch (badge) {
      case BadgeLevel.platinum: return 'Platine';
      case BadgeLevel.gold:     return 'Or';
      case BadgeLevel.silver:   return 'Argent';
      case BadgeLevel.bronze:   return 'Bronze';
      case null:                return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// TRANSPORT REQUEST
// ─────────────────────────────────────────────────────────────────
class TransportRequestModel {
  final String id;
  final String clientId;
  final String? transporterId;

  final double pickupLat;
  final double pickupLng;
  final String? pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String? dropoffAddress;
  final double? estimatedDistanceKm;
  final int? estimatedDurationMin;

  final String? cargoDescription;
  final double? cargoWeightKg;
  final bool needsHandling;
  final bool needsTransportInsurance;

  final double? basePrice;
  final double handlingFee;
  final double insuranceFee;
  final double? totalPrice;
  final String currency;

  final double? appCommissionAmount;
  final double? supervisorCommissionAmount;
  final double? transporterNetAmount;

  final RequestStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentBoutiqueId;

  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? regionId;

  // JOIN
  final ProfileModel? client;
  final TransporterModel? transporter;

  const TransportRequestModel({
    required this.id,
    required this.clientId,
    this.transporterId,
    required this.pickupLat,
    required this.pickupLng,
    this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    this.dropoffAddress,
    this.estimatedDistanceKm,
    this.estimatedDurationMin,
    this.cargoDescription,
    this.cargoWeightKg,
    this.needsHandling = false,
    this.needsTransportInsurance = false,
    this.basePrice,
    this.handlingFee = 0,
    this.insuranceFee = 0,
    this.totalPrice,
    this.currency = 'DZD',
    this.appCommissionAmount,
    this.supervisorCommissionAmount,
    this.transporterNetAmount,
    this.status = RequestStatus.pending,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentBoutiqueId,
    required this.requestedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.regionId,
    this.client,
    this.transporter,
  });

  factory TransportRequestModel.fromJson(Map<String, dynamic> j) => TransportRequestModel(
        id: j['id'] as String,
        clientId: j['client_id'] as String,
        transporterId: j['transporter_id'] as String?,
        pickupLat: (j['pickup_lat'] as num).toDouble(),
        pickupLng: (j['pickup_lng'] as num).toDouble(),
        pickupAddress: j['pickup_address'] as String?,
        dropoffLat: (j['dropoff_lat'] as num).toDouble(),
        dropoffLng: (j['dropoff_lng'] as num).toDouble(),
        dropoffAddress: j['dropoff_address'] as String?,
        estimatedDistanceKm: (j['estimated_distance_km'] as num?)?.toDouble(),
        estimatedDurationMin: j['estimated_duration_min'] as int?,
        cargoDescription: j['cargo_description'] as String?,
        cargoWeightKg: (j['cargo_weight_kg'] as num?)?.toDouble(),
        needsHandling: j['needs_handling'] as bool? ?? false,
        needsTransportInsurance: j['needs_transport_insurance'] as bool? ?? false,
        basePrice: (j['base_price'] as num?)?.toDouble(),
        handlingFee: (j['handling_fee'] as num?)?.toDouble() ?? 0,
        insuranceFee: (j['insurance_fee'] as num?)?.toDouble() ?? 0,
        totalPrice: (j['total_price'] as num?)?.toDouble(),
        currency: j['currency'] as String? ?? 'DZD',
        appCommissionAmount: (j['app_commission_amount'] as num?)?.toDouble(),
        supervisorCommissionAmount: (j['supervisor_commission_amount'] as num?)?.toDouble(),
        transporterNetAmount: (j['transporter_net_amount'] as num?)?.toDouble(),
        status: _parseStatus(j['status'] as String? ?? 'pending'),
        paymentStatus: PaymentStatus.values.firstWhere(
          (e) => e.name == j['payment_status'],
          orElse: () => PaymentStatus.pending,
        ),
        paymentBoutiqueId: j['payment_boutique_id'] as String?,
        requestedAt: DateTime.parse(j['requested_at'] as String),
        acceptedAt: j['accepted_at'] != null ? DateTime.parse(j['accepted_at'] as String) : null,
        startedAt: j['started_at'] != null ? DateTime.parse(j['started_at'] as String) : null,
        completedAt: j['completed_at'] != null ? DateTime.parse(j['completed_at'] as String) : null,
        cancelledAt: j['cancelled_at'] != null ? DateTime.parse(j['cancelled_at'] as String) : null,
        cancellationReason: j['cancellation_reason'] as String?,
        regionId: j['region_id'] as String?,
        client: j['profiles'] != null
            ? ProfileModel.fromJson(j['profiles'] as Map<String, dynamic>)
            : null,
      );

  String get statusLabel {
    switch (status) {
      case RequestStatus.pending:    return 'En attente';
      case RequestStatus.accepted:   return 'Accepté';
      case RequestStatus.inProgress: return 'En cours';
      case RequestStatus.completed:  return 'Terminé';
      case RequestStatus.cancelled:  return 'Annulé';
    }
  }

  Color get statusColor {
    switch (status) {
      case RequestStatus.pending:    return const Color(0xFFFFC107);
      case RequestStatus.accepted:   return const Color(0xFF2196F3);
      case RequestStatus.inProgress: return const Color(0xFFFF6B35);
      case RequestStatus.completed:  return const Color(0xFF4CAF50);
      case RequestStatus.cancelled:  return const Color(0xFFE53935);
    }
  }

  // Ajouter la fonction statique :
  static RequestStatus _parseStatus(String raw) {
    const map = {
      'pending':     RequestStatus.pending,
      'accepted':    RequestStatus.accepted,
      'in_progress': RequestStatus.inProgress,
      'inProgress':  RequestStatus.inProgress,
      'completed':   RequestStatus.completed,
      'cancelled':   RequestStatus.cancelled,
    };
    return map[raw] ?? RequestStatus.pending;
  }
}

// ─────────────────────────────────────────────────────────────────
// TRACKING POINT
// ─────────────────────────────────────────────────────────────────
class TrackingModel {
  final String id;
  final String requestId;
  final String transporterId;
  final double lat;
  final double lng;
  final double? speedKmh;
  final double? heading;
  final double? accuracyM;
  final DateTime recordedAt;

  const TrackingModel({
    required this.id,
    required this.requestId,
    required this.transporterId,
    required this.lat,
    required this.lng,
    this.speedKmh,
    this.heading,
    this.accuracyM,
    required this.recordedAt,
  });

  factory TrackingModel.fromJson(Map<String, dynamic> j) => TrackingModel(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        transporterId: j['transporter_id'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        speedKmh: (j['speed_kmh'] as num?)?.toDouble(),
        heading: (j['heading'] as num?)?.toDouble(),
        accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
        recordedAt: DateTime.parse(j['recorded_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'transporter_id': transporterId,
        'lat': lat,
        'lng': lng,
        'speed_kmh': speedKmh,
        'heading': heading,
        'accuracy_m': accuracyM,
      };
}

// ─────────────────────────────────────────────────────────────────
// RATING
// ─────────────────────────────────────────────────────────────────
class RatingModel {
  final String id;
  final String requestId;
  final String transporterId;
  final String clientId;
  final int score;
  final String? comment;
  final bool isVisible;
  final DateTime createdAt;
  final ProfileModel? client;

  const RatingModel({
    required this.id,
    required this.requestId,
    required this.transporterId,
    required this.clientId,
    required this.score,
    this.comment,
    this.isVisible = true,
    required this.createdAt,
    this.client,
  });

  factory RatingModel.fromJson(Map<String, dynamic> j) => RatingModel(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        transporterId: j['transporter_id'] as String,
        clientId: j['client_id'] as String,
        score: j['score'] as int,
        comment: j['comment'] as String?,
        isVisible: j['is_visible'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
        client: j['profiles'] != null
            ? ProfileModel.fromJson(j['profiles'] as Map<String, dynamic>)
            : null,
      );
}

// ─────────────────────────────────────────────────────────────────
// SUPERVISOR
// ─────────────────────────────────────────────────────────────────
class SupervisorModel {
  final String id;
  final String profileId;
  final SupervisorTier tier;
  final int maxTransporters;
  final double commissionFromTransportsRate;
  final double commissionToAppRate;
  final String? currentMonthYear;
  final int transportersAddedThisMonth;
  final int minMonthlyAddRequired;
  final bool isCommissionActive;
  final String? commissionSuspendedReason;
  final double totalGrossEarnings;
  final double totalAppFeesPaid;
  final double totalNetEarnings;
  final String? parentSupervisorId;
  final String? referralCode;
  final String? regionId;
  final DateTime createdAt;
  final ProfileModel? profile;
  final List<SupervisorReferralModel> referrals;

  const SupervisorModel({
    required this.id,
    required this.profileId,
    required this.tier,
    required this.maxTransporters,
    required this.commissionFromTransportsRate,
    required this.commissionToAppRate,
    this.currentMonthYear,
    this.transportersAddedThisMonth = 0,
    required this.minMonthlyAddRequired,
    this.isCommissionActive = true,
    this.commissionSuspendedReason,
    this.totalGrossEarnings = 0,
    this.totalAppFeesPaid = 0,
    this.totalNetEarnings = 0,
    this.parentSupervisorId,
    this.referralCode,
    this.regionId,
    required this.createdAt,
    this.profile,
    this.referrals = const [],
  });

  factory SupervisorModel.fromJson(Map<String, dynamic> j) => SupervisorModel(
        id: j['id'] as String,
        profileId: j['profile_id'] as String,
        tier: SupervisorTier.values.firstWhere((e) => e.name == j['tier'], orElse: () => SupervisorTier.silver),
        maxTransporters: j['max_transporters'] as int? ?? 20,
        commissionFromTransportsRate: (j['commission_from_transports_rate'] as num?)?.toDouble() ?? 5.0,
        commissionToAppRate: (j['commission_to_app_rate'] as num?)?.toDouble() ?? 2.0,
        currentMonthYear: j['current_month_year'] as String?,
        transportersAddedThisMonth: j['transporters_added_this_month'] as int? ?? 0,
        minMonthlyAddRequired: j['min_monthly_add_required'] as int? ?? 5,
        isCommissionActive: j['is_commission_active'] as bool? ?? true,
        commissionSuspendedReason: j['commission_suspended_reason'] as String?,
        totalGrossEarnings: (j['total_gross_earnings'] as num?)?.toDouble() ?? 0,
        totalAppFeesPaid: (j['total_app_fees_paid'] as num?)?.toDouble() ?? 0,
        totalNetEarnings: (j['total_net_earnings'] as num?)?.toDouble() ?? 0,
        parentSupervisorId: j['parent_supervisor_id'] as String?,
        referralCode: j['referral_code'] as String?,
        regionId: j['region_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        profile: j['profiles'] != null ? ProfileModel.fromJson(j['profiles'] as Map<String, dynamic>) : null,
        referrals: j['supervisor_referrals'] != null
            ? (j['supervisor_referrals'] as List).map((e) => SupervisorReferralModel.fromJson(e as Map<String, dynamic>)).toList()
            : [],
      );

  int get remainingSlots => maxTransporters - referrals.where((r) => r.isActive).length;
  bool get needsMoreAdds => transportersAddedThisMonth < minMonthlyAddRequired;

  String get tierLabel {
    switch (tier) {
      case SupervisorTier.silver:   return 'Argent';
      case SupervisorTier.gold:     return 'Or';
      case SupervisorTier.platinum: return 'Platine';
    }
  }
}

class SupervisorReferralModel {
  final String id;
  final String supervisorId;
  final String transporterId;
  final DateTime joinedAt;
  final bool isActive;
  final TransporterModel? transporter;

  const SupervisorReferralModel({
    required this.id,
    required this.supervisorId,
    required this.transporterId,
    required this.joinedAt,
    this.isActive = true,
    this.transporter,
  });

  factory SupervisorReferralModel.fromJson(Map<String, dynamic> j) => SupervisorReferralModel(
        id: j['id'] as String,
        supervisorId: j['supervisor_id'] as String,
        transporterId: j['transporter_id'] as String,
        joinedAt: DateTime.parse(j['joined_at'] as String),
        isActive: j['is_active'] as bool? ?? true,
        transporter: j['transporters'] != null
            ? TransporterModel.fromJson(j['transporters'] as Map<String, dynamic>)
            : null,
      );
}

// ─────────────────────────────────────────────────────────────────
// PREMIUM OPTION
// ─────────────────────────────────────────────────────────────────
class PremiumOptionModel {
  final String id;
  final String name;
  final PremiumType type;
  final String? description;
  final int durationDays;
  final double price;
  final String currency;
  final int? locationIntervalSeconds;
  final int positionBoost;
  final bool isActive;
  final String? regionId;
  final int sortOrder;

  const PremiumOptionModel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    required this.durationDays,
    required this.price,
    this.currency = 'DZD',
    this.locationIntervalSeconds,
    this.positionBoost = 0,
    this.isActive = true,
    this.regionId,
    this.sortOrder = 0,
  });

  factory PremiumOptionModel.fromJson(Map<String, dynamic> j) => PremiumOptionModel(
        id: j['id'] as String,
        name: j['name'] as String,
        type: PremiumType.values.firstWhere(
          (e) => e.name == (j['type'] as String).replaceAll('_', ''),
          orElse: () => PremiumType.visibility,
        ),
        description: j['description'] as String?,
        durationDays: j['duration_days'] as int,
        price: (j['price'] as num).toDouble(),
        currency: j['currency'] as String? ?? 'DZD',
        locationIntervalSeconds: j['location_interval_seconds'] as int?,
        positionBoost: j['position_boost'] as int? ?? 0,
        isActive: j['is_active'] as bool? ?? true,
        regionId: j['region_id'] as String?,
        sortOrder: j['sort_order'] as int? ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────────
// MARKETPLACE LISTING
// ─────────────────────────────────────────────────────────────────
class MarketplaceListingModel {
  final String id;
  final String sellerId;
  final String title;
  final String? description;
  final String? categoryId;
  final ListingType type;
  final double? price;
  final bool isPriceNegotiable;
  final String currency;
  final List<String> imagesUrls;
  final String? regionId;
  final String? city;
  final ListingStatus status;
  final double commissionRate;
  final bool isPremium;
  final DateTime? premiumUntil;
  final int viewsCount;
  final bool isVerified;
  final DateTime createdAt;
  final ProfileModel? seller;

  const MarketplaceListingModel({
    required this.id,
    required this.sellerId,
    required this.title,
    this.description,
    this.categoryId,
    required this.type,
    this.price,
    this.isPriceNegotiable = false,
    this.currency = 'DZD',
    this.imagesUrls = const [],
    this.regionId,
    this.city,
    this.status = ListingStatus.active,
    this.commissionRate = 5.0,
    this.isPremium = false,
    this.premiumUntil,
    this.viewsCount = 0,
    this.isVerified = false,
    required this.createdAt,
    this.seller,
  });

  factory MarketplaceListingModel.fromJson(Map<String, dynamic> j) => MarketplaceListingModel(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        categoryId: j['category_id'] as String?,
        type: ListingType.values.firstWhere((e) => e.name == j['type'], orElse: () => ListingType.product),
        price: (j['price'] as num?)?.toDouble(),
        isPriceNegotiable: j['is_price_negotiable'] as bool? ?? false,
        currency: j['currency'] as String? ?? 'DZD',
        imagesUrls: (j['images_urls'] as List<dynamic>?)?.cast<String>() ?? [],
        regionId: j['region_id'] as String?,
        city: j['city'] as String?,
        status: ListingStatus.values.firstWhere((e) => e.name == j['status'], orElse: () => ListingStatus.active),
        commissionRate: (j['commission_rate'] as num?)?.toDouble() ?? 5.0,
        isPremium: j['is_premium'] as bool? ?? false,
        premiumUntil: j['premium_until'] != null ? DateTime.parse(j['premium_until'] as String) : null,
        viewsCount: j['views_count'] as int? ?? 0,
        isVerified: j['is_verified'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        seller: j['profiles'] != null ? ProfileModel.fromJson(j['profiles'] as Map<String, dynamic>) : null,
      );
}

// ─────────────────────────────────────────────────────────────────
// NOTIFICATION
// ─────────────────────────────────────────────────────────────────
class NotificationModel {
  final String id;
  final String recipientId;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? type;
  final bool isRead;
  final bool sentViaFcm;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    this.data = const {},
    this.type,
    this.isRead = false,
    this.sentViaFcm = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
        id: j['id'] as String,
        recipientId: j['recipient_id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        data: (j['data'] as Map<String, dynamic>?) ?? {},
        type: j['type'] as String?,
        isRead: j['is_read'] as bool? ?? false,
        sentViaFcm: j['sent_via_fcm'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ─────────────────────────────────────────────────────────────────
// REGION
// ─────────────────────────────────────────────────────────────────
class RegionModel {
  final String id;
  final String name;
  final String country;
  final String currency;
  final String currencySymbol;
  final bool isActive;

  const RegionModel({
    required this.id,
    required this.name,
    required this.country,
    required this.currency,
    required this.currencySymbol,
    this.isActive = true,
  });

  factory RegionModel.fromJson(Map<String, dynamic> j) => RegionModel(
        id: j['id'] as String,
        name: j['name'] as String,
        country: j['country'] as String,
        currency: j['currency'] as String,
        currencySymbol: j['currency_symbol'] as String? ?? 'DA',
        isActive: j['is_active'] as bool? ?? true,
      );
}

// ─────────────────────────────────────────────────────────────────
// BUSINESS RULE
// ─────────────────────────────────────────────────────────────────
class BusinessRuleModel {
  final String id;
  final String key;
  final Map<String, dynamic> value;
  final String? regionId;
  final String? appliesToRole;
  final String? description;

  const BusinessRuleModel({
    required this.id,
    required this.key,
    required this.value,
    this.regionId,
    this.appliesToRole,
    this.description,
  });

  factory BusinessRuleModel.fromJson(Map<String, dynamic> j) => BusinessRuleModel(
        id: j['id'] as String,
        key: j['key'] as String,
        value: (j['value'] as Map<String, dynamic>?) ?? {},
        regionId: j['region_id'] as String?,
        appliesToRole: j['applies_to_role'] as String?,
        description: j['description'] as String?,
      );

  dynamic get numericValue => value['rate'] ?? value['count'] ?? value['price'] ?? value['seconds'] ?? value['multiplier'];
}
