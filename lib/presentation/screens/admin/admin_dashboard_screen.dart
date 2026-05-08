// lib/presentation/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final auth  = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: () => admin.loadDashboardData()),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.push('/profile')),
        ],
      ),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => admin.loadDashboardData(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── BIENVENUE ────────────────────────────────────
                  _WelcomeHeader(name: auth.profile?.displayName ?? 'Admin'),
                  const SizedBox(height: 20),

                  // ── KPIs ────────────────────────────────────────
                  _KpiGrid(admin: admin),
                  const SizedBox(height: 20),

                  // ── ALERTE VALIDATION EN ATTENTE ─────────────────
                  if (admin.pendingTransporters.isNotEmpty)
                    _PendingAlert(
                      count: admin.pendingTransporters.length,
                      onTap: () => context.push('/home/admin/validate'),
                    ),

                  const SizedBox(height: 20),

                  // ── ACTIONS ADMIN ─────────────────────────────────
                  Text('Gestion', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _AdminActionsGrid(),

                  const SizedBox(height: 20),

                  // ── RÈGLES MÉTIER RAPIDES ─────────────────────────
                  _BusinessRulesPreview(rules: admin.businessRules),

                  const SizedBox(height: 20),

                  // ── SUPERVISEURS ──────────────────────────────────
                  _SupervisorsPreview(supervisors: admin.supervisors),
                ],
              ),
            ),
      bottomNavigationBar: _AdminBottomNav(currentIndex: 0),
    );
  }
}

// ─── WELCOME HEADER ───────────────────────────────────────────────
class _WelcomeHeader extends StatelessWidget {
  final String name;
  const _WelcomeHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
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
                Text('Bonjour, $name 👋', style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 4),
                Text(
                  'Panneau de contrôle TransportHub',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary, size: 30),
          ),
        ],
      ),
    );
  }
}

// ─── KPI GRID ─────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final AdminProvider admin;
  const _KpiGrid({required this.admin});

  @override
  Widget build(BuildContext context) {
    final kpis = [
      _KpiData('En attente', '${admin.pendingTransporters.length}', Icons.pending_outlined, AppColors.warning),
      _KpiData('Superviseurs', '${admin.supervisors.length}', Icons.supervisor_account_outlined, AppColors.info),
      _KpiData('Régions', '${admin.regions.length}', Icons.map_outlined, AppColors.success),
      _KpiData('Règles', '${admin.businessRules.length}', Icons.rule_outlined, AppColors.primary),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
      ),
      itemCount: kpis.length,
      itemBuilder: (_, i) => _KpiCard(data: kpis[i]),
    );
  }
}

class _KpiData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: data.color, size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: data.color)),
              Text(data.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── ALERTE VALIDATION ────────────────────────────────────────────
class _PendingAlert extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingAlert({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count transporteur(s) en attente de validation',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                  const Text('Appuyez pour examiner et valider les profils',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}

// ─── ADMIN ACTIONS GRID ───────────────────────────────────────────
class _AdminActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem('Valider transporteurs', Icons.verified_outlined, AppColors.success, '/home/admin/validate'),
      _ActionItem('Règles métier', Icons.tune_outlined, AppColors.primary, '/home/admin/rules'),
      _ActionItem('Superviseurs', Icons.supervisor_account_outlined, AppColors.info, '/home/admin/supervisors'),
      _ActionItem('Boutiques', Icons.storefront_outlined, AppColors.warning, '/home/admin/validate'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => context.push(actions[i].route),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: actions[i].color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: actions[i].color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(actions[i].icon, color: actions[i].color, size: 30),
              const SizedBox(height: 8),
              Text(actions[i].label,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: actions[i].color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  final String label, route;
  final IconData icon;
  final Color color;
  const _ActionItem(this.label, this.icon, this.color, this.route);
}

// ─── RÈGLES MÉTIER PREVIEW ────────────────────────────────────────
class _BusinessRulesPreview extends StatelessWidget {
  final List<BusinessRuleModel> rules;
  const _BusinessRulesPreview({required this.rules});

  @override
  Widget build(BuildContext context) {
    final keyRules = rules.where((r) => [
      'app_commission_rate',
      'supervisor_commission_rate',
      'base_price_per_km',
      'tracking_default_interval_seconds',
    ].contains(r.key)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Règles métier', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(onPressed: () => context.push('/home/admin/rules'), child: const Text('Tout voir')),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: keyRules.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.rule_outlined, color: AppColors.primary, size: 20),
                    title: Text(_ruleLabel(r.key), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _ruleValue(r),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13),
                      ),
                    ),
                  ),
                  if (i < keyRules.length - 1) const Divider(height: 1, indent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _ruleLabel(String key) {
    switch (key) {
      case 'app_commission_rate':                return 'Commission app';
      case 'supervisor_commission_rate':         return 'Commission superviseur';
      case 'base_price_per_km':                  return 'Prix base / km';
      case 'tracking_default_interval_seconds':  return 'Intervalle tracking';
      default:                                   return key;
    }
  }

  String _ruleValue(BusinessRuleModel r) {
    final v = r.numericValue;
    if (r.key.contains('rate')) return '$v%';
    if (r.key.contains('price')) return '$v DA';
    if (r.key.contains('seconds')) return '${v}s';
    return '$v';
  }
}

// ─── SUPERVISEURS PREVIEW ─────────────────────────────────────────
class _SupervisorsPreview extends StatelessWidget {
  final List<SupervisorModel> supervisors;
  const _SupervisorsPreview({required this.supervisors});

  @override
  Widget build(BuildContext context) {
    final top = supervisors.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Superviseurs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(onPressed: () => context.push('/home/admin/supervisors'), child: const Text('Tout voir')),
          ],
        ),
        const SizedBox(height: 8),
        if (top.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Aucun superviseur')))
        else
          ...top.map((s) => _SupervisorTile(supervisor: s)),
      ],
    );
  }
}

class _SupervisorTile extends StatelessWidget {
  final SupervisorModel supervisor;
  const _SupervisorTile({required this.supervisor});

  @override
  Widget build(BuildContext context) {
    final tierColor = supervisor.tier == SupervisorTier.platinum
        ? AppColors.badgePlatinum
        : supervisor.tier == SupervisorTier.gold
            ? AppColors.badgeGold
            : AppColors.badgeSilver;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tierColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: tierColor.withOpacity(0.2),
            child: Text(
              supervisor.profile?.displayName.substring(0, 1).toUpperCase() ?? 'S',
              style: TextStyle(fontWeight: FontWeight.w700, color: tierColor, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(supervisor.profile?.displayName ?? 'Superviseur',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tierColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(supervisor.tierLabel,
                        style: TextStyle(fontSize: 10, color: tierColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${supervisor.referrals.length}/${supervisor.maxTransporters} transporteurs • ${supervisor.totalNetEarnings.toStringAsFixed(0)} DA',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
          Icon(
            supervisor.isCommissionActive ? Icons.check_circle : Icons.cancel,
            color: supervisor.isCommissionActive ? AppColors.success : AppColors.error,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ─── ADMIN BOTTOM NAV ─────────────────────────────────────────────
class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  const _AdminBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        switch (i) {
          case 0: context.go('/home/admin'); break;
          case 1: context.go('/home/admin/validate'); break;
          case 2: context.go('/home/admin/rules'); break;
          case 3: context.go('/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.verified_outlined), activeIcon: Icon(Icons.verified), label: 'Validation'),
        BottomNavigationBarItem(icon: Icon(Icons.tune_outlined), activeIcon: Icon(Icons.tune), label: 'Règles'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
      ],
    );
  }
}
