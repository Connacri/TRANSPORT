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

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(logLevel: RealtimeLogLevel.info),
  );

  await FirebaseService.instance.init();
  await TrackingService.instance.initialize();

  runApp(const TransportHubApp());
}

// ─────────────────────────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────────────────────────
class TransportHubApp extends StatefulWidget {
  const TransportHubApp({super.key});
  @override
  State<TransportHubApp> createState() => _TransportHubAppState();
}

class _TransportHubAppState extends State<TransportHubApp> {
  late final AuthProvider _authProvider;

  // ✅ FIX #1 : Le router est créé UNE SEULE FOIS comme champ d'état.
  // Il ne sera jamais recréé, éliminant le clignotement.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();

    // ✅ FIX #2 : Le router est initialisé ici avec une référence stable
    // à _authProvider. refreshListenable permet au router de recalculer
    // les redirections sans recréer le router lui-même.
    _router = _buildRouter(_authProvider);

    // ✅ FIX #3 : init() est appelé après la construction du router
    // pour éviter la race condition. L'état initial est 'initial',
    // le redirect retourne null pendant ce temps.
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
      // ✅ FIX #4 : Seul ThemeProvider est écouté ici pour le thème.
      // AuthProvider ne déclenche PLUS de rebuild du widget racine,
      // uniquement une réévaluation du redirect via refreshListenable.
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.themeMode,
            routerConfig: _router, // ✅ Référence stable, jamais recréée
          );
        },
      ),
    );
  }

  GoRouter _buildRouter(AuthProvider auth) {
    return GoRouter(
      refreshListenable: auth,
      initialLocation: '/onboarding',
      redirect: (context, state) {
        final status = auth.status;
        final path   = state.matchedLocation;

        // ✅ FIX #5 : Pendant le chargement initial ET le chargement
        // post-login, on ne redirige pas. L'écran courant reste affiché.
        if (status == AuthStatus.initial || status == AuthStatus.loading) {
          return null;
        }

        final isAuth = status == AuthStatus.authenticated && auth.profile != null;

        final authPaths = ['/login', '/register', '/forgot-password', '/onboarding'];
        final isAuthPath = authPaths.any((p) => path.startsWith(p));

        // Non authentifié sur une page protégée → login
        if (!isAuth && !isAuthPath) return '/login';

        // Authentifié sur une page auth → home selon rôle
        if (isAuth && isAuthPath) return _homeByRole(auth.role);

        return null;
      },
      routes: [
        GoRoute(path: '/onboarding',      builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register',        builder: (_, s) => RegisterScreen(isGoogleFlow: s.uri.queryParameters['google'] == 'true')),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

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

        GoRoute(
          path: '/home/transporter',
          builder: (_, __) => const TransporterHomeScreen(),
          routes: [
            GoRoute(path: 'setup',       builder: (_, __) => const TransporterSetupScreen()),
            GoRoute(path: 'request/:id', builder: (_, s) => TransporterRequestScreen(requestId: s.pathParameters['id']!)),
            GoRoute(path: 'premium',     builder: (_, __) => const PremiumStoreScreen()),
            GoRoute(path: 'history',     builder: (_, __) => const HistoryScreen()),
          ],
        ),

        GoRoute(
          path: '/home/supervisor',
          builder: (_, __) => const SupervisorHomeScreen(),
          routes: [
            GoRoute(path: 'add-transporter', builder: (_, __) => const SupervisorAddTransporterScreen()),
          ],
        ),

        GoRoute(
          path: '/home/admin',
          builder: (_, __) => const AdminDashboardScreen(),
          routes: [
            GoRoute(path: 'validate',    builder: (_, __) => const AdminTransporterValidationScreen()),
            GoRoute(path: 'rules',       builder: (_, __) => const AdminBusinessRulesScreen()),
            GoRoute(path: 'supervisors', builder: (_, __) => const AdminSupervisorsScreen()),
          ],
        ),

        GoRoute(
          path: '/marketplace',
          builder: (_, __) => const MarketplaceScreen(),
          routes: [
            GoRoute(path: 'listing/:id', builder: (_, s) => ListingDetailScreen(listingId: s.pathParameters['id']!)),
            GoRoute(path: 'create',      builder: (_, __) => const CreateListingScreen()),
          ],
        ),

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