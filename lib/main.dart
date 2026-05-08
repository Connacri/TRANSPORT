// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/services/firebase_service.dart';
import 'data/services/tracking_service.dart';
import 'data/models/models.dart';

import 'firebase_options.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/transport_provider.dart';
import 'presentation/providers/providers.dart';

// ─── Écrans ──────────────────────────────────────────────────────
import 'presentation/screens/admin/admin_screens.dart';
import 'presentation/screens/auth/auth_screens.dart';
import 'presentation/screens/marketplace/listing_screens.dart';
import 'presentation/screens/public/public_home_screen.dart';
import 'presentation/screens/public/request_and_transporter_request.dart';
import 'presentation/screens/public/transporter_detail_screen.dart';
import 'presentation/screens/public/history_screen.dart';
import 'presentation/screens/shared/notifications_and_history.dart' hide HistoryScreen;
import 'presentation/screens/transporter/premium_and_supervisor_screens.dart';
import 'presentation/screens/transporter/transporter_home_screen.dart';
import 'presentation/screens/transporter/transporter_setup_screen.dart';
import 'presentation/screens/supervisor/supervisor_home_screen.dart';
import 'presentation/screens/admin/admin_dashboard_screen.dart';
import 'presentation/screens/marketplace/marketplace_screen.dart';
import 'presentation/screens/shared/profile_screen.dart';
import 'presentation/screens/shared/onboarding_screen.dart';
import 'data/services/supabase_service.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //Orientation portrait + landscape (desktop aussi)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Firebase
  await Firebase.initializeApp();

  // Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(logLevel: RealtimeLogLevel.info),
  );

  // Firebase FCM + Local Notifs
  await FirebaseService.instance.init();

  // Background tracking
  await TrackingService.instance.initialize();

  runApp(const TransportHubApp());
}

// ─────────────────────────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────────────────────────
class TransportHubApp extends StatefulWidget {
  const TransportHubApp({super.key});
  @override State<TransportHubApp> createState() => _TransportHubAppState();
}

