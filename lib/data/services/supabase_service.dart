// lib/data/services/supabase_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  // ─── PROFILES ────────────────────────────────────────────────

  Future<ProfileModel?> getProfileByFirebaseUid(String uid) async {
    final res = await client
        .from(AppConstants.tProfiles)
        .select()
        .eq('firebase_uid', uid)
        .maybeSingle();
    return res != null ? ProfileModel.fromJson(res) : null;
  }

  Future<ProfileModel> createProfile({
    required String firebaseUid,
    required String email,
    required UserRole role,
    String? fullName,
    String? phone,
    String? regionId,
  }) async {
    final res = await client
        .from(AppConstants.tProfiles)
        .insert({
          'firebase_uid': firebaseUid,
          'email': email,
          'role': role.name,
          'full_name': fullName,
          'phone': phone,
          'region_id': regionId,
        })
        .select()
        .single();
    return ProfileModel.fromJson(res);
  }

  Future<ProfileModel> updateProfile(String profileId, Map<String, dynamic> data) async {
    final res = await client
        .from(AppConstants.tProfiles)
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', profileId)
        .select()
        .single();
    return ProfileModel.fromJson(res);
  }

  Future<void> updateLastSeen(String profileId) async {
    await client
        .from(AppConstants.tProfiles)
        .update({'last_seen': DateTime.now().toIso8601String()})
        .eq('id', profileId);
  }

  // ─── FCM TOKENS ──────────────────────────────────────────────

  Future<void> upsertFcmToken({
    required String profileId,
    required String token,
    required String platform,
  }) async {
    await client.from(AppConstants.tFcmTokens).upsert({
      'profile_id': profileId,
      'token': token,
      'platform': platform,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'profile_id,platform');
  }

  // ─── TRANSPORTERS ─────────────────────────────────────────────

  Future<TransporterModel?> getTransporterByProfileId(String profileId) async {
    final res = await client
        .from(AppConstants.tTransporters)
        .select('*, profiles(*)')
        .eq('profile_id', profileId)
        .maybeSingle();
    return res != null ? TransporterModel.fromJson(res) : null;
  }

  Future<TransporterModel> createTransporter(Map<String, dynamic> data) async {
    final res = await client
        .from(AppConstants.tTransporters)
        .insert(data)
        .select('*, profiles(*)')
        .single();
    return TransporterModel.fromJson(res);
  }

  Future<TransporterModel> updateTransporter(String transporterId, Map<String, dynamic> data) async {
    final res = await client
        .from(AppConstants.tTransporters)
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', transporterId)
        .select('*, profiles(*)')
        .single();
    return TransporterModel.fromJson(res);
  }

  Future<List<TransporterModel>> getNearbyTransporters({
    required double lat,
    required double lng,
    double radiusKm = 50,
    String? vehicleType,
  }) async {
    final res = await client.rpc('get_nearby_transporters', params: {
      'user_lat': lat,
      'user_lng': lng,
      'radius_km': radiusKm,
      'vehicle_type_filter': vehicleType,
    });
    return (res as List).map((e) => TransporterModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateTransporterLocation({
    required String transporterId,
    required double lat,
    required double lng,
  }) async {
    await client.from(AppConstants.tTransporters).update({
      'current_lat': lat,
      'current_lng': lng,
      'last_location_at': DateTime.now().toIso8601String(),
    }).eq('id', transporterId);
  }

  Future<void> toggleTransporterAvailability(String transporterId, bool isAvailable) async {
    await client.from(AppConstants.tTransporters)
        .update({'is_available': isAvailable})
        .eq('id', transporterId);
  }

  Future<List<TransporterModel>> getPendingValidationTransporters() async {
    final res = await client
        .from(AppConstants.tTransporters)
        .select('*, profiles(*)')
        .eq('is_validated', false)
        .order('created_at');
    return (res as List).map((e) => TransporterModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TransporterModel> validateTransporter({
    required String transporterId,
    required String adminProfileId,
    bool validate = true,
    String? suspensionReason,
  }) async {
    final res = await client
        .from(AppConstants.tTransporters)
        .update({
          'is_validated': validate,
          'validated_by': adminProfileId,
          'validated_at': DateTime.now().toIso8601String(),
          'suspension_reason': suspensionReason,
        })
        .eq('id', transporterId)
        .select('*, profiles(*)')
        .single();
    return TransporterModel.fromJson(res);
  }

  // ─── TRANSPORT REQUESTS ───────────────────────────────────────

  Future<TransportRequestModel> createRequest(Map<String, dynamic> data) async {
    final res = await client
        .from(AppConstants.tRequests)
        .insert(data)
        .select()
        .single();
    return TransportRequestModel.fromJson(res);
  }

  Future<TransportRequestModel> updateRequestStatus({
    required String requestId,
    required RequestStatus status,
    Map<String, dynamic>? extra,
  }) async {
    final Map<String, dynamic> updateData = {'status': status.name};

    switch (status) {
      case RequestStatus.accepted:
        updateData['accepted_at'] = DateTime.now().toIso8601String();
        break;
      case RequestStatus.inProgress:
        updateData['started_at'] = DateTime.now().toIso8601String();
        break;
      case RequestStatus.completed:
        updateData['completed_at'] = DateTime.now().toIso8601String();
        break;
      case RequestStatus.cancelled:
        updateData['cancelled_at'] = DateTime.now().toIso8601String();
        break;
      default:
        break;
    }

    if (extra != null) updateData.addAll(extra);

    final res = await client
        .from(AppConstants.tRequests)
        .update(updateData)
        .eq('id', requestId)
        .select()
        .single();
    return TransportRequestModel.fromJson(res);
  }

  Future<List<TransportRequestModel>> getClientRequests(String clientId) async {
    final res = await client
        .from(AppConstants.tRequests)
        .select()
        .eq('client_id', clientId)
        .order('requested_at', ascending: false)
        .limit(AppConstants.pageSize);
    return (res as List).map((e) => TransportRequestModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TransportRequestModel>> getTransporterRequests(String transporterId) async {
    final res = await client
        .from(AppConstants.tRequests)
        .select()
        .eq('transporter_id', transporterId)
        .order('requested_at', ascending: false)
        .limit(AppConstants.pageSize);
    return (res as List).map((e) => TransportRequestModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TransportRequestModel>> getPendingRequests() async {
    final res = await client
        .from(AppConstants.tRequests)
        .select()
        .eq('status', 'pending')
        .order('requested_at');
    return (res as List).map((e) => TransportRequestModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── TRACKING ─────────────────────────────────────────────────

  Future<void> insertTracking(TrackingModel tracking) async {
    await client.from(AppConstants.tTrackings).insert(tracking.toJson());
  }

  Future<List<TrackingModel>> getRequestTrackings(String requestId) async {
    final res = await client
        .from(AppConstants.tTrackings)
        .select()
        .eq('request_id', requestId)
        .order('recorded_at');
    return (res as List).map((e) => TrackingModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Realtime subscription for tracking
  RealtimeChannel subscribeToTracking({
    required String requestId,
    required void Function(TrackingModel) onData,
  }) {
    return client
        .channel('tracking_$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.tTrackings,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: requestId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onData(TrackingModel.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  // Realtime subscription for request status
  RealtimeChannel subscribeToRequest({
    required String requestId,
    required void Function(TransportRequestModel) onData,
  }) {
    return client
        .channel('request_$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConstants.tRequests,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: requestId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onData(TransportRequestModel.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  // Realtime: transporteur écoute les nouvelles demandes
  RealtimeChannel subscribeToNewRequests({
    required void Function(TransportRequestModel) onData,
  }) {
    return client
        .channel('new_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.tRequests,
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onData(TransportRequestModel.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  void unsubscribeChannel(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  // ─── RATINGS ──────────────────────────────────────────────────

  Future<RatingModel> createRating({
    required String requestId,
    required String transporterId,
    required String clientId,
    required int score,
    String? comment,
  }) async {
    final res = await client.from(AppConstants.tRatings).insert({
      'request_id': requestId,
      'transporter_id': transporterId,
      'client_id': clientId,
      'score': score,
      'comment': comment,
    }).select().single();
    return RatingModel.fromJson(res);
  }

  Future<List<RatingModel>> getTransporterRatings(String transporterId) async {
    final res = await client
        .from(AppConstants.tRatings)
        .select('*, profiles(*)')
        .eq('transporter_id', transporterId)
        .eq('is_visible', true)
        .order('created_at', ascending: false)
        .limit(AppConstants.pageSize);
    return (res as List).map((e) => RatingModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── SUPERVISORS ──────────────────────────────────────────────

  Future<SupervisorModel?> getSupervisorByProfileId(String profileId) async {
    final res = await client
        .from(AppConstants.tSupervisors)
        .select('*, profiles(*), supervisor_referrals(*, transporters(*, profiles(*)))')
        .eq('profile_id', profileId)
        .maybeSingle();
    return res != null ? SupervisorModel.fromJson(res) : null;
  }

  Future<SupervisorModel> createSupervisor(String profileId, {String? regionId}) async {
    final res = await client.from(AppConstants.tSupervisors).insert({
      'profile_id': profileId,
      'region_id': regionId,
    }).select('*, profiles(*)').single();
    return SupervisorModel.fromJson(res);
  }

  Future<void> addTransporterReferral({
    required String supervisorId,
    required String transporterId,
  }) async {
    await client.from(AppConstants.tSupervisorReferrals).insert({
      'supervisor_id': supervisorId,
      'transporter_id': transporterId,
    });
  }

  Future<List<SupervisorModel>> getAllSupervisors() async {
    final res = await client
        .from(AppConstants.tSupervisors)
        .select('*, profiles(*)')
        .order('created_at', ascending: false);
    return (res as List).map((e) => SupervisorModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateSupervisor(String supervisorId, Map<String, dynamic> data) async {
    await client.from(AppConstants.tSupervisors)
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', supervisorId);
  }

  // ─── PREMIUM OPTIONS ──────────────────────────────────────────

  Future<List<PremiumOptionModel>> getPremiumOptions({String? regionId}) async {
    var query = client
        .from(AppConstants.tPremiumOptions)
        .select()
        .eq('is_active', true)
        .order('sort_order');

    final res = await query;
    return (res as List).map((e) => PremiumOptionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createPremiumPurchase({
    required String transporterId,
    required String optionId,
    required String boutiqueId,
    required double amountPaid,
    required int durationDays,
  }) async {
    final endsAt = DateTime.now().add(Duration(days: durationDays));
    await client.from(AppConstants.tPremiumPurchases).insert({
      'transporter_id': transporterId,
      'option_id': optionId,
      'boutique_id': boutiqueId,
      'amount_paid': amountPaid,
      'ends_at': endsAt.toIso8601String(),
      'status': 'pending_payment',
    });
  }

  Future<void> validatePremiumPurchase({
    required String purchaseId,
    required String validatorProfileId,
    required String transporterId,
    required PremiumOptionModel option,
  }) async {
    final endsAt = DateTime.now().add(Duration(days: option.durationDays));

    await client.from(AppConstants.tPremiumPurchases).update({
      'status': 'active',
      'validated_by': validatorProfileId,
      'validated_at': DateTime.now().toIso8601String(),
      'starts_at': DateTime.now().toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
    }).eq('id', purchaseId);

    await client.from(AppConstants.tTransporters).update({
      'is_premium': true,
      'premium_until': endsAt.toIso8601String(),
      'premium_type': option.type.name,
      if (option.locationIntervalSeconds != null)
        'location_interval_seconds': option.locationIntervalSeconds,
    }).eq('id', transporterId);
  }

  // ─── BOUTIQUES ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBoutiques({String? regionId}) async {
    var query = client
        .from(AppConstants.tBoutiques)
        .select()
        .eq('is_active', true)
        .eq('status', 'validated');
    final res = await query;
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ─── MARKETPLACE ──────────────────────────────────────────────

  Future<List<MarketplaceListingModel>> getListings({
    String? categoryId,
    String? regionId,
    ListingType? type,
    int page = 0,
  }) async {
    var query = client
        .from(AppConstants.tMarketplaceListings)
        .select('*, profiles(*)')
        .eq('status', 'active')
        .order('is_premium', ascending: false)
        .order('created_at', ascending: false)
        .range(page * AppConstants.pageSize, (page + 1) * AppConstants.pageSize - 1);

    final res = await query;
    return (res as List).map((e) => MarketplaceListingModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MarketplaceListingModel> createListing(Map<String, dynamic> data) async {
    final res = await client
        .from(AppConstants.tMarketplaceListings)
        .insert(data)
        .select('*, profiles(*)')
        .single();
    return MarketplaceListingModel.fromJson(res);
  }

  // ─── NOTIFICATIONS ────────────────────────────────────────────

  Future<void> insertNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? type,
  }) async {
    await client.from(AppConstants.tNotifications).insert({
      'recipient_id': recipientId,
      'title': title,
      'body': body,
      'data': data ?? {},
      'type': type,
    });
  }

  Future<List<NotificationModel>> getNotifications(String profileId) async {
    final res = await client
        .from(AppConstants.tNotifications)
        .select()
        .eq('recipient_id', profileId)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markNotificationRead(String notifId) async {
    await client.from(AppConstants.tNotifications).update({'is_read': true}).eq('id', notifId);
  }

  RealtimeChannel subscribeToNotifications({
    required String profileId,
    required void Function(NotificationModel) onData,
  }) {
    return client
        .channel('notifs_$profileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.tNotifications,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: profileId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onData(NotificationModel.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  // ─── BUSINESS RULES ───────────────────────────────────────────

  Future<List<BusinessRuleModel>> getAllBusinessRules() async {
    final res = await client
        .from(AppConstants.tBusinessRules)
        .select()
        .order('key');
    return (res as List).map((e) => BusinessRuleModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BusinessRuleModel?> getBusinessRule(String key, {String? regionId}) async {
    var query = client
        .from(AppConstants.tBusinessRules)
        .select()
        .eq('key', key);
    final res = await query.order('region_id').limit(1).maybeSingle();
    return res != null ? BusinessRuleModel.fromJson(res) : null;
  }

  Future<void> updateBusinessRule(String ruleId, Map<String, dynamic> value) async {
    await client.from(AppConstants.tBusinessRules).update({
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ruleId);
  }

  // ─── REGIONS ─────────────────────────────────────────────────

  Future<List<RegionModel>> getRegions() async {
    final res = await client
        .from(AppConstants.tRegions)
        .select()
        .eq('is_active', true)
        .order('name');
    return (res as List).map((e) => RegionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── STORAGE ──────────────────────────────────────────────────

  Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String contentType = 'image/jpeg',
  }) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteFile(String bucket, String path) async {
    await client.storage.from(bucket).remove([path]);
  }
}
