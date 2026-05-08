// lib/presentation/screens/public/tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transport_provider.dart';
import '../../widgets/widgets.dart';

class TrackingScreen extends StatefulWidget {
  final String requestId;
  const TrackingScreen({super.key, required this.requestId});
  @override State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final transport = context.read<TransportProvider>();
    // Charger la demande active si pas déjà chargée
    if (transport.activeRequest?.id != widget.requestId) {
      try {
        final data = await SupabaseService.instance.client
            .from('transport_requests')
            .select()
            .eq('id', widget.requestId)
            .single();
        // Met à jour activeRequest via le provider
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final transport = context.watch<TransportProvider>();
    final auth      = context.watch<AuthProvider>();
    final req       = transport.activeRequest;
    final theme     = Theme.of(context);

    if (req == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pickup  = LatLng(req.pickupLat,  req.pickupLng);
    final dropoff = LatLng(req.dropoffLat, req.dropoffLng);

    return Scaffold(
      body: Stack(
        children: [
          // ── CARTE PLEIN ÉCRAN ─────────────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: TrackingMap(
              pickupPoint: pickup,
              dropoffPoint: dropoff,
              transporterPosition: transport.transporterPos,
              trackingHistory: transport.trackingPoints,
              height: MediaQuery.of(context).size.height,
            ),
          ),

          // ── APP BAR FLOTTANTE ─────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _FloatingBtn(icon: Icons.arrow_back, onTap: () => context.pop()),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: req.statusColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                    ),
                    child: Text(req.statusLabel,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  _FloatingBtn(icon: Icons.refresh_outlined, onTap: _init),
                ],
              ),
            ),
          ),

          // ── SPEED INDICATOR (si en cours) ─────────────────────
          if (req.status == RequestStatus.inProgress && transport.trackingPoints.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              child: _SpeedIndicator(
                speed: transport.trackingPoints.last.speedKmh ?? 0,
              ),
            ),

          // ── BOTTOM INFO SHEET ─────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20)],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),

                  // Stepper
                  RequestStatusStepper(currentStatus: req.status),
                  const SizedBox(height: 16),

                  // Route
                  _RouteRow(pickup: req.pickupAddress, dropoff: req.dropoffAddress),
                  const SizedBox(height: 14),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (req.estimatedDistanceKm != null)
                        _StatChip(icon: Icons.straighten_outlined, label: '${req.estimatedDistanceKm!.toStringAsFixed(1)} km'),
                      if (req.estimatedDurationMin != null)
                        _StatChip(icon: Icons.timer_outlined, label: '${req.estimatedDurationMin} min'),
                      if (req.totalPrice != null)
                        _StatChip(icon: Icons.payments_outlined, label: '${req.totalPrice!.toStringAsFixed(0)} DA'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Actions
                  _TrackingActions(request: req, auth: auth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FloatingBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _SpeedIndicator extends StatelessWidget {
  final double speed;
  const _SpeedIndicator({required this.speed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text('${speed.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          const Text('km/h', style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String? pickup, dropoff;
  const _RouteRow({this.pickup, this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            const Icon(Icons.radio_button_checked, color: AppColors.success, size: 16),
            Container(width: 1.5, height: 24, color: Colors.grey.withOpacity(0.3)),
            const Icon(Icons.location_on, color: AppColors.error, size: 16),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup ?? 'Départ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Text(dropoff ?? 'Arrivée', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
      ]),
    );
  }
}

class _TrackingActions extends StatefulWidget {
  final TransportRequestModel request;
  final AuthProvider auth;
  const _TrackingActions({required this.request, required this.auth});
  @override State<_TrackingActions> createState() => _TrackingActionsState();
}

class _TrackingActionsState extends State<_TrackingActions> {
  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le transport ?'),
        content: const Text('Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<TransportProvider>().cancelRequest(
      requestId: widget.request.id,
      reason: 'Annulé par le client',
      otherPartyProfileId: widget.request.transporterId ?? '',
    );
    if (mounted) context.pop();
  }

  Future<void> _rate() async {
    int score = 5;
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('⭐ Noter le transporteur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setDlgState(() => score = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.star, size: 38,
                      color: i < score ? AppColors.warning : Colors.grey.withOpacity(0.3)),
                  ),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)',
                  hintText: 'Votre expérience...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<TransportProvider>().submitRating(
                  requestId: widget.request.id,
                  transporterId: widget.request.transporterId!,
                  clientId: widget.request.clientId,
                  score: score,
                  comment: commentCtrl.text.isEmpty ? null : commentCtrl.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Merci pour votre avis !'), backgroundColor: AppColors.success));
                  context.pop();
                }
              },
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Column(
      children: [
        if (req.status == RequestStatus.pending || req.status == RequestStatus.accepted)
          AppButton(
            label: 'Annuler la demande',
            color: AppColors.error,
            outlined: true,
            onPressed: _cancel,
          ),
        if (req.status == RequestStatus.completed) ...[
          AppButton(
            label: '⭐ Noter le transporteur',
            onPressed: _rate,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Retour à l\'accueil',
            outlined: true,
            onPressed: () => context.go('/home/public'),
          ),
        ],
        if (req.status == RequestStatus.inProgress)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success)),
                SizedBox(width: 10),
                Text('Transport en cours...', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}