class _TransportHubAppState extends State<TransportHubApp> {
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _authProvider.init();
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => TransportProvider()),
        ChangeNotifierProvider(create: (_) => TransporterProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => MarketplaceProvider()),
        ChangeNotifierProvider(create: (_) => SupervisorProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, themeProv, _) {
          final router = _buildRouter(auth);
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }

  GoRouter _buildRouter(AuthProvider auth) {
    return GoRouter(
      refreshListenable: auth,
      initialLocation: '/onboarding',
      redirect: (context, state) async {
        final isAuth    = auth.isAuth;
        final isLoading = auth.status == AuthStatus.initial || auth.status == AuthStatus.loading;
        final path      = state.matchedLocation;

        // En chargement → rien
        if (isLoading) return null;

        // Pages publiques (auth)
        final authPaths = ['/login', '/register', '/forgot-password', '/onboarding'];
        final isAuthPath = authPaths.any((p) => path.startsWith(p));

        if (!isAuth && !isAuthPath) return '/login';
        if (isAuth && isAuthPath) return _homeByRole(auth.role);

        return null;
      },
      routes: [
        // ─── AUTH ────────────────────────────────────────────────
        GoRoute(path: '/onboarding',      builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register',        builder: (_, s) => RegisterScreen(isGoogleFlow: s.uri.queryParameters['google'] == 'true')),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

        // ─── PUBLIC (CLIENT) ─────────────────────────────────────
        GoRoute(
          path: '/home/public',
          builder: (_, __) => const PublicHomeScreen(),
          routes: [
            GoRoute(path: 'transporter/:id',  builder: (_, s) => TransporterDetailScreen(transporterId: s.pathParameters['id']!)),
            GoRoute(path: 'request/:id',      builder: (_, s) => RequestScreen(transporterId: s.pathParameters['id']!)),
            GoRoute(path: 'tracking/:id',     builder: (_, s) => TrackingScreen(requestId: s.pathParameters['id']!)),
            GoRoute(path: 'history',          builder: (_, __) => const HistoryScreen()),
          ],
        ),

        // ─── TRANSPORTEUR ────────────────────────────────────────
        GoRoute(
          path: '/home/transporter',
          builder: (_, __) => const TransporterHomeScreen(),
          routes: [
            GoRoute(path: 'setup',      builder: (_, __) => const TransporterSetupScreen()),
            GoRoute(path: 'request/:id',builder: (_, s) => TransporterRequestScreen(requestId: s.pathParameters['id']!)),
            GoRoute(path: 'premium',    builder: (_, __) => const PremiumStoreScreen()),
            GoRoute(path: 'history',    builder: (_, __) => const HistoryScreen()),
          ],
        ),

        // ─── SUPERVISEUR ─────────────────────────────────────────
        GoRoute(
          path: '/home/supervisor',
          builder: (_, __) => const SupervisorHomeScreen(),
          routes: [
            GoRoute(path: 'add-transporter', builder: (_, __) => const SupervisorAddTransporterScreen()),
          ],
        ),

        // ─── ADMIN ───────────────────────────────────────────────
        GoRoute(
          path: '/home/admin',
          builder: (_, __) => const AdminDashboardScreen(),
          routes: [
            GoRoute(path: 'validate',      builder: (_, __) => const AdminTransporterValidationScreen()),
            GoRoute(path: 'rules',         builder: (_, __) => const AdminBusinessRulesScreen()),
            GoRoute(path: 'supervisors',   builder: (_, __) => const AdminSupervisorsScreen()),
          ],
        ),

        // ─── MARKETPLACE (tous rôles) ─────────────────────────────
        GoRoute(
          path: '/marketplace',
          builder: (_, __) => const MarketplaceScreen(),
          routes: [
            GoRoute(path: 'listing/:id', builder: (_, s) => ListingDetailScreen(listingId: s.pathParameters['id']!)),
            GoRoute(path: 'create',      builder: (_, __) => const CreateListingScreen()),
          ],
        ),

        // ─── PARTAGÉS ────────────────────────────────────────────
        GoRoute(path: '/profile',       builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Center(child: Text('Page introuvable: ${state.error}')),
      ),
    );
  }

  String _homeByRole(UserRole role) {
    switch (role) {
      case UserRole.admin:       return '/home/admin';
      case UserRole.supervisor:  return '/home/supervisor';
      case UserRole.transporter: return '/home/transporter';
      case UserRole.public:      return '/home/public';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// THEME PROVIDER
// ─────────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggle() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────
// MARKETPLACE PROVIDER (stub — à compléter)
// ─────────────────────────────────────────────────────────────────
class MarketplaceProvider extends ChangeNotifier {
  List<MarketplaceListingModel> _listings = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;

  List<MarketplaceListingModel> get listings   => _listings;
  bool                          get isLoading  => _isLoading;
  String?                       get error      => _error;
  bool                          get hasMore    => _hasMore;

  Future<void> loadListings({String? categoryId, String? regionId, bool refresh = false}) async {
    if (refresh) { _listings = []; _currentPage = 0; _hasMore = true; }
    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newItems = await SupabaseService.instance.getListings(
        categoryId: categoryId,
        regionId: regionId,
        page: _currentPage,
      );
      _listings.addAll(newItems);
      _currentPage++;
      _hasMore = newItems.length >= AppConstants.pageSize;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createListing({
    required String sellerId,
    required String title,
    required String? description,
    required String? categoryId,
    required ListingType type,
    required double? price,
    required bool isPriceNegotiable,
    required List<String> imagesUrls,
    required String? regionId,
    required String? city,
  }) async {
    try {
      final listing = await SupabaseService.instance.createListing({
        'seller_id': sellerId,
        'title': title,
        'description': description,
        'category_id': categoryId,
        'type': type.name,
        'price': price,
        'is_price_negotiable': isPriceNegotiable,
        'images_urls': imagesUrls,
        'region_id': regionId,
        'city': city,
      });
      _listings.insert(0, listing);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// SUPERVISOR PROVIDER
// ─────────────────────────────────────────────────────────────────
class SupervisorProvider extends ChangeNotifier {
  SupervisorModel? _supervisor;
  bool _isLoading = false;
  String? _error;

  SupervisorModel? get supervisor => _supervisor;
  bool             get isLoading  => _isLoading;
  String?          get error      => _error;

  Future<void> loadSupervisor(String profileId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _supervisor = await SupabaseService.instance.getSupervisorByProfileId(profileId);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addTransporterByReferral({
    required String transporterCode,
    required String supervisorId,
  }) async {
    try {
      // Chercher transporteur par code (email ou ID)
      final transporterData = await SupabaseService.instance.client
          .from(AppConstants.tTransporters)
          .select('id, profiles!inner(email)')
          .eq('profiles.email', transporterCode)
          .maybeSingle();

      if (transporterData == null) {
        _error = 'Transporteur introuvable avec cet email';
        notifyListeners();
        return false;
      }

      await SupabaseService.instance.addTransporterReferral(
        supervisorId: supervisorId,
        transporterId: transporterData['id'] as String,
      );

      await loadSupervisor(_supervisor!.profileId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}


