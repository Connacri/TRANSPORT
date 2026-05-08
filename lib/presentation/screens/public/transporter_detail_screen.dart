// lib/presentation/screens/public/transporter_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transport_provider.dart';
import '../../widgets/widgets.dart';

class TransporterDetailScreen extends StatefulWidget {
  final String transporterId;
  const TransporterDetailScreen({super.key, required this.transporterId});
  @override State<TransporterDetailScreen> createState() => _TransporterDetailScreenState();
}

class _TransporterDetailScreenState extends State<TransporterDetailScreen>
    with SingleTickerProviderStateMixin {
  TransporterModel? _transporter;
  List<RatingModel> _ratings = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.instance.client
          .from('transporters')
          .select('*, profiles(*)')
          .eq('id', widget.transporterId)
          .single();
      final ratings = await SupabaseService.instance.getTransporterRatings(widget.transporterId);
      if (mounted) setState(() { _transporter = TransporterModel.fromJson(data); _ratings = ratings; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_transporter == null) return const Scaffold(body: Center(child: Text('Introuvable')));

    final t     = _transporter!;
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(t.vehiclePhotoUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.primary.withOpacity(0.15),
                      child: const Icon(Icons.local_shipping, size: 80, color: AppColors.primary))),
                  // Gradient overlay
                  const DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  )),
                  // Premium badge
                  if (t.isPremium)
                    Positioned(top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.premiumGold, borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondaryLight,
              tabs: const [Tab(text: 'Profil'), Tab(text: 'Avis')],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _ProfileTab(transporter: t),
            _ReviewsTab(ratings: _ratings, transporter: t),
          ],
        ),
      ),

      // Bouton Réserver
      bottomNavigationBar: t.isValidated && t.isAvailable
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Réserver ce transporteur'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                  onPressed: () => context.push('/home/public/request/${t.id}'),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    t.isValidated ? '⛔ Indisponible pour le moment' : '⏳ En attente de validation',
                    style: const TextStyle(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final TransporterModel transporter;
  const _ProfileTab({required this.transporter});

  @override
  Widget build(BuildContext context) {
    final t = transporter;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Nom + badge
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.profile?.displayName ?? 'Transporteur',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(t.vehicleType, style: const TextStyle(color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            if (t.badge != null)
              Column(
                children: [
                  Icon(Icons.verified, color: t.badgeColor, size: 32),
                  Text(t.badgeLabel, style: TextStyle(color: t.badgeColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Stats
        Row(
          children: [
            _StatBox(label: 'Note', value: t.averageRating.toStringAsFixed(1), icon: Icons.star, color: AppColors.warning),
            const SizedBox(width: 10),
            _StatBox(label: 'Transports', value: '${t.totalTransports}', icon: Icons.local_shipping_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            _StatBox(label: 'Avis', value: '${t.totalRatings}', icon: Icons.rate_review_outlined, color: AppColors.info),
          ],
        ),
        const SizedBox(height: 20),

        // Véhicule
        _InfoSection(title: '🚛 Véhicule', children: [
          _Detail(label: 'Type', value: t.vehicleType),
          if (t.vehicleBrand != null) _Detail(label: 'Marque', value: '${t.vehicleBrand} ${t.vehicleModel ?? ""}'),
          if (t.vehicleYear != null) _Detail(label: 'Année', value: '${t.vehicleYear}'),
          _Detail(label: 'Plaque', value: t.vehiclePlate),
          if (t.vehicleCapacityKg != null) _Detail(label: 'Capacité', value: '${t.vehicleCapacityKg} kg'),
          if (t.vehicleCapacityM3 != null) _Detail(label: 'Volume', value: '${t.vehicleCapacityM3} m³'),
        ]),
        const SizedBox(height: 16),

        // Tarifs
        _InfoSection(title: '💰 Tarification', children: [
          if (t.basePricePerKm != null) _Detail(label: 'Prix / km', value: '${t.basePricePerKm!.toStringAsFixed(0)} DA'),
          if (t.minimumPrice != null) _Detail(label: 'Prix minimum', value: '${t.minimumPrice!.toStringAsFixed(0)} DA'),
        ]),
        const SizedBox(height: 16),

        // Services
        _InfoSection(title: '⚙️ Services proposés', children: [
          _ServiceRow(label: 'Manutention', ok: t.offersHandling,
            extra: t.offersHandling ? '${t.handlingFeeRate.toStringAsFixed(0)}% du prix' : null),
          _ServiceRow(label: 'Assurance transport', ok: t.offersTransportInsurance,
            extra: t.offersTransportInsurance ? '${t.insuranceRatePercent.toStringAsFixed(1)}% de la valeur' : null),
        ]),
        const SizedBox(height: 16),

        // Documents vérifiés
        _InfoSection(title: '📋 Documents vérifiés', children: [
          _DocRow(label: 'Photo véhicule', ok: true),
          _DocRow(label: 'Visage', ok: t.facePhotoUrl != null),
          _DocRow(label: 'Permis de conduire', ok: t.licensePhotoUrl != null),
          _DocRow(label: 'Carte grise', ok: t.registrationPhotoUrl != null),
          _DocRow(label: 'Assurance véhicule', ok: t.insurancePhotoUrl != null),
          _DocRow(label: 'Contrôle technique', ok: t.technicalControlUrl != null),
        ]),
      ],
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  final List<RatingModel> ratings;
  final TransporterModel transporter;
  const _ReviewsTab({required this.ratings, required this.transporter});

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline, size: 60, color: Color(0xFFCCCCCC)),
          SizedBox(height: 12),
          Text('Pas encore d\'avis', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: ratings.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return _RatingSummary(transporter: transporter, ratings: ratings);
        }
        return _ReviewCard(rating: ratings[i - 1]);
      },
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final TransporterModel transporter;
  final List<RatingModel> ratings;
  const _RatingSummary({required this.transporter, required this.ratings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(transporter.averageRating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.warning)),
              RatingBarIndicator(
                rating: transporter.averageRating,
                itemSize: 18,
                itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.warning),
              ),
              Text('${transporter.totalRatings} avis',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = ratings.where((r) => r.score == star).length;
                final pct   = ratings.isEmpty ? 0.0 : count / ratings.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$star', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      const Icon(Icons.star, size: 12, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct, minHeight: 6,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation(AppColors.warning),
                        ),
                      )),
                      const SizedBox(width: 6),
                      Text('$count', style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final RatingModel rating;
  const _ReviewCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: Text(rating.client?.displayName.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rating.client?.displayName ?? 'Client',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(DateFormat('dd/MM/yyyy').format(rating.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  ],
                ),
              ),
              RatingBarIndicator(
                rating: rating.score.toDouble(),
                itemSize: 16,
                itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.warning),
              ),
            ],
          ),
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(rating.comment!, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        ]),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(14)),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  final String label, value;
  const _Detail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text('$label : ', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String label;
  final bool ok;
  final String? extra;
  const _ServiceRow({required this.label, required this.ok, this.extra});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? AppColors.success : AppColors.error, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        if (extra != null) ...[
          const Spacer(),
          Text(extra!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        ],
      ]),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final bool ok;
  const _DocRow({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 16, color: ok ? AppColors.success : Colors.grey.withOpacity(0.4)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: ok ? null : AppColors.textSecondaryLight, fontSize: 13)),
      ]),
    );
  }
}
