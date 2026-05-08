// lib/presentation/screens/shared/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';
import '../../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _editing    = false;
  bool _savingAvatar = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    if (profile != null) {
      _nameCtrl.text  = profile.fullName ?? '';
      _phoneCtrl.text = profile.phone ?? '';
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    setState(() => _savingAvatar = true);
    try {
      final auth  = context.read<AuthProvider>();
      final bytes = await file.readAsBytes();
      final url   = await SupabaseService.instance.uploadFile(
        bucket: AppConstants.bucketAvatars,
        path: '${auth.profile!.id}/avatar.jpg',
        bytes: bytes,
      );
      await auth.updateProfile({'avatar_url': url});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _savingAvatar = false);
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final ok   = await auth.updateProfile({
      'full_name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Profil mis à jour' : auth.errorMessage ?? 'Erreur'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _changeRole(UserRole newRole) async {
    final auth = context.read<AuthProvider>();
    if (newRole == auth.role) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Changer de rôle ?'),
        content: Text('Vous allez passer au rôle "${_roleLabel(newRole)}". Confirmez-vous ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final ok = await auth.changeRole(newRole);
    if (!mounted) return;
    if (ok) {
      context.go(_homeByRole(newRole));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Erreur'), backgroundColor: AppColors.error));
    }
  }

  String _homeByRole(UserRole r) {
    switch (r) {
      case UserRole.admin:       return '/home/admin';
      case UserRole.supervisor:  return '/home/supervisor';
      case UserRole.transporter: return '/home/transporter';
      case UserRole.public:      return '/home/public';
    }
  }

  String _roleLabel(UserRole r) {
    switch (r) {
      case UserRole.admin:       return 'Administrateur';
      case UserRole.supervisor:  return 'Superviseur';
      case UserRole.transporter: return 'Transporteur';
      case UserRole.public:      return 'Client';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final theme   = context.watch<ThemeProvider>();
    final profile = auth.profile;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          if (!_editing)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => setState(() => _editing = true))
          else
            TextButton(onPressed: _save, child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── AVATAR ───────────────────────────────────────────────
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    backgroundImage: profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
                    child: _savingAvatar
                        ? const CircularProgressIndicator(color: AppColors.primary)
                        : profile?.avatarUrl == null
                            ? Text(
                                (profile?.displayName.isNotEmpty == true)
                                    ? profile!.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.primary),
                              )
                            : null,
                  ),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nom + rôle
          Center(child: Text(profile?.displayName ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          const SizedBox(height: 4),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: (profile?.roleColor ?? AppColors.primary).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(profile?.roleLabel ?? '',
                style: TextStyle(color: profile?.roleColor ?? AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 28),

          // ── INFOS ────────────────────────────────────────────────
          _SectionCard(
            title: 'Informations personnelles',
            children: [
              if (_editing) ...[
                AppTextField(controller: _nameCtrl, label: 'Nom complet', prefixIcon: Icons.person_outline),
                const SizedBox(height: 12),
                AppTextField(controller: _phoneCtrl, label: 'Téléphone', prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              ] else ...[
                _InfoRow(icon: Icons.person_outline, label: 'Nom', value: profile?.fullName ?? 'Non renseigné'),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: profile?.email ?? ''),
                _InfoRow(icon: Icons.phone_outlined, label: 'Téléphone', value: profile?.phone ?? 'Non renseigné'),
                _InfoRow(icon: Icons.location_on_outlined, label: 'Région', value: profile?.regionId ?? 'Non renseignée'),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── CHANGER RÔLE ─────────────────────────────────────────
          _SectionCard(
            title: 'Mon rôle',
            children: [
              ...[UserRole.public, UserRole.transporter, UserRole.supervisor]
                  .where((r) => r != UserRole.admin)
                  .map((r) {
                    final isCurr = r == auth.role;
                    return GestureDetector(
                      onTap: () => _changeRole(r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurr ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurr ? AppColors.primary : Colors.grey.withOpacity(0.25),
                            width: isCurr ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(_roleIcon(r), color: isCurr ? AppColors.primary : Colors.grey, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(_roleLabel(r),
                                style: TextStyle(fontWeight: isCurr ? FontWeight.w700 : FontWeight.w400,
                                  color: isCurr ? AppColors.primary : null)),
                            ),
                            if (isCurr) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
            ],
          ),
          const SizedBox(height: 16),

          // ── APPARENCE ────────────────────────────────────────────
          _SectionCard(
            title: 'Apparence',
            children: [
              Row(
                children: [
                  const Icon(Icons.dark_mode_outlined, color: AppColors.textSecondaryLight, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Mode sombre')),
                  Switch.adaptive(
                    value: theme.themeMode == ThemeMode.dark,
                    activeColor: AppColors.primary,
                    onChanged: (_) => theme.toggle(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── DÉCONNEXION ───────────────────────────────────────────
          OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Déconnexion', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Se déconnecter ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Déconnexion'),
                    ),
                  ],
                ),
              );
              if (ok == true && mounted) {
                await context.read<AuthProvider>().signOut();
              }
            },
          ),
          const SizedBox(height: 8),

          Center(child: Text('v${AppConstants.appVersion} — ${AppConstants.appName}',
            style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _roleIcon(UserRole r) {
    switch (r) {
      case UserRole.public:      return Icons.person_outline;
      case UserRole.transporter: return Icons.local_shipping_outlined;
      case UserRole.supervisor:  return Icons.supervisor_account_outlined;
      case UserRole.admin:       return Icons.admin_panel_settings_outlined;
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondaryLight),
          const SizedBox(width: 12),
          Text('$label : ', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
