// lib/presentation/screens/transporter/transporter_home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transport_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class TransporterHomeScreen extends StatefulWidget {
  const TransporterHomeScreen({super.key});
  @override State<TransporterHomeScreen> createState() => _TransporterHomeScreenState();
}

class _TransporterHomeScreenState extends State<TransporterHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth      = context.read<AuthProvider>();
    final transProv = context.read<TransporterProvider>();
    final transport = context.read<TransportProvider>();

    if (auth.profile == null) return;
    await transProv.loadTransporter(auth.profile!.id);

    // Si pas encore de profil transporteur → setup
    if (transProv.transporter == null && mounted) {
      context.go('/home/transporter/setup');
      return;
    }

    // Écouter les nouvelles demandes entrant
    transport.subscribeToIncomingRequests(_onNewRequest);
  }

  void _onNewRequest(TransportRequestModel req) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewRequestBottomSheet(
        request: req,
        onAccept: () => _acceptRequest(req),
        onReject: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _acceptRequest(TransportRequestModel req) async {
    Navigator.pop(context);
    final transport  = context.read<TransportProvider>();
    final transProv  = context.read<TransporterProvider>();
    final auth       = context.read<AuthProvider>();

    final ok = await transport.acceptRequest(
      requestId: req.id,
      transporterId: transProv.transporter!.id,
      clientId: req.clientId,
    );

    if (ok && mounted) {
      context.push('/home/transporter/request/${req.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final transProv = context.watch<TransporterProvider>();
    final transport = context.watch<TransportProvider>();
    final notifProv = context.watch<NotificationProvider>();
    final theme     = Theme.of(context);
    final isDark    = theme.brightness == Brightness.dark;
    final t         = transProv.transporter;

    if (transProv.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Mon espace'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications')),
              if (notifProv.unreadCount > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: Center(child: Text('${notifProv.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                  ),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.push('/profile')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => transProv.loadTransporter(auth.profile!.id),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── CARTE STATUT PRINCIPAL ───────────────────────────
            _StatusCard(transporter: t, onToggle: () => transProv.toggleAvailability()),

            const SizedBox(height: 16),

            // ── ALERTE VALIDATION ────────────────────────────────
            if (t != null && !t.isValidated)
              _AlertBanner(
                icon: Icons.pending_outlined,
                title: 'En attente de validation',
                subtitle: 'Votre profil est en cours d\'examen par notre équipe.',
                color: AppColors.warning,
                onTap: null,
              ),

            if (t != null && t.isValidated && t.badge != null) ...[
              _BadgeCard(transporter: t),
              const SizedBox(height: 16),
            ],

            // ── SCORE DE COMPLÉTION ──────────────────────────────
            if (t != null) ...[
              _CompletionScore(transporter: t),
              const SizedBox(height: 16),
            ],

            // ── STATS RAPIDES ────────────────────────────────────
            if (t != null) _StatsRow(transporter: t),
            const SizedBox(height: 16),

            // ── ACTIONS RAPIDES ───────────────────────────────────
            Text('Actions rapides', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _ActionCard(
                  icon: Icons.history_outlined,
                  label: 'Historique',
                  color: AppColors.info,
                  onTap: () => context.push('/home/transporter/history'),
                ),
                _ActionCard(
                  icon: Icons.star_outline,
                  label: 'Mes avis',
                  color: AppColors.warning,
                  onTap: () => _showRatings(context, t),
                ),
                _ActionCard(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Options Premium',
                  color: AppColors.premiumGold,
                  onTap: () => context.push('/home/transporter/premium'),
                ),
                _ActionCard(
                  icon: Icons.edit_outlined,
                  label: 'Modifier profil',
                  color: AppColors.primary,
                  onTap: () => context.push('/home/transporter/setup'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── MARKETPLACE ───────────────────────────────────────
            _SectionCard(
              icon: Icons.store_outlined,
              title: 'Marché',
              subtitle: 'Achetez ou vendez des services',
              color: AppColors.success,
              onTap: () => context.go('/marketplace'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _TransporterBottomNav(currentIndex: 0),
    );
  }

  void _showRatings(BuildContext context, TransporterModel? t) {
    if (t == null) return;
    context.read<TransporterProvider>().loadRatings();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RatingsSheet(),
    );
  }
}

// ─── CARTE STATUT DISPONIBILITÉ ──────────────────────────────────
class _StatusCard extends StatelessWidget {
  final TransporterModel? transporter;
  final VoidCallback onToggle;
  const _StatusCard({required this.transporter, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isAvailable = transporter?.isAvailable ?? false;
    final isValidated = transporter?.isValidated ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAvailable
              ? [AppColors.success, const Color(0xFF2E7D32)]
              : [AppColors.textSecondaryLight, const Color(0xFF455A64)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isAvailable ? AppColors.success : Colors.grey).withOpacity(0.3),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? '🟢 Disponible' : '🔴 Indisponible',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isAvailable
                      ? 'Vous êtes visible par les clients'
                      : 'Vous n\'apparaissez pas dans la liste',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
                if (!isValidated) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('⏳ En attente validation admin', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: isAvailable,
            onChanged: isValidated ? (_) => onToggle() : null,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}

// ─── BADGE CARD ───────────────────────────────────────────────────
class _BadgeCard extends StatelessWidget {
  final TransporterModel transporter;
  const _BadgeCard({required this.transporter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: transporter.badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: transporter.badgeColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: transporter.badgeColor, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Badge ${transporter.badgeLabel}', style: TextStyle(
                fontWeight: FontWeight.w700, color: transporter.badgeColor,
              )),
              const Text('Compte vérifié et validé par l\'admin', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── SCORE COMPLÉTION PROFIL ─────────────────────────────────────
class _CompletionScore extends StatelessWidget {
  final TransporterModel transporter;
  const _CompletionScore({required this.transporter});

  @override
  Widget build(BuildContext context) {
    final score = transporter.validationScore;
    final color = score >= 80 ? AppColors.success : score >= 50 ? AppColors.warning : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Complétude du profil', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('$score%', style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
          if (score < 100) ...[
            const SizedBox(height: 10),
            _MissingDocsList(transporter: transporter),
          ],
        ],
      ),
    );
  }
}

class _MissingDocsList extends StatelessWidget {
  final TransporterModel transporter;
  const _MissingDocsList({required this.transporter});

  @override
  Widget build(BuildContext context) {
    final missing = <String>[];
    if (transporter.facePhotoUrl == null)          missing.add('Photo de visage (+10%)');
    if (transporter.licensePhotoUrl == null)        missing.add('Permis de conduire (+20%)');
    if (transporter.registrationPhotoUrl == null)   missing.add('Carte grise (+20%)');
    if (transporter.insurancePhotoUrl == null)      missing.add('Assurance véhicule (+20%)');
    if (transporter.technicalControlUrl == null)    missing.add('Contrôle technique (+10%)');

    if (missing.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Documents manquants :', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6, runSpacing: 4,
          children: missing.map((m) => Chip(
            label: Text(m, style: const TextStyle(fontSize: 11)),
            backgroundColor: AppColors.error.withOpacity(0.1),
            side: const BorderSide(color: AppColors.error, width: 0.5),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          )).toList(),
        ),
      ],
    );
  }
}

// ─── STATS ROW ────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final TransporterModel transporter;
  const _StatsRow({required this.transporter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatItem(label: 'Transports', value: '${transporter.totalTransports}', icon: Icons.local_shipping_outlined, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _StatItem(label: 'Note moy.', value: transporter.averageRating.toStringAsFixed(1), icon: Icons.star_outline, color: AppColors.warning)),
        const SizedBox(width: 12),
        Expanded(child: _StatItem(label: 'Avis', value: '${transporter.totalRatings}', icon: Icons.rate_review_outlined, color: AppColors.info)),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

// ─── ACTION CARD ──────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION CARD ────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ─── ALERT BANNER ────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _AlertBanner({required this.icon, required this.title, required this.subtitle, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET NOUVELLE DEMANDE ───────────────────────────────
class _NewRequestBottomSheet extends StatelessWidget {
  final TransportRequestModel request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _NewRequestBottomSheet({required this.request, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text('🚨 Nouvelle demande !', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.radio_button_checked, label: 'Départ', value: request.pickupAddress ?? '${request.pickupLat.toStringAsFixed(4)}, ${request.pickupLng.toStringAsFixed(4)}', color: AppColors.success),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.location_on, label: 'Arrivée', value: request.dropoffAddress ?? '${request.dropoffLat.toStringAsFixed(4)}, ${request.dropoffLng.toStringAsFixed(4)}', color: AppColors.error),
          const SizedBox(height: 10),
          if (request.estimatedDistanceKm != null)
            _InfoRow(icon: Icons.straighten, label: 'Distance', value: '${request.estimatedDistanceKm!.toStringAsFixed(1)} km', color: AppColors.info),
          const SizedBox(height: 10),
          if (request.totalPrice != null)
            _InfoRow(icon: Icons.payments_outlined, label: 'Prix total', value: '${request.totalPrice!.toStringAsFixed(0)} ${request.currency}', color: AppColors.primary),
          if (request.needsHandling)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _InfoRow(icon: Icons.people_outline, label: 'Manutention', value: 'Demandée', color: AppColors.warning),
            ),
          if (request.needsTransportInsurance)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _InfoRow(icon: Icons.security_outlined, label: 'Assurance', value: 'Demandée', color: AppColors.info),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close, color: AppColors.error),
                  label: const Text('Refuser', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Accepter'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text('$label : ', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    );
  }
}

// ─── RATINGS SHEET ───────────────────────────────────────────────
class _RatingsSheet extends StatelessWidget {
  const _RatingsSheet();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TransporterProvider>();
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Avis clients', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (prov.transporter != null) ...[
                    const Icon(Icons.star, color: AppColors.warning, size: 18),
                    const SizedBox(width: 4),
                    Text(prov.transporter!.averageRating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(' (${prov.transporter!.totalRatings})',
                      style: const TextStyle(color: AppColors.textSecondaryLight)),
                  ],
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: prov.ratings.isEmpty
                  ? const Center(child: Text('Aucun avis pour le moment'))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: prov.ratings.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final r = prov.ratings[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.15),
                            child: Text(r.client?.displayName.substring(0, 1).toUpperCase() ?? '?',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          ),
                          title: Row(
                            children: [
                              Text(r.client?.displayName ?? 'Client', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const Spacer(),
                              ...List.generate(5, (idx) => Icon(
                                Icons.star,
                                size: 14,
                                color: idx < r.score ? AppColors.warning : Colors.grey.withOpacity(0.3),
                              )),
                            ],
                          ),
                          subtitle: r.comment != null ? Text(r.comment!, style: const TextStyle(fontSize: 13)) : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BOTTOM NAV TRANSPORTEUR ─────────────────────────────────────
class _TransporterBottomNav extends StatelessWidget {
  final int currentIndex;
  const _TransporterBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        switch (i) {
          case 0: context.go('/home/transporter'); break;
          case 1: context.go('/home/transporter/premium'); break;
          case 2: context.go('/marketplace'); break;
          case 3: context.go('/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.workspace_premium_outlined), activeIcon: Icon(Icons.workspace_premium), label: 'Premium'),
        BottomNavigationBarItem(icon: Icon(Icons.store_outlined), activeIcon: Icon(Icons.store), label: 'Marché'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
      ],
    );
  }
}
