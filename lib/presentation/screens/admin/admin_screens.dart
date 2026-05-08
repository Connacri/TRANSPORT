// lib/presentation/screens/admin/admin_business_rules_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
// Imports
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/transport_provider.dart';


class AdminBusinessRulesScreen extends StatelessWidget {
  const AdminBusinessRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Règles métier')),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionTitle(title: '💰 Commissions', subtitle: 'Taux appliqués sur chaque transport'),
                ..._filterRules(admin.businessRules, ['app_commission_rate', 'supervisor_commission_rate', 'supervisor_app_fee_rate', 'marketplace_commission_rate'])
                    .map((r) => _RuleTile(rule: r, suffix: '%', onEdit: (v) => _saveRule(context, admin, r, v))),

                const SizedBox(height: 16),
                const _SectionTitle(title: '🚛 Tarification transport', subtitle: 'Prix de base modifiables par région'),
                ..._filterRules(admin.businessRules, ['base_price_per_km', 'handling_fee_rate', 'insurance_rate'])
                    .map((r) => _RuleTile(rule: r, suffix: r.key.contains('price') ? ' DA' : '%', onEdit: (v) => _saveRule(context, admin, r, v))),

                const SizedBox(height: 16),
                const _SectionTitle(title: '👥 Superviseurs', subtitle: 'Conditions d\'activité et niveaux'),
                ..._filterRules(admin.businessRules, ['supervisor_min_monthly_adds', 'supervisor_max_silver', 'supervisor_max_gold', 'supervisor_max_platinum'])
                    .map((r) => _RuleTile(rule: r, suffix: ' transporteurs', onEdit: (v) => _saveRule(context, admin, r, v))),

                const SizedBox(height: 16),
                const _SectionTitle(title: '📍 Tracking', subtitle: 'Intervalles de localisation'),
                ..._filterRules(admin.businessRules, ['tracking_default_interval_seconds', 'tracking_premium_interval_seconds'])
                    .map((r) => _RuleTile(rule: r, suffix: 's', onEdit: (v) => _saveRule(context, admin, r, v))),

                const SizedBox(height: 16),
                const _SectionTitle(title: '⚡ Tarification dynamique', subtitle: 'Multiplicateurs heures de pointe'),
                ..._filterRules(admin.businessRules, ['surge_pricing_multiplier_peak'])
                    .map((r) => _RuleTile(rule: r, suffix: 'x', onEdit: (v) => _saveRule(context, admin, r, v))),

