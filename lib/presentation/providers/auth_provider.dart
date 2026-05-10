// lib/presentation/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/models.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/supabase_service.dart';



enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus    _status       = AuthStatus.initial;
  ProfileModel? _profile;
  String?       _errorMessage;
  StreamSubscription? _authSub;

  AuthStatus    get status       => _status;
  ProfileModel? get profile      => _profile;
  String?       get errorMessage => _errorMessage;
  bool          get isLoading    => _status == AuthStatus.loading;
  bool          get isAuth       => _status == AuthStatus.authenticated && _profile != null;
  UserRole      get role         => _profile?.role ?? UserRole.public;

  // ─── INIT ────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('[AuthProvider] Initializing...');
    
    // 1. Écouter les changements futurs
    _authSub = FirebaseService.instance.authStateChanges.listen((user) {
      debugPrint('[AuthProvider] Auth state changed (Stream): ${user?.email ?? "null"}');
      _onAuthStateChanged(user);
    });

    // 2. Vérification immédiate (Fix pour les flux qui restent muets au départ)
    final currentUser = FirebaseService.instance.currentUser;
    if (currentUser != null) {
      debugPrint('[AuthProvider] Immediate user found: ${currentUser.email}');
      _onAuthStateChanged(currentUser);
    } else {
      // Si pas de user immédiat, on laisse le temps au stream ou on force un état initial
      Future.delayed(const Duration(seconds: 2), () {
        if (_status == AuthStatus.initial) {
          debugPrint('[AuthProvider] No user after 2s, setting unauthenticated');
          _status = AuthStatus.unauthenticated;
          notifyListeners();
        }
      });
    }
  }

  Future<void> _onAuthStateChanged(fb.User? user) async {
    if (user == null) {
      debugPrint('[AuthProvider] No user found, setting unauthenticated');
      _status  = AuthStatus.unauthenticated;
      _profile = null;
      notifyListeners();
      return;
    }

    final needsInitialNotify = _status != AuthStatus.loading;
    _status = AuthStatus.loading;
    if (needsInitialNotify) notifyListeners();

    try {
      debugPrint('[AuthProvider] Fetching profile for UID: ${user.uid}');
      _profile = await SupabaseService.instance.getProfileByFirebaseUid(user.uid);
      debugPrint('[AuthProvider] Profile found: ${_profile != null}');

      if (_profile == null) {
        _status = AuthStatus.unauthenticated;
      } else {
        debugPrint('[AuthProvider] Profile role: ${_profile!.role}');
        await _postLoginActions(_profile!);
        _status = AuthStatus.authenticated;
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error during auth state change: $e');
      _status       = AuthStatus.error;
      _errorMessage = _mapError(e);
    }

    debugPrint('[AuthProvider] Final status: $_status');
    notifyListeners();
  }

  Future<void> _postLoginActions(ProfileModel profile) async {
    try {
      debugPrint('[AuthProvider] Performing post-login actions...');
      await SupabaseService.instance.updateLastSeen(profile.id);

      final token = await FirebaseService.instance.getFcmToken();
      if (token != null) {
        debugPrint('[AuthProvider] FCM Token obtained');
        final platform = defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'windows';
        await SupabaseService.instance.upsertFcmToken(
          profileId: profile.id,
          token: token,
          platform: platform,
        );
      } else {
        debugPrint('[AuthProvider] No FCM Token obtained (timeout or error)');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', profile.role.name);
      debugPrint('[AuthProvider] Post-login actions completed');
    } catch (e) {
      debugPrint('Error in postLoginActions: $e');
    }
  }

  // ─── SIGNUP EMAIL ─────────────────────────────────────────────

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String? phone,
    required UserRole role,
    String? regionId,
  }) async {
    _setLoading();
    try {
      final credential = await FirebaseService.instance.signUpWithEmail(
        email: email,
        password: password,
      );

      try {
        await FirebaseService.instance.updateDisplayName(fullName);
      } catch (e) {
        debugPrint('Failed to update display name: $e');
      }

      _profile = await SupabaseService.instance.createProfile(
        firebaseUid: credential.user!.uid,
        email: email,
        role: role,
        fullName: fullName,
        phone: phone,
        regionId: regionId,
      );

      if (role == UserRole.supervisor) {
        await SupabaseService.instance.createSupervisor(
          _profile!.id,
          regionId: regionId,
        );
      }

      try {
        await FirebaseService.instance.sendEmailVerification();
      } catch (e) {
        debugPrint('Failed to send verification email: $e');
      }

      await _postLoginActions(_profile!);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } catch (e) {
      _setError(_mapError(e));
      return false;
    }
  }

  // ─── LOGIN EMAIL ──────────────────────────────────────────────

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      await FirebaseService.instance.signInWithEmail(
        email: email,
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } catch (e) {
      _setError(_mapError(e));
      return false;
    }
  }



  Future<fb.User?> signInWithGoogle({
    UserRole? roleIfNew,
    String? regionId,
    String? phone,
  }) async {
    _setLoading();
    try {
      final fb.UserCredential? userCredential =
          await FirebaseService.instance.signInWithGoogle();

      if (userCredential == null) {
        _status = _profile != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
        notifyListeners();
        return null;
      }

      final fb.User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        // 🔥 Insertion dans Supabase après 1re connexion
        await _createUserInSupabase(
          firebaseUser,
          role: roleIfNew,
          regionId: regionId,
          phone: phone,
        );

        // Si le profil a été chargé/créé avec succès
        if (_profile != null) {
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      }
      notifyListeners();
      return firebaseUser;
    } catch (e, s) {
      debugPrint("Erreur lors de la connexion avec Google : ${e.toString()}");
      debugPrint("Stacktrace : $s");
      _setError(_mapError(e));
      return null;
    }
  }
  // ─── RESET PASSWORD ───────────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    _setLoading();
    try {
      await FirebaseService.instance.sendPasswordResetEmail(email);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } catch (e) {
      _setError(_mapError(e));
      return false;
    }
  }

  // ─── CHANGER DE RÔLE ─────────────────────────────────────────

  Future<bool> changeRole(UserRole newRole) async {
    if (_profile == null) return false;
    _setLoading();
    try {
      _profile = await SupabaseService.instance.updateProfile(
        _profile!.id,
        {'role': newRole.name},
      );

      if (newRole == UserRole.supervisor) {
        final existing = await SupabaseService.instance
            .getSupervisorByProfileId(_profile!.id);
        if (existing == null) {
          await SupabaseService.instance.createSupervisor(_profile!.id);
        }
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_mapError(e));
      return false;
    }
  }

  // ─── UPDATE PROFIL ────────────────────────────────────────────

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_profile == null) return false;
    try {
      _profile = await SupabaseService.instance.updateProfile(
        _profile!.id,
        data,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_mapError(e));
      return false;
    }
  }

  // ─── LOGOUT ───────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await FirebaseService.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _profile = null;
      _status  = AuthStatus.unauthenticated;
    } catch (e) {
      _setError('Erreur lors de la déconnexion');
    }
    notifyListeners();
  }

  // ─── HELPERS ──────────────────────────────────────────────────

  Future<void> _createUserInSupabase(
    fb.User firebaseUser, {
    UserRole? role,
    String? regionId,
    String? phone,
  }) async {
    try {
      // Vérifie si le user existe déjà
      final existing = await SupabaseService.instance
          .getProfileByFirebaseUid(firebaseUser.uid);

      if (existing != null) {
        _profile = existing;
        return;
      }

      // Insertion
      _profile = await SupabaseService.instance.createProfile(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        role: role ?? UserRole.public,
        fullName: firebaseUser.displayName,
        phone: phone ?? firebaseUser.phoneNumber,
        regionId: regionId,
        avatarUrl: firebaseUser.photoURL,
      );

      await _postLoginActions(_profile!);
    } catch (e) {
      debugPrint('Erreur insertion Supabase : $e');
    }
  }

  void _setLoading() {
    _status       = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status       = AuthStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':         return 'Aucun compte trouvé avec cet email';
      case 'wrong-password':         return 'Mot de passe incorrect';
      case 'email-already-in-use':   return 'Cet email est déjà utilisé';
      case 'invalid-email':          return 'Adresse email invalide';
      case 'weak-password':          return 'Le mot de passe doit contenir au moins 6 caractères';
      case 'too-many-requests':      return 'Trop de tentatives. Réessayez plus tard';
      case 'network-request-failed': return 'Erreur réseau. Vérifiez votre connexion';
      case 'user-disabled':          return 'Ce compte a été désactivé';
      case 'operation-not-allowed':  return 'Opération non autorisée';
      default:                       return e.message ?? "Une erreur d'authentification s'est produite";
    }
  }

  String _mapError(dynamic e) {
    if (e is FirebaseAuthException) return _mapFirebaseError(e);
    final str = e.toString().toLowerCase();
    if (str.contains('network') || str.contains('socket')) {
      return 'Problème de connexion internet';
    }
    if (str.contains('postgrestexception')) {
      return 'Erreur de base de données. Veuillez réessayer';
    }
    return 'Une erreur inattendue est survenue';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
