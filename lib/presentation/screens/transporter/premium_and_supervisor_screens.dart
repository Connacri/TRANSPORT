// lib/presentation/screens/transporter/premium_store_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';
import '../../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class PremiumStoreScreen extends StatefulWidget {
  const PremiumStoreScreen({super.key});
  @override State<PremiumStoreScreen> createState() => _PremiumStoreScreenState();
}

class _PremiumStoreScreenState extends State<PremiumStoreScreen> {
  List<Map<String, dynamic>> _boutiques = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await context.read<TransporterProvider>().loadPremiumOptions(regionId: auth.profile?.regionId);
      _boutiques = await SupabaseService.instance.getBoutiques();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final transProv = context.watch<TransporterProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Options Premium')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── STATUT PREMIUM ACTUEL ─────────────────────────────────
          if (transProv.transporter?.isPremium == true) ...[
            _CurrentPremiumCard(transporter: transProv.transporter!),
            const SizedBox(height: 20),
          ],

          // ── EXPLICATION ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB8860B), AppColors.premiumGold],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⭐ Boostez votre visibilité', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text('Apparaissez en premier dans la liste, augmentez la fréquence de votre tracking GPS et recevez plus de demandes.',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── OPTIONS ───────────────────────────────────────────────
          if (transProv.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ...transProv.premiumOptions.map((opt) => _PremiumOptionCard(
              option: opt,
              boutiques: _boutiques,
              transporterId: transProv.transporter?.id ?? '',
              onPurchased: () => context.read<TransporterProvider>().loadTransporter(
                context.read<AuthProvider>().profile!.id),
            )),

          const SizedBox(height: 20),

          // ── COMMENT ACHETER ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  SizedBox(width: 8),
                  Text('Comment payer ?', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.info)),
                ]),
                SizedBox(height: 8),
                Text('1. Choisissez votre option ci-dessus\n2. Sélectionnez une boutique partenaire\n3. Rendez-vous en boutique pour payer\n4. L\'admin valide et votre premium est activé.',
                  style: TextStyle(fontSize: 13, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPremiumCard extends StatelessWidget {
  final TransporterModel transporter;
  const _CurrentPremiumCard({required this.transporter});

  @override
  Widget build(BuildContext context) {
    final remaining = transporter.premiumUntil?.difference(DateTime.now()).inDays ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.premiumGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.premiumGold.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: AppColors.premiumGold, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Premium actif ✅', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.premiumGold)),
                Text('Expire dans $remaining jour(s)', style: const TextStyle(fontSize: 13)),
                Text('Intervalle GPS : ${transporter.locationIntervalSeconds}s',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumOptionCard extends StatelessWidget {
  final PremiumOptionModel option;
  final List<Map<String, dynamic>> boutiques;
  final String transporterId;
  final VoidCallback onPurchased;

  const _PremiumOptionCard({
    required this.option, required this.boutiques,
    required this.transporterId, required this.onPurchased,
  });

  IconData get _icon {
    switch (option.type) {
      case PremiumType.visibility:        return Icons.trending_up;
      case PremiumType.locationInterval:  return Icons.gps_fixed;
      case PremiumType.badgeBoost:        return Icons.workspace_premium;
    }
  }

  Color get _color {
    switch (option.type) {
      case PremiumType.visibility:        return AppColors.primary;
      case PremiumType.locationInterval:  return AppColors.info;
      case PremiumType.badgeBoost:        return AppColors.premiumGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (option.description != null)
                    Text(option.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: _color),
                    const SizedBox(width: 4),
                    Text('${option.durationDays} jours', style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600)),
                    if (option.locationIntervalSeconds != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.speed, size: 12, color: _color),
                      const SizedBox(width: 4),
                      Text('GPS ${option.locationIntervalSeconds}s', style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${option.price.toStringAsFixed(0)}\n${option.currency}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _color)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showBoutiqueSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Acheter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBoutiqueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choisir une boutique', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 4),
              const Text('Rendez-vous en boutique pour payer et activer votre option premium.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
              const SizedBox(height: 16),
              Expanded(
                child: boutiques.isEmpty
                    ? const Center(child: Text('Aucune boutique disponible dans votre région'))
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: boutiques.length,
                        itemBuilder: (_, i) {
                          final b = boutiques[i];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.storefront_outlined, color: Colors.white, size: 20),
                            ),
                            title: Text(b['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(b['address'] as String? ?? ''),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () async {
                              Navigator.pop(context);
                              await SupabaseService.instance.createPremiumPurchase(
                                transporterId: transporterId,
                                optionId: option.id,
                                boutiqueId: b['id'] as String,
                                amountPaid: option.price,
                                durationDays: option.durationDays,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Demande enregistrée ! Rendez-vous en boutique pour valider.'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                              onPurchased();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SUPERVISOR ADD TRANSPORTER SCREEN
// ════════════════════════════════════════════════════════════════
class SupervisorAddTransporterScreen extends StatefulWidget {
  const SupervisorAddTransporterScreen({super.key});
  @override State<SupervisorAddTransporterScreen> createState() => _SupervisorAddTransporterScreenState();
}

class _SupervisorAddTransporterScreenState extends State<SupervisorAddTransporterScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading    = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _add() async {
    if (_emailCtrl.text.isEmpty) return;
    setState(() => _loading = true);

    final supProv = context.read<SupervisorProvider>();

    final ok = await supProv.addTransporterByReferral(
      transporterCode: _emailCtrl.text.trim(),
      supervisorId: supProv.supervisor!.id,
    );

    setState(() => _loading = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Transporteur ajouté à votre réseau !' : supProv.error ?? 'Transporteur introuvable'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
    if (ok) _emailCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final supProv = context.watch<SupervisorProvider>();
    final s       = supProv.supervisor;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un transporteur')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // Stats capacité
          if (s != null) _CapacityCard(supervisor: s),
          const SizedBox(height: 20),

          // Formulaire
          const Text('📧 Par email', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Le transporteur doit déjà avoir un compte Cargoza.',
            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
          const SizedBox(height: 14),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email du transporteur',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AppButton(label: 'Ajouter au réseau', icon: Icons.person_add_outlined,
            isLoading: _loading, onPressed: _add),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 20),

          // Conditions rappel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.rule_outlined, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Text('Rappel des conditions', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                ]),
                const SizedBox(height: 10),
                if (s != null) ...[
                  _RuleItem('Vous pouvez gérer jusqu\'à ${s.maxTransporters} transporteurs (tier ${s.tierLabel})'),
                  _RuleItem('Vous devez ajouter min. ${s.minMonthlyAddRequired} transporteurs/mois pour garder vos commissions'),
                  _RuleItem('Votre commission : ${s.commissionFromTransportsRate}% par transport'),
                  _RuleItem('Frais plateforme : ${s.commissionToAppRate}% de votre commission'),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Mes filleuls
          if (s != null && s.referrals.isNotEmpty) ...[
            Text('Mes transporteurs (${s.referrals.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            ...s.referrals.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r.transporter?.profile?.displayName ?? 'Transporteur',
                    style: const TextStyle(fontWeight: FontWeight.w500))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (r.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(r.isActive ? 'Actif' : 'Inactif',
                      style: TextStyle(fontSize: 11, color: r.isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _CapacityCard extends StatelessWidget {
  final SupervisorModel supervisor;
  const _CapacityCard({required this.supervisor});

  @override
  Widget build(BuildContext context) {
    final used = supervisor.referrals.where((r) => r.isActive).length;
    final max  = supervisor.maxTransporters;
    final pct  = used / max;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Capacité réseau', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('$used / $max', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(pct > 0.9 ? AppColors.error : AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text('${supervisor.maxTransporters - used} place(s) disponible(s) — Tier ${supervisor.tierLabel}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  const _RuleItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN SUPERVISORS SCREEN
// ════════════════════════════════════════════════════════════════
class AdminSupervisorsScreen extends StatelessWidget {
  const AdminSupervisorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Superviseurs (${admin.supervisors.length})'),
        actions: [IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: () => admin.loadDashboardData())],
      ),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : admin.supervisors.isEmpty
              ? const Center(child: Text('Aucun superviseur'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: admin.supervisors.length,
                  itemBuilder: (_, i) => _AdminSupervisorCard(
                    supervisor: admin.supervisors[i],
                    onTierChange: (tier) => admin.updateSupervisorTier(supervisorId: admin.supervisors[i].id, tier: tier),
                    onToggleCommission: (active) => admin.toggleSupervisorCommission(
                      supervisorId: admin.supervisors[i].id, active: active,
                      reason: active ? null : 'Suspendu par l\'administrateur',
                    ),
                  ),
                ),
    );
  }
}

class _AdminSupervisorCard extends StatelessWidget {
  final SupervisorModel supervisor;
  final void Function(SupervisorTier) onTierChange;
  final void Function(bool) onToggleCommission;

  const _AdminSupervisorCard({
    required this.supervisor, required this.onTierChange, required this.onToggleCommission,
  });

  Color get _tierColor {
    switch (supervisor.tier) {
      case SupervisorTier.platinum: return AppColors.badgePlatinum;
      case SupervisorTier.gold:     return AppColors.badgeGold;
      case SupervisorTier.silver:   return AppColors.badgeSilver;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tierColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _tierColor.withValues(alpha: 0.15),
                  child: Text(supervisor.profile?.displayName.substring(0, 1).toUpperCase() ?? 'S',
                    style: TextStyle(color: _tierColor, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supervisor.profile?.displayName ?? 'Superviseur',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(supervisor.profile?.email ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: supervisor.isCommissionActive,
                  activeTrackColor: AppColors.success,
                  onChanged: onToggleCommission,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats
            Row(
              children: [
                _MiniStat(label: 'Transporteurs', value: '${supervisor.referrals.length}/${supervisor.maxTransporters}'),
                const SizedBox(width: 10),
                _MiniStat(label: 'Gains nets', value: '${supervisor.totalNetEarnings.toStringAsFixed(0)} DA'),
                const SizedBox(width: 10),
                _MiniStat(label: 'Ajoutés/mois', value: '${supervisor.transportersAddedThisMonth}/${supervisor.minMonthlyAddRequired}'),
              ],
            ),
            const SizedBox(height: 12),

            // Tier selector
            Row(
              children: [
                const Text('Tier : ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ...SupervisorTier.values.map((tier) {
                  final isCurr = tier == supervisor.tier;
                  final color  = tier == SupervisorTier.platinum ? AppColors.badgePlatinum
                      : tier == SupervisorTier.gold ? AppColors.badgeGold : AppColors.badgeSilver;
                  return GestureDetector(
                    onTap: () => onTierChange(tier),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isCurr ? color.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color, width: isCurr ? 1.5 : 1),
                      ),
                      child: Text(
                        tier == SupervisorTier.silver ? 'Argent' : tier == SupervisorTier.gold ? 'Or' : 'Platine',
                        style: TextStyle(fontSize: 12, fontWeight: isCurr ? FontWeight.w700 : FontWeight.w400, color: color),
                      ),
                    ),
                  );
                }),
              ],
            ),

            if (!supervisor.isCommissionActive && supervisor.commissionSuspendedReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.block, color: AppColors.error, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Raison : ${supervisor.commissionSuspendedReason}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
