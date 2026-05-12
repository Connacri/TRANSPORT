// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // ─── App Info ────────────────────────────────────────────────
  static const String appName       = 'Cargoza';
  static const String appVersion    = '1.0.0';
  static const String appTagline    = 'Transport à portée de main';

  // ─── Supabase ─────────────────────────────────────────────────
  static const String supabaseUrl   = 'https://xlgxpiniwjbooezzrtxi.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhsZ3hwaW5pd2pib29lenpydHhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyMDk4MjMsImV4cCI6MjA5Mzc4NTgyM30.hHSpVXcx1QG0NSw8ELeR9PAoQ3l79i2Op8_avP5USwU';

  // ─── Supabase Tables ──────────────────────────────────────────
  static const String tProfiles             = 'profiles';
  static const String tTransporters         = 'transporters';
  static const String tRequests             = 'transport_requests';
  static const String tTrackings            = 'trackings';
  static const String tRatings              = 'ratings';
  static const String tSupervisors          = 'supervisors';
  static const String tSupervisorReferrals  = 'supervisor_referrals';
  static const String tCommissions          = 'commissions';
  static const String tPremiumOptions       = 'premium_options';
  static const String tPremiumPurchases     = 'premium_purchases';
  static const String tBoutiques            = 'boutiques';
  static const String tBusinessRules        = 'business_rules';
  static const String tRegions              = 'regions';
  static const String tNotifications        = 'notifications_log';
  static const String tFcmTokens            = 'fcm_tokens';
  static const String tMarketplaceListings  = 'marketplace_listings';
  static const String tMarketplaceCategories= 'marketplace_categories';

  // ─── Supabase Storage Buckets ─────────────────────────────────
  static const String bucketAvatars     = 'avatars';
  static const String bucketVehicles    = 'vehicles';
  static const String bucketDocuments   = 'documents';
  static const String bucketListings    = 'listings';

  // ─── Maps ─────────────────────────────────────────────────────
  static const String osmTileUrl  = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const double defaultLat  = 36.7372;
  static const double defaultLng  = 3.0870;
  static const double defaultZoom = 13.0;
  static const double searchRadius = 50.0; // km

  // ─── Tracking ─────────────────────────────────────────────────
  static const int trackingDefaultIntervalSec = 30;
  static const int trackingPremiumIntervalSec = 5;
  static const double trackingMinDistanceM    = 10.0;

  // ─── Supervisor ───────────────────────────────────────────────
  static const int supervisorMaxSilver   = 20;
  static const int supervisorMaxGold     = 50;
  static const int supervisorMaxPlatinum = 150;
  static const int supervisorMinMonthlyAdds = 5;

  // ─── Pagination ───────────────────────────────────────────────
  static const int pageSize = 20;

  // ─── Cache ────────────────────────────────────────────────────
  static const String keyFcmToken       = 'fcm_token';
  static const String keyUserRole       = 'user_role';
  static const String keyFirebaseUid    = 'firebase_uid';
  static const String keyOnboardingDone = 'onboarding_done';

  // ─── Validation ───────────────────────────────────────────────
  static const int maxImageSizeBytes    = 5 * 1024 * 1024; // 5MB
  static const int maxImagesPerListing  = 8;
  static const double minRating         = 1.0;
  static const double maxRating         = 5.0;
}
