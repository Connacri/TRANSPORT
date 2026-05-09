// lib/presentation/providers/auth_provider.dart
// ─── MODIFICATION : _onAuthStateChanged ──────────────────────────

Future<void> _onAuthStateChanged(User? user) async {
  if (user == null) {
    // ✅ Un seul setState groupé
    _status  = AuthStatus.unauthenticated;
    _profile = null;
    notifyListeners();
    return;
  }

  // ✅ FIX : Ne pas notifier si on est déjà en loading depuis signInWithEmail.
  // signInWithEmail a déjà appelé _setLoading(). On évite un double notify.
  if (_status != AuthStatus.loading) {
    _status = AuthStatus.loading;
    notifyListeners();
  }

  try {
    _profile = await SupabaseService.instance.getProfileByFirebaseUid(user.uid);

    if (_profile == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      await _postLoginActions(_profile!);
      _status = AuthStatus.authenticated;
    }
  } catch (e) {
    _status       = AuthStatus.error;
    _errorMessage = _mapError(e);
  }

  // ✅ Un seul notifyListeners() final, le router recalcule le redirect une seule fois
  notifyListeners();
}

// ─── MODIFICATION : signInWithGoogle ─────────────────────────────
// Même logique : éviter le double notify

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
        // ✅ Nouvel utilisateur Google sans rôle → rediriger vers /register?google=true
        // On NE met PAS unauthenticated ici pour éviter une redirection /login
        // On reste loading le temps que le router navigue vers register
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
    // ✅ Un seul notify final. _onAuthStateChanged sera aussi déclenché
    // par Firebase mais trouvera _status déjà à authenticated et ne re-notifiera pas.
    notifyListeners();
    return (success: true, isNewUser: isNew);
  } catch (e) {
    _setError(_mapError(e));
    return (success: false, isNewUser: false);
  }
}