// lib/presentation/screens/public/public_home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/tracking_service.dart';
import '../../providers/transport_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class PublicHomeScreen extends StatefulWidget {
  const PublicHomeScreen({super.key});
  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Position? _myPosition;
  String? _selectedVehicleType;
  bool _showMap = true;
  final MapController _mapCtrl = MapController();
  double _searchRadius = 50.0;
  final _vehicleTypes = [
    'Tous',
    'Camion',
    'Camionnette',
    'Fourgon',
    'Moto',
    'Voiture',
    'Semi-remorque'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _init();
  }

  // Remplacer la méthode _init() par :
  Future<void> _init() async {
    final pos = await TrackingService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _myPosition = pos);

      // ✅ FIX : centrer la carte sur la position du user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showMap) {
          _mapCtrl.move(
            LatLng(pos.latitude, pos.longitude),
            14.0, // zoom plus précis pour la ville
          );
        }
      });

      _loadTransporters(pos.latitude, pos.longitude);
    }
  }

  void _loadTransporters(double lat, double lng) {
    context.read<TransportProvider>().loadNearbyTransporters(
          lat: lat,
          lng: lng,
          radius: _searchRadius,
          vehicleType:
              (_selectedVehicleType == 'Tous' || _selectedVehicleType == null)
                  ? null
                  : _selectedVehicleType,
        );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transport = context.watch<TransportProvider>();
    final notifProv = context.watch<NotificationProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            expandedHeight: 0,
            title: Row(
              children: [
                const Icon(Icons.local_shipping_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                const Text('Cargoza',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                // Notifications
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => context.push('/notifications'),
                    ),
                    if (notifProv.unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: AppColors.error, shape: BoxShape.circle),
                          child: Center(
                            child: Text('${notifProv.unreadCount}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => context.push('/profile'),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Column(
                children: [
                  // Barre de recherche
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: GestureDetector(
                      onTap: () {/* TODO: Search screen */},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardDark
                              : const Color(0xFFF1F3F4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: AppColors.textSecondaryLight),
                            const SizedBox(width: 12),
                            const Text('Destination...',
                                style: TextStyle(
                                    color: AppColors.textSecondaryLight)),
                            const Spacer(),
                            if (_myPosition != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.my_location,
                                        size: 13, color: AppColors.primary),
                                    SizedBox(width: 4),
                                    Text('Ma position',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Filtre types véhicule
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _vehicleTypes.length,
                      itemBuilder: (_, i) {
                        final vt = _vehicleTypes[i];
                        final isSelected =
                            (_selectedVehicleType ?? 'Tous') == vt;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedVehicleType = vt);
                            if (_myPosition != null) {
                              _loadTransporters(_myPosition!.latitude,
                                  _myPosition!.longitude);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.cardDark
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color:
                                          Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(vt,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight),
                                  )),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Toggle Carte / Liste
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${transport.nearbyTransporters.length} transporteur(s) à proximité',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondaryLight),
                  ),
                  const Spacer(),
                  _ToggleView(
                    showMap: _showMap,
                    onToggle: (v) => setState(() => _showMap = v),
                  ),
                  // Dans le body, après le ToggleView :
                  if (transport.state == TransportProviderState.error)
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off,
                              color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Impossible de charger les transporteurs',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.error),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (_myPosition != null) {
                                _loadTransporters(_myPosition!.latitude,
                                    _myPosition!.longitude);
                              }
                            },
                            child: const Text('Réessayer',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: _showMap
                  ? _MapView(
                      transporters: transport.nearbyTransporters,
                      myPosition: _myPosition,
                      mapCtrl: _mapCtrl,
                      onTransporterTap: (t) =>
                          context.push('/home/public/transporter/${t.id}'),
                      onRadiusChanged: (newRadius) {
                        setState(() => _searchRadius = newRadius);
                        if (_myPosition != null) {
                          _loadTransporters(
                              _myPosition!.latitude, _myPosition!.longitude);
                        }
                      },
                      onReloadTransporters: () {
                        if (_myPosition != null) {
                          _loadTransporters(
                              _myPosition!.latitude, _myPosition!.longitude);
                        }
                      },
                    )
                  : _ListView(
                      transporters: transport.nearbyTransporters,
                      isLoading: transport.isLoading,
                      onTap: (t) =>
                          context.push('/home/public/transporter/${t.id}'),
                      onRefresh: _init,
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _BottomNav(currentIndex: 0),
    );
  }
}

// ─── VUE CARTE ───────────────────────────────────────────────────
class _MapView extends StatelessWidget {
  final List<TransporterModel> transporters;
  final Position? myPosition;
  final MapController mapCtrl;
  final void Function(TransporterModel) onTransporterTap;
  final void Function(double) onRadiusChanged;
  final VoidCallback onReloadTransporters;

  const _MapView(
      {required this.transporters,
      this.myPosition,
      required this.mapCtrl,
      required this.onTransporterTap,
      required this.onRadiusChanged,
      required this.onReloadTransporters});

  @override
  Widget build(BuildContext context) {
    final center = myPosition != null
        ? LatLng(myPosition!.latitude, myPosition!.longitude)
        : const LatLng(36.7372, 3.0870);

    return Stack(
      children: [
        FlutterMap(
          mapController: mapCtrl,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) {
                // Adapter le radius au zoom
                // zoom 14 ≈ 5km, zoom 12 ≈ 20km, zoom 10 ≈ 80km
                final newRadius =
                    (1000 * (1 << (20 - camera.zoom.round())) / 1000)
                        .clamp(5.0, 100.0);
                onRadiusChanged(newRadius.toDouble());
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.trasnport.dz.trasport',
              tileProvider: CancellableNetworkTileProvider(),
            ),
            MarkerLayer(
              markers: [
                // Ma position
                if (myPosition != null)
                  Marker(
                    point: LatLng(myPosition!.latitude, myPosition!.longitude),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.info.withValues(alpha: 0.4),
                              blurRadius: 8)
                        ],
                      ),
                    ),
                  ),

                // Transporteurs
                ...transporters.where((t) => t.currentLat != null).map((t) =>
                    Marker(
                      point: LatLng(t.currentLat!, t.currentLng!),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => onTransporterTap(t),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: t.isPremium
                                    ? AppColors.premiumGold
                                    : AppColors.primary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: (t.isPremium
                                            ? AppColors.premiumGold
                                            : AppColors.primary)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.local_shipping,
                                  color: Colors.white, size: 22),
                            ),
                            if (t.badge != null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: t.badgeColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white)),
                                  child: const Icon(Icons.verified,
                                      size: 10, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ],
        ),

        // Bouton recentrer
        // Dans _MapView.build(), dans le Stack, avant le FAB :
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${transporters.length} disponible(s)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Remplacer le FAB actuel par :
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'refresh_transporters',
                backgroundColor: AppColors.primary,
                onPressed: () {
                  if (myPosition != null) {
                    mapCtrl.move(
                        LatLng(myPosition!.latitude, myPosition!.longitude),
                        14);
                    onReloadTransporters(); // callback → _loadTransporters()
                  }
                },
                child: const Icon(Icons.refresh, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'my_location',
                backgroundColor: Colors.white,
                onPressed: () {
                  if (myPosition != null) {
                    mapCtrl.move(
                        LatLng(myPosition!.latitude, myPosition!.longitude),
                        14);
                  }
                },
                child: const Icon(Icons.my_location,
                    color: AppColors.primary, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── VUE LISTE ────────────────────────────────────────────────────
class _ListView extends StatelessWidget {
  final List<TransporterModel> transporters;
  final bool isLoading;
  final void Function(TransporterModel) onTap;
  final Future<void> Function() onRefresh;
  const _ListView(
      {required this.transporters,
      required this.isLoading,
      required this.onTap,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (transporters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 64, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Aucun transporteur disponible',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Réessayez dans quelques instants',
                style: TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        // callback depuis le parent
        await onRefresh();
      },
      child: ListView.builder(
        itemCount: transporters.length,
        itemBuilder: (_, i) => TransporterCard(
          transporter: transporters[i],
          onTap: () => onTap(transporters[i]),
        ),
      ),
    );
  }
}

// ─── BOTTOM NAV (CLIENT) ─────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        switch (i) {
          case 0:
            context.go('/home/public');
            break;
          case 1:
            context.go('/home/public/history');
            break;
          case 2:
            context.go('/marketplace');
            break;
          case 3:
            context.go('/profile');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil'),
        BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Historique'),
        BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'Marché'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil'),
      ],
    );
  }
}

// ─── TOGGLE VUE ───────────────────────────────────────────────────
class _ToggleView extends StatelessWidget {
  final bool showMap;
  final void Function(bool) onToggle;
  const _ToggleView({required this.showMap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _Btn(
              icon: Icons.map_outlined,
              isActive: showMap,
              onTap: () => onToggle(true)),
          _Btn(
              icon: Icons.list_outlined,
              isActive: !showMap,
              onTap: () => onToggle(false)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child:
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey),
      ),
    );
  }
}
