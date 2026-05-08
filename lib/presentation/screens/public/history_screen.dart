// lib/presentation/screens/public/history_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transport_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.profile != null) {
        context.read<TransportProvider>().loadHistory(
          profileId: auth.profile!.id,
          role: auth.role,
        );
      }
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final transport = context.watch<TransportProvider>();
    final history   = transport.requestHistory;

    final completed = history.where((r) => r.status == RequestStatus.completed).toList();
    final active    = history.where((r) => [RequestStatus.pending, RequestStatus.accepted, RequestStatus.inProgress].contains(r.status)).toList();
    final cancelled = history.where((r) => r.status == RequestStatus.cancelled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          tabs: [
            Tab(text: 'En cours (${active.length})'),
            Tab(text: 'Terminés (${completed.length})'),
            Tab(text: 'Annulés (${cancelled.length})'),
          ],
        ),
      ),
      body: transport.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _RequestList(requests: active, emptyMsg: 'Aucune course active'),
                _RequestList(requests: completed, emptyMsg: 'Aucune course terminée'),
                _RequestList(requests: cancelled, emptyMsg: 'Aucune course annulée'),
              ],
            ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<TransportRequestModel> requests;
  final String emptyMsg;
  const _RequestList({required this.requests, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📭', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(emptyMsg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        if (auth.profile != null) {
          await context.read<TransportProvider>().loadHistory(
            profileId: auth.profile!.id, role: auth.role);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (_, i) => _HistoryCard(request: requests[i]),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final TransportRequestModel request;
  const _HistoryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: request.statusColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header : statut + date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: request.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(request.statusLabel,
                    style: TextStyle(color: request.statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const Spacer(),
                Text(DateFormat('dd/MM/yy HH:mm').format(request.requestedAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
              ],
            ),
            const SizedBox(height: 12),

            // Trajet
            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.radio_button_checked, color: AppColors.success, size: 13),
                    Container(width: 1, height: 22, color: Colors.grey.withValues(alpha: 0.3)),
                    const Icon(Icons.location_on, color: AppColors.error, size: 13),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.pickupAddress ?? 'Point de départ',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      Text(request.dropoffAddress ?? 'Destination',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Footer
            Row(
              children: [
                if (request.estimatedDistanceKm != null) ...[
                  const Icon(Icons.straighten, size: 13, color: AppColors.textSecondaryLight),
                  const SizedBox(width: 4),
                  Text('${request.estimatedDistanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  const SizedBox(width: 10),
                ],
                if (request.needsHandling)
                  const _MiniTag(label: '💪 Manutention'),
                if (request.needsTransportInsurance)
                  const _MiniTag(label: '🛡️ Assurance'),
                const Spacer(),
                if (request.totalPrice != null)
                  Text('${request.totalPrice!.toStringAsFixed(0)} DA',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
              ],
            ),

            // CTA selon statut
            if (request.status == RequestStatus.inProgress || request.status == RequestStatus.accepted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Suivre en direct'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => context.push('/home/public/tracking/${request.id}'),
                ),
              ),
            ],

            if (request.status == RequestStatus.completed && request.transporterNetAmount == null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Laisser un avis'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => context.push('/home/public/tracking/${request.id}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
    );
  }
}