                const SizedBox(height: 16),
                const _SectionTitle(title: '⭐ Notes & Avis', subtitle: 'Paramètres d\'affichage'),
                ..._filterRules(admin.businessRules, ['rating_min_count_to_display'])
                    .map((r) => _RuleTile(rule: r, suffix: ' avis min', onEdit: (v) => _saveRule(context, admin, r, v))),
              ],
            ),
    );
  }

  List<BusinessRuleModel> _filterRules(List<BusinessRuleModel> rules, List<String> keys) {
    return rules.where((r) => keys.contains(r.key)).toList();
  }

  Future<void> _saveRule(BuildContext context, AdminProvider admin, BusinessRuleModel rule, double newValue) async {
    final firstKey = rule.value.keys.first;
    final ok = await admin.updateBusinessRule(rule.id, {firstKey: newValue});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Règle mise à jour' : '❌ ${admin.error}'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title, subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final BusinessRuleModel rule;
  final String suffix;
  final void Function(double) onEdit;

  const _RuleTile({required this.rule, required this.suffix, required this.onEdit});

  String get _label {
    const labels = {
      'app_commission_rate':               'Commission application',
      'supervisor_commission_rate':        'Commission superviseur',
      'supervisor_app_fee_rate':           'Frais app sur commission sup.',
      'marketplace_commission_rate':       'Commission marketplace',
      'base_price_per_km':                 'Prix de base / km',
      'handling_fee_rate':                 'Frais manutention',
      'insurance_rate':                    'Taux assurance transport',
      'supervisor_min_monthly_adds':       'Ajouts mensuels minimum',
      'supervisor_max_silver':             'Max transporteurs (Silver)',
      'supervisor_max_gold':               'Max transporteurs (Gold)',
      'supervisor_max_platinum':           'Max transporteurs (Platinum)',
      'tracking_default_interval_seconds': 'Intervalle standard',
      'tracking_premium_interval_seconds': 'Intervalle premium',
      'surge_pricing_multiplier_peak':     'Multiplicateur heure de pointe',
      'rating_min_count_to_display':       'Notes minimum pour affichage',
    };
    return labels[rule.key] ?? rule.key;
  }

  @override
  Widget build(BuildContext context) {
    final value = rule.numericValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(_label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: rule.description != null ? Text(rule.description!, style: const TextStyle(fontSize: 11)) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$value$suffix',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondaryLight),
              onPressed: () => _showEditDialog(context, value?.toDouble() ?? 0),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, double currentValue) {
    final ctrl = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Valeur actuelle : $currentValue$suffix',
              style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Nouvelle valeur',
                suffixText: suffix.trim(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v != null) { onEdit(v); Navigator.pop(context); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADMIN TRANSPORTER VALIDATION SCREEN
// ═══════════════════════════════════════════════════════════════
class AdminTransporterValidationScreen extends StatelessWidget {
  const AdminTransporterValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final auth  = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Validation (${admin.pendingTransporters.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: () => admin.loadDashboardData()),
        ],
      ),
      body: admin.pendingTransporters.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                  SizedBox(height: 16),
                  Text('Tout est à jour !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('Aucun transporteur en attente de validation.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: admin.pendingTransporters.length,
              itemBuilder: (_, i) => _PendingTransporterCard(
                transporter: admin.pendingTransporters[i],
                onValidate: () => _validate(context, admin, auth, admin.pendingTransporters[i], true),
                onReject: () => _showRejectDialog(context, admin, auth, admin.pendingTransporters[i]),
              ),
            ),
    );
  }

  Future<void> _validate(BuildContext ctx, AdminProvider admin, AuthProvider auth, TransporterModel t, bool approve) async {
    final ok = await admin.validateTransporter(
      transporterId: t.id,
      adminProfileId: auth.profile!.id,
      validate: approve,
    );
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Transporteur validé avec succès' : '❌ ${admin.error}'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
    }
  }

  void _showRejectDialog(BuildContext ctx, AdminProvider admin, AuthProvider auth, TransporterModel t) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Motif de refus'),
        content: TextField(controller: ctrl, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Expliquez le motif de refus')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await admin.validateTransporter(
                transporterId: t.id,
                adminProfileId: auth.profile!.id,
                validate: false,
                suspensionReason: ctrl.text,
              );
            },
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }
}

class _PendingTransporterCard extends StatelessWidget {
  final TransporterModel transporter;
  final VoidCallback onValidate;
  final VoidCallback onReject;

