// lib/presentation/screens/shared/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
// Imports
import '../../providers/auth_provider.dart';
import '../../providers/transport_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProv = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifProv.unreadCount > 0)
            TextButton(
              onPressed: () => notifProv.markAllRead(),
              child: const Text('Tout lire', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: notifProv.notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 72, color: Color(0xFFCCCCCC)),
                  SizedBox(height: 16),
                  Text('Aucune notification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('Vous êtes à jour !', style: TextStyle(color: AppColors.textSecondaryLight)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifProv.notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
              itemBuilder: (_, i) {
                final n = notifProv.notifications[i];
                return _NotifTile(
                  notif: n,
                  onTap: () async {
                    await notifProv.markRead(n.id);
                    _navigate(context, n);
                  },
                );
              },
            ),
    );
  }

  void _navigate(BuildContext context, NotificationModel n) {
    final type = n.type ?? '';
    final data = n.data;
    if (type.contains('request') || type.contains('transport')) {
      final id = data['request_id'] as String?;
      if (id != null) context.push('/home/public/tracking/$id');
    }
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  IconData get _icon {
    final t = notif.type ?? '';
    if (t.contains('accepted'))   return Icons.check_circle_outline;
    if (t.contains('completed'))  return Icons.flag_outlined;
    if (t.contains('cancelled'))  return Icons.cancel_outlined;
    if (t.contains('started'))    return Icons.local_shipping_outlined;
    if (t.contains('validated'))  return Icons.verified_outlined;
    if (t.contains('rejected'))   return Icons.block_outlined;
    if (t.contains('new_request'))return Icons.notifications_active_outlined;
    return Icons.notifications_outlined;
  }

  Color get _iconColor {
    final t = notif.type ?? '';
    if (t.contains('accepted') || t.contains('completed') || t.contains('validated')) return AppColors.success;
    if (t.contains('cancelled') || t.contains('rejected'))  return AppColors.error;
    if (t.contains('started'))   return AppColors.primary;
    if (t.contains('new_request')) return AppColors.warning;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: notif.isRead ? null : _iconColor.withValues(alpha: 0.05),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notif.title,
                          style: TextStyle(
                            fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(width: 8, height: 8,
                          decoration: BoxDecoration(color: _iconColor, shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notif.body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notif.createdAt),
                    style: TextStyle(fontSize: 11, color: _iconColor.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'À l\'instant';
    if (diff.inHours < 1)    return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1)     return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7)     return 'Il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}

// ════════════════════════════════════════════════════════════════
// HISTORY SCREEN
// ════════════════════════════════════════════════════════════════
// lib/presentation/screens/public/history_screen.dart
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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

    final completed = transport.requestHistory.where((r) => r.status == RequestStatus.completed).toList();
    final other     = transport.requestHistory.where((r) => r.status != RequestStatus.completed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: [
            Tab(text: 'Terminés (${completed.length})'),
            Tab(text: 'Autres (${other.length})'),
          ],
        ),
      ),
      body: transport.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _RequestList(requests: completed),
                _RequestList(requests: other),
              ],
            ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<TransportRequestModel> requests;
  const _RequestList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 64, color: Color(0xFFCCCCCC)),
            SizedBox(height: 16),
            Text('Aucun trajet ici', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (_, i) => _RequestHistoryCard(request: requests[i]),
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  final TransportRequestModel request;
  const _RequestHistoryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: request.statusColor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut + date
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
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(request.requestedAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Trajet
            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.radio_button_checked, color: AppColors.success, size: 14),
                    Container(width: 1.5, height: 30, color: Colors.grey.withValues(alpha: 0.3)),
                    const Icon(Icons.location_on, color: AppColors.error, size: 14),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.pickupAddress ?? 'Départ', style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 14),
                      Text(request.dropoffAddress ?? 'Arrivée', style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Infos bas
            Row(
              children: [
                if (request.estimatedDistanceKm != null) ...[
                  const Icon(Icons.straighten, size: 13, color: AppColors.textSecondaryLight),
                  const SizedBox(width: 4),
                  Text('${request.estimatedDistanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  const SizedBox(width: 12),
                ],
                if (request.needsHandling)
                  const _MiniChip(label: 'Manutention', color: AppColors.info),
                if (request.needsTransportInsurance)
                  const _MiniChip(label: 'Assurance', color: AppColors.success),
                const Spacer(),
                if (request.totalPrice != null)
                  Text('${request.totalPrice!.toStringAsFixed(0)} ${request.currency}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
              ],
            ),

            // Bouton suivre si en cours
            if (request.status == RequestStatus.inProgress || request.status == RequestStatus.accepted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Suivre en direct'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
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

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}



