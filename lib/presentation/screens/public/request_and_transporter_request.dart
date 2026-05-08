// lib/presentation/screens/public/request_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/services/tracking_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../providers/transport_provider.dart';
import '../../widgets/widgets.dart';

import 'package:latlong2/latlong.dart';
class RequestScreen extends StatefulWidget {
  final String transporterId;
  const RequestScreen({super.key, required this.transporterId});
  @override State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  TransporterModel? _transporter;
  Position?         _myPos;
  bool              _loading = true;

  // Form
  final _cargoCtrl     = TextEditingController();
  final _weightCtrl    = TextEditingController();
  final _pickupCtrl    = TextEditingController();
  final _dropoffCtrl   = TextEditingController();
  bool  _needsHandling = false;
  bool  _needsInsurance= false;

  // Estimations
  double? _estimatedDistance;
  double? _estimatedPrice;
  double? _handlingFee;
  double? _insuranceFee;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final data = await SupabaseService.instance.client
          .from('transporters').select('*, profiles(*)').eq('id', widget.transporterId).single();
      _transporter = TransporterModel.fromJson(data);
      _myPos = await TrackingService.instance.getCurrentPosition();
      if (_myPos != null) {
        _pickupCtrl.text = 'Ma position actuelle (${_myPos!.latitude.toStringAsFixed(4)}, ${_myPos!.longitude.toStringAsFixed(4)})';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() { _cargoCtrl.dispose(); _weightCtrl.dispose(); _pickupCtrl.dispose(); _dropoffCtrl.dispose(); super.dispose(); }

  void _calculateEstimate() {
    if (_transporter == null || _myPos == null) return;
    final t = _transporter!;
    if (t.currentLat == null) return;

    // Distance simulée (en production : OSRM routing)
    final dist = TrackingService.instance.calculateDistance(
      _myPos!.latitude, _myPos!.longitude,
      t.currentLat!, t.currentLng!,
    ) * 2.5; // Simulation aller

    final base     = max(t.minimumPrice ?? 0, (t.basePricePerKm ?? 50) * dist);
    final handling = _needsHandling ? base * (t.handlingFeeRate / 100) : 0.0;
    final insurance= _needsInsurance ? base * (t.insuranceRatePercent / 100) : 0.0;

    setState(() {
      _estimatedDistance = dist;
      _estimatedPrice    = base;
      _handlingFee       = handling.toDouble();
      _insuranceFee      = insurance.toDouble();
    });
  }

  Future<void> _submit() async {
    if (_transporter == null || _myPos == null) return;
    if (_dropoffCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez votre destination'), backgroundColor: AppColors.error));
      return;
    }

    final auth      = context.read<AuthProvider>();
    final transport = context.read<TransportProvider>();

    final t      = _transporter!;
    final dist   = _estimatedDistance ?? 10.0;
    final base   = _estimatedPrice ?? (t.basePricePerKm ?? 50) * dist;
    final handling  = _needsHandling   ? base * (t.handlingFeeRate / 100) : 0.0;
    final insurance = _needsInsurance  ? base * (t.insuranceRatePercent / 100) : 0.0;

    final request = await transport.createRequest(
      clientId: auth.profile!.id,
      transporterId: widget.transporterId,
      pickupLat:  _myPos!.latitude,
      pickupLng:  _myPos!.longitude,
      pickupAddress: _pickupCtrl.text,
      dropoffLat: _myPos!.latitude + 0.05,  // simulation — remplacer par geocoding
      dropoffLng: _myPos!.longitude + 0.05,
      dropoffAddress: _dropoffCtrl.text,
      estimatedDistanceKm: dist,
      estimatedDurationMin: (dist / 40 * 60).round(),
      cargoDescription: _cargoCtrl.text.isEmpty ? null : _cargoCtrl.text,
      cargoWeightKg: double.tryParse(_weightCtrl.text),
      needsHandling: _needsHandling,
      needsTransportInsurance: _needsInsurance,
      basePrice: base,
      handlingFee: handling,
      insuranceFee: insurance,
      regionId: auth.profile?.regionId,
    );

    if (!mounted) return;
    if (request != null) {
      context.pushReplacement('/home/public/tracking/${request.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(transport.errorMessage ?? 'Erreur'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final transport = context.watch<TransportProvider>();
    final theme     = Theme.of(context);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final t = _transporter;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle demande')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── TRANSPORTEUR SÉLECTIONNÉ ─────────────────────────────
          if (t != null) _TransporterSummary(transporter: t),
          const SizedBox(height: 20),

          // ── TRAJET ────────────────────────────────────────────────
          Text('📍 Trajet', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AppTextField(
            controller: _pickupCtrl,
            label: 'Point de départ',
            prefixIcon: Icons.radio_button_checked,
            onChanged: (_) => _calculateEstimate(),
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _dropoffCtrl,
            label: 'Destination *',
            prefixIcon: Icons.location_on_outlined,
            onChanged: (_) => _calculateEstimate(),
          ),
          const SizedBox(height: 20),

          // ── CARGAISON ────────────────────────────────────────────
          Text('📦 Cargaison', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AppTextField(controller: _cargoCtrl, label: 'Description (optionnel)',
            prefixIcon: Icons.inventory_2_outlined, maxLines: 2),
          const SizedBox(height: 10),
          AppTextField(controller: _weightCtrl, label: 'Poids estimé (kg)',
            prefixIcon: Icons.fitness_center_outlined, keyboardType: TextInputType.number,
            onChanged: (_) => _calculateEstimate()),
          const SizedBox(height: 20),

          // ── OPTIONS ───────────────────────────────────────────────
          Text('⚙️ Options', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          if (t?.offersHandling == true)
            _OptionToggle(
              icon: Icons.people_outline, color: AppColors.info,
              title: 'Manutention', subtitle: 'Chargement / déchargement inclus',
              extra: '+${t!.handlingFeeRate.toStringAsFixed(0)}% du prix',
              value: _needsHandling,
              onToggle: (v) { setState(() => _needsHandling = v); _calculateEstimate(); },
            ),

          if (t?.offersTransportInsurance == true)
            _OptionToggle(
              icon: Icons.security_outlined, color: AppColors.success,
              title: 'Assurance transport', subtitle: 'Couvre vos marchandises',
              extra: '+${t!.insuranceRatePercent.toStringAsFixed(1)}% du prix',
              value: _needsInsurance,
              onToggle: (v) { setState(() => _needsInsurance = v); _calculateEstimate(); },
            ),

          const SizedBox(height: 20),

          // ── ESTIMATION PRIX ───────────────────────────────────────
          if (_estimatedPrice != null) _PriceEstimate(
            distance: _estimatedDistance,
            basePrice: _estimatedPrice!,
            handlingFee: _handlingFee,
            insuranceFee: _insuranceFee,
            currency: 'DA',
          ),

          const SizedBox(height: 24),

          // ── BOUTON ENVOYER ────────────────────────────────────────
          AppButton(
            label: 'Envoyer la demande',
            icon: Icons.send_outlined,
            isLoading: transport.isLoading,
            onPressed: _submit,
          ),

          const SizedBox(height: 8),
          const Center(
            child: Text('Le transporteur sera notifié immédiatement',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          ),
        ],
      ),
    );
  }
}

class _TransporterSummary extends StatelessWidget {
  final TransporterModel transporter;
  const _TransporterSummary({required this.transporter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(transporter.vehiclePhotoUrl,
              width: 70, height: 55, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 70, height: 55,
                color: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.local_shipping, color: AppColors.primary))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transporter.profile?.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(transporter.vehicleType, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                Row(
                  children: [
                    const Icon(Icons.star, size: 13, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text(transporter.averageRating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${transporter.basePricePerKm?.toStringAsFixed(0) ?? "?"} DA/km',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionToggle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, extra;
  final bool value;
  final ValueChanged<bool> onToggle;

  const _OptionToggle({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.extra, required this.value, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.08) : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? color : Colors.grey, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: value ? color : null)),
                Row(children: [
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  const SizedBox(width: 8),
                  Text(extra, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onToggle, activeColor: color),
        ],
      ),
    );
  }
}

class _PriceEstimate extends StatelessWidget {
  final double? distance;
  final double basePrice;
  final double? handlingFee, insuranceFee;
  final String currency;

  const _PriceEstimate({
    this.distance, required this.basePrice, this.handlingFee, this.insuranceFee, required this.currency,
  });

  double get _total => basePrice + (handlingFee ?? 0) + (insuranceFee ?? 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💰 Estimation du prix', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          if (distance != null) _PriceRow(label: 'Distance estimée', value: '${distance!.toStringAsFixed(1)} km'),
          _PriceRow(label: 'Transport', value: '${basePrice.toStringAsFixed(0)} $currency'),
          if ((handlingFee ?? 0) > 0)
            _PriceRow(label: 'Manutention', value: '+${handlingFee!.toStringAsFixed(0)} $currency'),
          if ((insuranceFee ?? 0) > 0)
            _PriceRow(label: 'Assurance', value: '+${insuranceFee!.toStringAsFixed(0)} $currency'),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total estimé', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text('${_total.toStringAsFixed(0)} $currency',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('* Prix indicatif — paiement en boutique physique',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TRANSPORTER REQUEST SCREEN
// ════════════════════════════════════════════════════════════════
// lib/presentation/screens/transporter/transporter_request_screen.dart
class TransporterRequestScreen extends StatefulWidget {
  final String requestId;
  const TransporterRequestScreen({super.key, required this.requestId});
  @override State<TransporterRequestScreen> createState() => _TransporterRequestScreenState();
}

class _TransporterRequestScreenState extends State<TransporterRequestScreen> {
  TransportRequestModel? _request;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.instance.client
          .from('transport_requests').select().eq('id', widget.requestId).single();
      if (mounted) setState(() { _request = TransportRequestModel.fromJson(data); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final r = _request;
    if (r == null) return const Scaffold(body: Center(child: Text('Demande introuvable')));

    final transport = context.watch<TransportProvider>();
    final active    = transport.activeRequest ?? r;
    final theme     = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Course en cours')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // Statut
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: active.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active.statusColor.withOpacity(0.4)),
            ),
            child: Column(children: [
              Text(active.statusLabel,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: active.statusColor)),
              const SizedBox(height: 4),
              RequestStatusStepper(currentStatus: active.status),
            ]),
          ),
          const SizedBox(height: 20),

          // Carte tracking
          TrackingMap(
            pickupPoint: LatLng(active.pickupLat, active.pickupLng),
            dropoffPoint: LatLng(active.dropoffLat, active.dropoffLng),
            transporterPosition: transport.transporterPos,
            trackingHistory: transport.trackingPoints,
            height: 260,
          ),
          const SizedBox(height: 20),

          // Infos trajet
          _InfoCard(
            icon: Icons.radio_button_checked, color: AppColors.success,
            label: 'Départ', value: active.pickupAddress ?? '${active.pickupLat.toStringAsFixed(4)}, ${active.pickupLng.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 8),
          _InfoCard(
            icon: Icons.location_on, color: AppColors.error,
            label: 'Arrivée', value: active.dropoffAddress ?? '${active.dropoffLat.toStringAsFixed(4)}, ${active.dropoffLng.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 8),

          if (active.cargoDescription != null)
            _InfoCard(icon: Icons.inventory_2_outlined, color: AppColors.info,
              label: 'Cargaison', value: active.cargoDescription!),
          const SizedBox(height: 8),

          // Prix
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total course', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                    Text('${active.totalPrice?.toStringAsFixed(0) ?? "?"} ${active.currency}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.primary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Votre part', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                    Text('${active.transporterNetAmount?.toStringAsFixed(0) ?? "?"} ${active.currency}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.success)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions selon statut
          if (active.status == RequestStatus.accepted) ...[
            AppButton(
              label: '🚀 Démarrer le transport',
              color: AppColors.success,
              isLoading: transport.isLoading,
              onPressed: () async {
                final auth       = context.read<AuthProvider>();
                final transProv  = context.read<TransporterProvider>();
                await transport.startTransport(
                  requestId: active.id,
                  transporterId: transProv.transporter!.id,
                  clientId: active.clientId,
                  intervalSeconds: transProv.transporter!.locationIntervalSeconds,
                );
                setState(() {});
              },
            ),
          ],

          if (active.status == RequestStatus.inProgress) ...[
            AppButton(
              label: '✅ Marquer comme livré',
              color: AppColors.success,
              isLoading: transport.isLoading,
              onPressed: () async {
                await transport.completeTransport(
                  requestId: active.id,
                  clientId: active.clientId,
                );
                if (mounted) context.pop();
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Annuler',
              color: AppColors.error,
              outlined: true,
              onPressed: () async {
                await transport.cancelRequest(
                  requestId: active.id,
                  reason: 'Annulé par le transporteur',
                  otherPartyProfileId: active.clientId,
                );
                if (mounted) context.pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _InfoCard({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