  const _PendingTransporterCard({
    required this.transporter,
    required this.onValidate,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // En-tête profil
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: transporter.facePhotoUrl != null
                      ? NetworkImage(transporter.facePhotoUrl!)
                      : null,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: transporter.facePhotoUrl == null
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transporter.profile?.displayName ?? 'Transporteur',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(transporter.profile?.email ?? '',
                        style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                      Text('${transporter.profile?.phone ?? "N/A"} • ${transporter.vehicleType}',
                        style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${transporter.validationScore}%',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                ),
              ],
            ),
          ),

          // Véhicule
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(transporter.vehiclePhotoUrl,
                    width: 100, height: 70, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 100, height: 70,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.local_shipping, color: AppColors.primary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${transporter.vehicleType} ${transporter.vehicleBrand ?? ""}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Plaque : ${transporter.vehiclePlate}'),
                      if (transporter.vehicleCapacityKg != null)
                        Text('Capacité : ${transporter.vehicleCapacityKg} kg'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Documents uploaded
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                const _DocChip(label: 'Photo', ok: true),
                _DocChip(label: 'Visage', ok: transporter.facePhotoUrl != null),
                _DocChip(label: 'Permis', ok: transporter.licensePhotoUrl != null),
                _DocChip(label: 'Carte grise', ok: transporter.registrationPhotoUrl != null),
                _DocChip(label: 'Assurance', ok: transporter.insurancePhotoUrl != null),
                _DocChip(label: 'Contrôle tech.', ok: transporter.technicalControlUrl != null),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: AppColors.error, size: 18),
                    label: const Text('Refuser', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: onValidate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocChip extends StatelessWidget {
  final String label;
  final bool ok;
  const _DocChip({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: ok ? AppColors.success : AppColors.error)),
      backgroundColor: (ok ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
      side: BorderSide(color: (ok ? AppColors.success : AppColors.error).withValues(alpha: 0.4)),
      avatar: Icon(ok ? Icons.check : Icons.close, size: 14, color: ok ? AppColors.success : AppColors.error),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TRACKING SCREEN (UBER/YASSIR STYLE)
// ═══════════════════════════════════════════════════════════════
class TrackingScreen extends StatefulWidget {
  final String requestId;
  const TrackingScreen({super.key, required this.requestId});
  @override State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransportProvider>().loadHistory(
        profileId: context.read<AuthProvider>().profile!.id,
        role: context.read<AuthProvider>().role,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final transport = context.watch<TransportProvider>();
    final request   = transport.activeRequest;
    final theme     = Theme.of(context);

    if (request == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pickup  = LatLng(request.pickupLat,  request.pickupLng);
    final dropoff = LatLng(request.dropoffLat, request.dropoffLng);

    return Scaffold(
      body: Stack(
        children: [
          // ── CARTE PLEIN ÉCRAN ─────────────────────────────────
          TrackingMap(
            pickupPoint: pickup,
            dropoffPoint: dropoff,
            transporterPosition: transport.transporterPos,
            trackingHistory: transport.trackingPoints,
            height: MediaQuery.of(context).size.height,
          ),

          // ── APP BAR FLOTTANTE ─────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: request.statusColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                    ),
                    child: Text(request.statusLabel,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM SHEET INFO ─────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),

                  // Stepper statut
                  RequestStatusStepper(currentStatus: request.status),
                  const SizedBox(height: 20),

                  // Adresses
                  _AddressRow(icon: Icons.radio_button_checked, color: AppColors.success,
                    label: 'Départ', address: request.pickupAddress ?? 'Position actuelle'),
                  Container(margin: const EdgeInsets.only(left: 11), width: 2, height: 20,
                    color: Colors.grey.withValues(alpha: 0.3)),
                  _AddressRow(icon: Icons.location_on, color: AppColors.error,
                    label: 'Arrivée', address: request.dropoffAddress ?? 'Destination'),

                  const SizedBox(height: 16),

                  // Infos transport
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (request.estimatedDistanceKm != null)
                        _InfoChip(icon: Icons.straighten, label: '${request.estimatedDistanceKm!.toStringAsFixed(1)} km'),
                      if (request.estimatedDurationMin != null)
                        _InfoChip(icon: Icons.timer_outlined, label: '${request.estimatedDurationMin} min'),
                      if (request.totalPrice != null)
                        _InfoChip(icon: Icons.payments_outlined, label: '${request.totalPrice!.toStringAsFixed(0)} DA'),
                    ],
                  ),

                  // Bouton annuler si en attente
                  if (request.status == RequestStatus.pending || request.status == RequestStatus.accepted) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                      label: const Text('Annuler', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () => _cancelRequest(context, request),
                    ),
                  ],

                  // Bouton noter si terminé
                  if (request.status == RequestStatus.completed) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Noter le transporteur'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      onPressed: () => _showRatingDialog(context, request),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelRequest(BuildContext context, TransportRequestModel req) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le transport ?'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette demande ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Non')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<TransportProvider>().cancelRequest(
                requestId: req.id,
                reason: 'Annulé par le client',
                otherPartyProfileId: req.transporterId ?? '',
              );
            },
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, TransportRequestModel req) {
    int score = 5;
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Noter le transporteur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setState(() => score = i + 1),
                  child: Icon(Icons.star,
                    size: 36,
                    color: i < score ? AppColors.warning : Colors.grey.withValues(alpha: 0.3),
                  ),
                )),
              ),
              const SizedBox(height: 16),
              TextField(controller: ctrl, maxLines: 3,
                decoration: const InputDecoration(labelText: 'Commentaire (optionnel)', hintText: 'Votre avis...')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<TransportProvider>().submitRating(
                  requestId: req.id,
                  transporterId: req.transporterId!,
                  clientId: req.clientId,
                  score: score,
                  comment: ctrl.text.isEmpty ? null : ctrl.text,
                );
                if (context.mounted) context.pop();
              },
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, address;
  const _AddressRow({required this.icon, required this.color, required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
              Text(address, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
        ],
      ),
    );
  }
}


