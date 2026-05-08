// lib/presentation/widgets/app_button.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// Imports regroupés
import '../../data/models/models.dart';


class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? color;
  final bool outlined;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    if (outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color ?? AppColors.primary, width: 1.5),
          foregroundColor: color ?? AppColors.primary,
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.primary,
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// APP TEXT FIELD
// ─────────────────────────────────────────────────────────────────
// lib/presentation/widgets/app_text_field.dart
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final String? hint;
  final bool enabled;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.hint,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TRANSPORTER CARD
// ─────────────────────────────────────────────────────────────────
// lib/presentation/widgets/transporter_card.dart
class TransporterCard extends StatelessWidget {
  final TransporterModel transporter;
  final VoidCallback? onTap;
  final bool showDistance;

  const TransporterCard({
    super.key,
    required this.transporter,
    this.onTap,
    this.showDistance = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: transporter.isPremium
              ? Border.all(color: AppColors.premiumGold, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // Photo véhicule
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      transporter.vehiclePhotoUrl,
                      width: 80, height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80, height: 70,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.local_shipping, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom + badges
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                transporter.profile?.displayName ?? 'Transporteur',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (transporter.isPremium) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.premiumGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 11, color: AppColors.premiumGold),
                                    SizedBox(width: 3),
                                    Text('Premium', style: TextStyle(fontSize: 10, color: AppColors.premiumGold, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                            if (transporter.badge != null) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified, size: 16, color: transporter.badgeColor),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Type véhicule
                        Text(
                          '${transporter.vehicleType}${transporter.vehicleBrand != null ? " • ${transporter.vehicleBrand}" : ""}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 6),

                        // Note + distance
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: AppColors.warning),
                            const SizedBox(width: 3),
                            Text(
                              transporter.averageRating.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              ' (${transporter.totalRatings})',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryLight),
                            ),
                            if (showDistance && transporter.distanceKm != null) ...[
                              const Spacer(),
                              const Icon(Icons.location_on, size: 13, color: AppColors.primary),
                              Text(
                                '${transporter.distanceKm!.toStringAsFixed(1)} km',
                                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Options + Prix
              Row(
                children: [
                  if (transporter.offersHandling)
                    const _ChipBadge(icon: Icons.people_outline, label: 'Manutention'),
                  if (transporter.offersHandling && transporter.offersTransportInsurance)
                    const SizedBox(width: 6),
                  if (transporter.offersTransportInsurance)
                    const _ChipBadge(icon: Icons.security_outlined, label: 'Assurance'),
                  const Spacer(),
                  if (transporter.basePricePerKm != null)
                    Text(
                      '${transporter.basePricePerKm!.toStringAsFixed(0)} DA/km',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ChipBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TRACKING MAP WIDGET (OSM + flutter_map)
// ─────────────────────────────────────────────────────────────────
// lib/presentation/widgets/tracking_map.dart


class TrackingMap extends StatefulWidget {
  final LatLng? pickupPoint;
  final LatLng? dropoffPoint;
  final LatLng? transporterPosition;
  final List<TrackingModel> trackingHistory;
  final bool isInteractive;
  final double height;

  const TrackingMap({
    super.key,
    this.pickupPoint,
    this.dropoffPoint,
    this.transporterPosition,
    this.trackingHistory = const [],
    this.isInteractive = true,
    this.height = 350,
  });

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Centrer sur position transporteur si elle change
    if (widget.transporterPosition != null &&
        widget.transporterPosition != oldWidget.transporterPosition) {
      _mapController.move(widget.transporterPosition!, 15);
    }
  }

  LatLng get _center {
    if (widget.transporterPosition != null) return widget.transporterPosition!;
    if (widget.pickupPoint != null) return widget.pickupPoint!;
    return const LatLng(36.7372, 3.0870);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 13,
            interactionOptions: InteractionOptions(
              flags: widget.isInteractive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            // ── Tuiles OSM ───────────────────────────────────────
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.transporthub.app',
            ),

            // ── Route parcourue ───────────────────────────────────
            if (widget.trackingHistory.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.trackingHistory
                        .map((t) => LatLng(t.lat, t.lng))
                        .toList(),
                    color: AppColors.primary,
                    strokeWidth: 4,
                  ),
                ],
              ),

            // ── Marqueurs ─────────────────────────────────────────
            MarkerLayer(
              markers: [
                // Point de départ
                if (widget.pickupPoint != null)
                  Marker(
                    point: widget.pickupPoint!,
                    width: 40, height: 40,
                    child: const _MapPin(color: AppColors.success, icon: Icons.radio_button_checked),
                  ),

                // Destination
                if (widget.dropoffPoint != null)
                  Marker(
                    point: widget.dropoffPoint!,
                    width: 40, height: 40,
                    child: const _MapPin(color: AppColors.error, icon: Icons.location_on),
                  ),

                // Position transporteur
                if (widget.transporterPosition != null)
                  Marker(
                    point: widget.transporterPosition!,
                    width: 52, height: 52,
                    child: _TransporterMarker(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _TransporterMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: const Icon(Icons.local_shipping, color: Colors.white, size: 28),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// STATUS STEP TRACKER
// ─────────────────────────────────────────────────────────────────
class RequestStatusStepper extends StatelessWidget {
  final RequestStatus currentStatus;

  const RequestStatusStepper({super.key, required this.currentStatus});

  static const _steps = [
    (status: RequestStatus.pending,    label: 'Demande envoyée', icon: Icons.send_outlined),
    (status: RequestStatus.accepted,   label: 'Transporteur trouvé', icon: Icons.check_circle_outline),
    (status: RequestStatus.inProgress, label: 'En cours', icon: Icons.local_shipping_outlined),
    (status: RequestStatus.completed,  label: 'Livré', icon: Icons.flag_outlined),
  ];

  int get _currentIndex => _steps.indexWhere((s) => s.status == currentStatus);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineIdx = i ~/ 2;
          final isCompleted = lineIdx < _currentIndex;
          return Expanded(
            child: Container(
              height: 3,
              color: isCompleted ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final step    = _steps[stepIdx];
        final isDone  = stepIdx < _currentIndex;
        final isCurr  = stepIdx == _currentIndex;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isDone || isCurr ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon, size: 18, color: isDone || isCurr ? Colors.white : Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(step.label, style: TextStyle(
              fontSize: 9,
              fontWeight: isCurr ? FontWeight.w700 : FontWeight.w400,
              color: isCurr ? AppColors.primary : AppColors.textSecondaryLight,
            ), textAlign: TextAlign.center),
          ],
        );
      }),
    );
  }
}


