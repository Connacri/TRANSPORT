// lib/presentation/screens/supervisor/supervisor_home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';

class SupervisorHomeScreen extends StatefulWidget {
  const SupervisorHomeScreen({super.key});
  @override State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.profile != null) {
        context.read<SupervisorProvider>().loadSupervisor(auth.profile!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final supProv = context.watch<SupervisorProvider>();
    final auth    = context.watch<AuthProvider>();
    final s       = supProv.supervisor;
    final theme   = Theme.of(context);

    if (supProv.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon espace superviseur'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications')),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.push('/profile')),
        ],
      ),
      body: s == null
          ? const Center(child: Text('Profil superviseur introuvable'))
          : RefreshIndicator(
              onRefresh: () => supProv.loadSupervisor(auth.profile!.id),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── CARTE TIER ───────────────────────────────────
                  _TierCard(supervisor: s),
                  const SizedBox(height: 16),

                  // ── ALERTE COMMISSION ────────────────────────────
                  if (!s.isCommissionActive)
                    _CommissionSuspendedAlert(reason: s.commissionSuspendedReason),

                  if (s.isCommissionActive && s.needsMoreAdds)
                    _MonthlyObjectiveAlert(supervisor: s),

                  // ── STATS REVENUS ────────────────────────────────
                  _EarningsCard(supervisor: s),
                  const SizedBox(height: 16),

                  // ── OBJECTIF MENSUEL ──────────────────────────────
                  _MonthlyProgressCard(supervisor: s),
                  const SizedBox(height: 16),

                  // ── TRANSPORTEURS ─────────────────────────────────
                  Row(
                    children: [
                      Text('Mes transporteurs (${s.referrals.length}/${s.maxTransporters})',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (s.remainingSlots > 0)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () => context.push('/home/supervisor/add-transporter'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (s.referrals.isEmpty)
                    _EmptyReferrals(onAdd: () => context.push('/home/supervisor/add-transporter'))
                  else
                    ...s.referrals.map((r) => _ReferralTile(referral: r)),

                  const SizedBox(height: 16),

                  // ── QR CODE PARRAINAGE ───────────────────────────
                  _ReferralQrCard(supervisor: s),

                  const SizedBox(height: 16),

                  // ── MARKETPLACE ───────────────────────────────────
                  GestureDetector(
                    onTap: () => context.go('/marketplace'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.store_outlined, color: AppColors.success, size: 26),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Marketplace', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
                                Text('Vendre vos services ou articles', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.success),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _SupervisorBottomNav(currentIndex: 0),
    );
  }
}

// ─── TIER CARD ────────────────────────────────────────────────────
class _TierCard extends StatelessWidget {
  final SupervisorModel supervisor;
  const _TierCard({required this.supervisor});

  Color get _tierGradientStart {
    switch (supervisor.tier) {
      case SupervisorTier.platinum: return const Color(0xFF78909C);
      case SupervisorTier.gold:     return const Color(0xFFB8860B);
      case SupervisorTier.silver:   return const Color(0xFF757575);
    }
  }

  Color get _tierGradientEnd {
    switch (supervisor.tier) {
      case SupervisorTier.platinum: return const Color(0xFFB0BEC5);
      case SupervisorTier.gold:     return const Color(0xFFFFD700);
      case SupervisorTier.silver:   return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_tierGradientStart, _tierGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Superviseur ${supervisor.tierLabel}',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${supervisor.remainingSlots} place(s) disponible(s)',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                const SizedBox(height: 8),
                Text('Code parrainage : ${supervisor.referralCode}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.workspace_premium, color: Colors.white, size: 48),
        ],
      ),
    );
  }
}

// ─── EARNINGS CARD ────────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final SupervisorModel supervisor;
  const _EarningsCard({required this.supervisor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mes revenus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _EarnItem(label: 'Brut', value: supervisor.totalGrossEarnings, color: AppColors.info)),
              Expanded(child: _EarnItem(label: 'Frais app', value: supervisor.totalAppFeesPaid, color: AppColors.error)),
              Expanded(child: _EarnItem(label: 'Net', value: supervisor.totalNetEarnings, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Taux commission : ', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
              Text('${supervisor.commissionFromTransportsRate}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
              const Text(' — Frais app : ', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
              Text('${supervisor.commissionToAppRate}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarnItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _EarnItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${value.toStringAsFixed(0)} DA',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
      ],
    );
  }
}

// ─── MONTHLY PROGRESS ────────────────────────────────────────────
class _MonthlyProgressCard extends StatelessWidget {
  final SupervisorModel supervisor;
  const _MonthlyProgressCard({required this.supervisor});

  @override
  Widget build(BuildContext context) {
    final added    = supervisor.transportersAddedThisMonth;
    final required = supervisor.minMonthlyAddRequired;
    final progress = (added / required).clamp(0.0, 1.0);
    final isDone   = added >= required;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDone ? AppColors.success : AppColors.warning).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isDone ? AppColors.success : AppColors.warning).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isDone ? Icons.check_circle : Icons.track_changes,
                color: isDone ? AppColors.success : AppColors.warning),
              const SizedBox(width: 8),
              Text('Objectif mensuel', style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDone ? AppColors.success : AppColors.warning,
              )),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(isDone ? AppColors.success : AppColors.warning),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('$added / $required transporteurs ajoutés ce mois',
            style: TextStyle(fontSize: 13, color: isDone ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w500)),
          if (!isDone)
            Text('Ajoutez encore ${required - added} transporteur(s) pour maintenir vos commissions.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

// ─── REFERRAL TILE ────────────────────────────────────────────────
class _ReferralTile extends StatelessWidget {
  final SupervisorReferralModel referral;
  const _ReferralTile({required this.referral});

  @override
  Widget build(BuildContext context) {
    final t = referral.transporter;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: t != null
                ? Image.network(t.vehiclePhotoUrl, width: 52, height: 40, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 52, height: 40,
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.local_shipping, color: AppColors.primary)))
                : Container(width: 52, height: 40,
                    color: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.local_shipping, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t?.profile?.displayName ?? 'Transporteur',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(t?.vehicleType ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (referral.isActive ? AppColors.success : AppColors.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(referral.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(fontSize: 11, color: referral.isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
              ),
              if (t?.isValidated == true)
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified, size: 12, color: AppColors.primary),
                  SizedBox(width: 3),
                  Text('Validé', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── QR CODE PARRAINAGE ───────────────────────────────────────────
class _ReferralQrCard extends StatelessWidget {
  final SupervisorModel supervisor;
  const _ReferralQrCard({required this.supervisor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Mon code de parrainage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Partagez ce QR code aux transporteurs que vous parrainez',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          const SizedBox(height: 16),
          QrImageView(
            data: supervisor.referralCode ?? 'NO_CODE',
            version: QrVersions.auto,
            size: 160,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(supervisor.referralCode ?? '',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primary, letterSpacing: 3)),
          ),
        ],
      ),
    );
  }
}

// ─── AUTRES WIDGETS SUPERVISEUR ───────────────────────────────────
class _CommissionSuspendedAlert extends StatelessWidget {
  final String? reason;
  const _CommissionSuspendedAlert({this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Commissions suspendues', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
                if (reason != null) Text(reason!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyObjectiveAlert extends StatelessWidget {
  final SupervisorModel supervisor;
  const _MonthlyObjectiveAlert({required this.supervisor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ajoutez encore ${supervisor.minMonthlyAddRequired - supervisor.transportersAddedThisMonth} transporteur(s) ce mois pour conserver vos commissions.',
              style: const TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReferrals extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyReferrals({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('Pas encore de transporteurs', style: TextStyle(fontWeight: FontWeight.w600)),
          const Text('Commencez à parrainer des transporteurs.', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter un transporteur'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _SupervisorBottomNav extends StatelessWidget {
  final int currentIndex;
  const _SupervisorBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        switch (i) {
          case 0: context.go('/home/supervisor'); break;
          case 1: context.go('/home/supervisor/add-transporter'); break;
          case 2: context.go('/marketplace'); break;
          case 3: context.go('/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.person_add_outlined), activeIcon: Icon(Icons.person_add), label: 'Ajouter'),
        BottomNavigationBarItem(icon: Icon(Icons.store_outlined), activeIcon: Icon(Icons.store), label: 'Marché'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
      ],
    );
  }
}
