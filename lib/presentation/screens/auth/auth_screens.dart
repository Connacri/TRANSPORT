// lib/presentation/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

import '../../../data/services/supabase_service.dart';
import '../../../data/models/models.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/widgets.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl= TextEditingController();
  bool _obscure      = true;
  late AnimationController _anim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithEmail(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Erreur de connexion'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _googleLogin() async {
    final auth = context.read<AuthProvider>();
    final result = await auth.signInWithGoogle();
    if (!mounted) return;
    if (result.isNewUser) {
      context.push('/register?google=true');
    } else if (!result.success && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Logo + titre
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 20, offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 20),
                        Text('TransportHub', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Connectez-vous à votre compte', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryLight)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Email
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email requis';
                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Email invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  AppTextField(
                    controller: _passwordCtrl,
                    label: 'Mot de passe',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mot de passe requis';
                      if (v.length < 6) return 'Minimum 6 caractères';
                      return null;
                    },
                  ),

                  // Mot de passe oublié
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Bouton connexion
                  AppButton(
                    label: 'Se connecter',
                    isLoading: auth.isLoading,
                    onPressed: _login,
                  ),

                  const SizedBox(height: 20),

                  // Séparateur
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('ou', style: theme.textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ]),

                  const SizedBox(height: 20),

                  // Google Sign-In
                  _GoogleSignInButton(onPressed: _googleLogin, isLoading: auth.isLoading),

                  const SizedBox(height: 32),

                  // Pas de compte
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Pas encore de compte ?'),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: const Text('S\'inscrire', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// REGISTER SCREEN
// ─────────────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  final bool isGoogleFlow;
  const RegisterScreen({super.key, this.isGoogleFlow = false});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.public;
  String?  _selectedRegionId;
  List<RegionModel> _regions = [];
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final r = await SupabaseService.instance.getRegions();
    setState(() => _regions = r);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    bool ok;
    if (widget.isGoogleFlow) {
      final res = await auth.signInWithGoogle(
        roleIfNew: _selectedRole,
        regionId: _selectedRegionId,
      );
      ok = res.success;
    } else {
      ok = await auth.signUpWithEmail(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        fullName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        role: _selectedRole,
        regionId: _selectedRegionId,
      );
    }

    setState(() => _isLoading = false);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Erreur'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── CHOIX DU RÔLE ─────────────────────────────────
              Text('Je suis…', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _RoleSelector(
                selected: _selectedRole,
                onChanged: (r) => setState(() => _selectedRole = r),
              ),
              const SizedBox(height: 24),

              if (!widget.isGoogleFlow) ...[
                AppTextField(controller: _nameCtrl, label: 'Nom complet', prefixIcon: Icons.person_outline,
                  validator: (v) => (v?.isEmpty ?? true) ? 'Nom requis' : null),
                const SizedBox(height: 16),
                AppTextField(controller: _emailCtrl, label: 'Email', prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v?.isEmpty ?? true) ? 'Email requis' : null),
                const SizedBox(height: 16),
              ],

              AppTextField(controller: _phoneCtrl, label: 'Téléphone', prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v?.isEmpty ?? true) ? 'Téléphone requis' : null),
              const SizedBox(height: 16),

              // Région
              if (_regions.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedRegionId,
                  decoration: const InputDecoration(
                    labelText: 'Région',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: _regions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                  onChanged: (v) => setState(() => _selectedRegionId = v),
                  validator: (v) => v == null ? 'Sélectionnez votre région' : null,
                ),
                const SizedBox(height: 16),
              ],

              if (!widget.isGoogleFlow) ...[
                AppTextField(controller: _passCtrl, label: 'Mot de passe', prefixIcon: Icons.lock_outline,
                  obscureText: _obscure,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) => (v?.length ?? 0) < 6 ? 'Minimum 6 caractères' : null),
                const SizedBox(height: 16),
                AppTextField(controller: _confirmCtrl, label: 'Confirmer le mot de passe', prefixIcon: Icons.lock_outline,
                  obscureText: _obscure,
                  validator: (v) => v != _passCtrl.text ? 'Les mots de passe ne correspondent pas' : null),
                const SizedBox(height: 24),
              ],

              // Info selon rôle
              if (_selectedRole == UserRole.transporter)
                _InfoCard(
                  icon: Icons.info_outline,
                  text: 'En tant que transporteur, vous devrez compléter votre profil véhicule après inscription.',
                  color: AppColors.info,
                ),
              if (_selectedRole == UserRole.supervisor)
                _InfoCard(
                  icon: Icons.supervisor_account_outlined,
                  text: 'En tant que superviseur, vous pouvez parrainer jusqu\'à 20 transporteurs et recevoir des commissions sur leurs transports.',
                  color: AppColors.warning,
                ),

              const SizedBox(height: 24),

              AppButton(
                label: 'Créer mon compte',
                isLoading: _isLoading,
                onPressed: _register,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// FORGOT PASSWORD SCREEN
// ─────────────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent       = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendPasswordReset(_emailCtrl.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _sent
            ? _SuccessState(email: _emailCtrl.text, onBack: () => context.pop())
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Icon(Icons.lock_reset_outlined, size: 64, color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text('Réinitialiser le mot de passe', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Entrez votre email. Nous vous enverrons un lien de réinitialisation.', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 32),
                    AppTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v?.isEmpty ?? true) ? 'Email requis' : null,
                    ),
                    const SizedBox(height: 24),
                    AppButton(label: 'Envoyer le lien', isLoading: auth.isLoading, onPressed: _send),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// WIDGETS LOCAUX
// ─────────────────────────────────────────────────────────────────
class _RoleSelector extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;
  const _RoleSelector({required this.selected, required this.onChanged});

  static const _roles = [
    (role: UserRole.public,      label: 'Client',      icon: Icons.person_outline,             desc: 'Je cherche un transport'),
    (role: UserRole.transporter, label: 'Transporteur', icon: Icons.local_shipping_outlined,    desc: 'Je propose mes services'),
    (role: UserRole.supervisor,  label: 'Superviseur',  icon: Icons.supervisor_account_outlined, desc: 'Je gère des transporteurs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _roles.map((r) {
        final isSelected = selected == r.role;
        return GestureDetector(
          onTap: () => onChanged(r.role),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(r.icon, color: isSelected ? AppColors.primary : Colors.grey, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.label, style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : null,
                      )),
                      Text(r.desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  const _GoogleSignInButton({required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://www.google.com/favicon.ico',
            width: 24, height: 24,
            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 28),
          ),
          const SizedBox(width: 12),
          const Text('Continuer avec Google'),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoCard({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
        ],
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  final String email;
  final VoidCallback onBack;
  const _SuccessState({required this.email, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 80, color: AppColors.success),
        const SizedBox(height: 24),
        Text('Email envoyé !', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text('Un lien de réinitialisation a été envoyé à\n$email', textAlign: TextAlign.center),
        const SizedBox(height: 32),
        AppButton(label: 'Retour à la connexion', onPressed: onBack),
      ],
    );
  }
}

