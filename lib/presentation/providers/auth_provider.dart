// lib/presentation/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/models.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/supabase_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status    = AuthStatus.initial;
  ProfileModel? _profile;
  String? _errorMessage;
  StreamSubscription? _authSub;

  AuthStatus    get status       => _status;
  ProfileModel? get profile      => _profile;
  String?       get errorMessage => _errorMessage;
  bool          get isLoading    => _status == AuthStatus.loading;
  bool          get isAuth       => _status == AuthStatus.authenticated && _profile != null;
  UserRole      get role         => _profile?.role ?? UserRole.public;

  // ─── INIT ────────────────────────────────────────────────────

  Future<void> init() async {
    _authSub = FirebaseService.instance.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _status  = AuthStatus.unauthenticated;
      _profile = null;
      notifyListeners();
      return;
    }

    _status = AuthStatus.loading;
    notifyListeners();

    try {
      _profile = await SupabaseService.instance.getProfileByFirebaseUid(user.uid);

      if (_profile == null) {
        // Profil inexistant → peut arriver si le crash survient entre Firebase et Supabase
        // On laisse l'utilisateur sur l'écran de login ou register qui détectera l'absence de profil
        _status = AuthStatus.unauthenticated;
      } else {
        await _postLoginActions(_profile!);
        _status = AuthStatus.authenticated;
      }
    } catch (e) {
      _setError(_mapError(e));
    }

    notifyListeners();
  }

  Future<void> _postLoginActions(ProfileModel profile) async {
    try {
      await SupabaseService.instance.updateLastSeen(profile.id);

      // Enregistrer FCM Token
      final token = await FirebaseService.instance.getFcmToken();
      if (token != null) {
        final platform = defaultTargetPlatform == TargetPlatform.android ? 'android' : 'windows';
        await SupabaseService.instance.upsertFcmToken(
          profileId: profile.id,
          token: token,
          platform: platform,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', profile.role.name);
    } catch (e) {
      debugPrint('Error in postLoginActions: $e');
      // On ne bloque pas l'auth pour ça
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

      // Créer fiche superviseur si rôle superviseur
      if (role == UserRole.supervisor) {
        await SupabaseService.instance.createSupervisor(_profile!.id, regionId: regionId);
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
      await FirebaseService.instance.signInWithEmail(email: email, password: password);
      // _onAuthStateChanged gère la suite (récupération profil Supabase)
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } catch (e) {
      _setError(_mapError(e));
      return false;
    }
  }

  // ─── GOOGLE SIGN IN ───────────────────────────────────────────

  Future<({bool success, bool isNewUser})> signInWithGoogle({
    UserRole? roleIfNew,
    String? regionId,
    String? phone,
  }) async {
    _setLoading();
    try {
      final credential = await FirebaseService.instance.signInWithGoogle();
      if (credential == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return (success: false, isNewUser: false);
      }

      final user = credential.user!;
      _profile = await SupabaseService.instance.getProfileByFirebaseUid(user.uid);

      final isNew = _profile == null;
      if (isNew) {
        if (roleIfNew == null) {
          // Besoin de choisir le rôle sur l'écran Register
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return (success: true, isNewUser: true);
        }

        _profile = await SupabaseService.instance.createProfile(
          firebaseUid: user.uid,
          email: user.email!,
          role: roleIfNew,
          fullName: user.displayName,
          phone: phone,
          regionId: regionId,
        );

        if (roleIfNew == UserRole.supervisor) {
          await SupabaseService.instance.createSupervisor(_profile!.id, regionId: regionId);
        }
      }

      await _postLoginActions(_profile!);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return (success: true, isNewUser: isNew);
    } catch (e) {
      _setError(_mapError(e));
      return (success: false, isNewUser: false);
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

  // ─── CHANGER DE RÔLE (après inscription) ─────────────────────

  Future<bool> changeRole(UserRole newRole) async {
    if (_profile == null) return false;
    _setLoading();
    try {
      _profile = await SupabaseService.instance.updateProfile(
        _profile!.id,
        {'role': newRole.name},
      );

      // Créer fiche superviseur si passage au rôle superviseur
      if (newRole == UserRole.supervisor) {
        final existing = await SupabaseService.instance.getSupervisorByProfileId(_profile!.id);
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
      _profile = await SupabaseService.instance.updateProfile(_profile!.id, data);
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

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = AuthStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':        return 'Aucun compte trouvé avec cet email';
      case 'wrong-password':        return 'Mot de passe incorrect';
      case 'email-already-in-use':  return 'Cet email est déjà utilisé';
      case 'invalid-email':         return 'Adresse email invalide';
      case 'weak-password':         return 'Le mot de passe doit contenir au moins 6 caractères';
      case 'too-many-requests':     return 'Trop de tentatives. Réessayez plus tard';
      case 'network-request-failed':return 'Erreur réseau. Vérifiez votre connexion';
      case 'user-disabled':         return 'Ce compte a été désactivé';
      case 'operation-not-allowed': return 'Opération non autorisée';
      default:                      return e.message ?? 'Une erreur d\'authentification s\'est produite';
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
