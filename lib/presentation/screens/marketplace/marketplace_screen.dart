// lib/presentation/screens/marketplace/marketplace_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';
import '../../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedType; // 'product' | 'service' | null
  final _searchCtrl = TextEditingController();
  bool _showSearch  = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadListings(refresh: true);
    _scrollCtrl.addListener(_onScroll);
  }

  Future<void> _loadCategories() async {
    final res = await SupabaseService.instance.client
        .from('marketplace_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    if (mounted) setState(() => _categories = List<Map<String, dynamic>>.from(res as List));
  }

  void _loadListings({bool refresh = false}) {
    final auth = context.read<AuthProvider>();
    context.read<MarketplaceProvider>().loadListings(
      categoryId: _selectedCategoryId,
      regionId: auth.profile?.regionId,
      refresh: refresh,
    );
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadListings();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceProvider>();
    final auth   = context.watch<AuthProvider>();
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _selectedType == null
        ? market.listings
        : market.listings.where((l) => l.type.name == _selectedType).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher...', border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Marketplace'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search_outlined),
            onPressed: () => setState(() { _showSearch = !_showSearch; _searchCtrl.clear(); }),
          ),
          IconButton(
            icon: const Icon(Icons.add_outlined),
            onPressed: () => context.push('/marketplace/create'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<MarketplaceProvider>().loadListings(refresh: true),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [

            // ── BANNIÈRE HERO ──────────────────────────────────────
            SliverToBoxAdapter(child: _HeroBanner(onSell: () => context.push('/marketplace/create'))),

            // ── FILTRES TYPE ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _TypeChip(label: 'Tout', selected: _selectedType == null,
                      onTap: () { setState(() => _selectedType = null); _loadListings(refresh: true); }),
                    const SizedBox(width: 8),
                    _TypeChip(label: '🛍️ Articles', selected: _selectedType == 'product',
                      onTap: () { setState(() => _selectedType = 'product'); _loadListings(refresh: true); }),
                    const SizedBox(width: 8),
                    _TypeChip(label: '🔧 Services', selected: _selectedType == 'service',
                      onTap: () { setState(() => _selectedType = 'service'); _loadListings(refresh: true); }),
                  ],
                ),
              ),
            ),

            // ── CATÉGORIES ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _CategoryItem(
                        icon: '🏠', label: 'Tout',
                        selected: _selectedCategoryId == null,
                        color: AppColors.primary,
                        onTap: () { setState(() => _selectedCategoryId = null); _loadListings(refresh: true); },
                      );
                    }
                    final cat   = _categories[i - 1];
                    final selId = cat['id'] as String;
                    return _CategoryItem(
                      icon: _catEmoji(cat['name'] as String? ?? ''),
                      label: cat['name'] as String? ?? '',
                      selected: _selectedCategoryId == selId,
                      color: Color(int.parse('0xFF${(cat['color_hex'] as String? ?? '#FF6B35').replaceAll('#', '')}')),
                      onTap: () { setState(() => _selectedCategoryId = selId); _loadListings(refresh: true); },
                    );
                  },
                ),
              ),
            ),

            // ── RÉSULTATS ──────────────────────────────────────────
            if (market.isLoading && filtered.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const _ShimmerCard(),
                    childCount: 6,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75,
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      const Text('Aucune annonce', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 6),
                      const Text('Soyez le premier à publier !', style: TextStyle(color: AppColors.textSecondaryLight)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Publier une annonce'),
                        onPressed: () => context.push('/marketplace/create'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (i == filtered.length) {
                        return market.hasMore
                            ? const Center(child: CircularProgressIndicator())
                            : const SizedBox.shrink();
                      }
                      final listing = filtered[i];
                      if (_showSearch && _searchCtrl.text.isNotEmpty &&
                          !listing.title.toLowerCase().contains(_searchCtrl.text.toLowerCase())) {
                        return const SizedBox.shrink();
                      }
                      return _ListingCard(
                        listing: listing,
                        onTap: () => context.push('/marketplace/listing/${listing.id}'),
                      );
                    },
                    childCount: filtered.length + (market.hasMore ? 1 : 0),
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _catEmoji(String name) {
    if (name.contains('Transport'))   return '🚛';
    if (name.contains('BTP'))         return '🏗️';
    if (name.contains('Alimentation'))return '🌾';
    if (name.contains('Tech'))        return '💻';
    if (name.contains('Meubles'))     return '🛋️';
    if (name.contains('Véhicules'))   return '🚗';
    if (name.contains('Service'))     return '💼';
    return '📦';
  }
}

// ─── HERO BANNER ─────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final VoidCallback onSell;
  const _HeroBanner({required this.onSell});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, Color(0xFF16213E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Achetez & Vendez', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Articles, services, tout y est.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onSell,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Publier une annonce', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const Text('🛍️', style: TextStyle(fontSize: 56)),
        ],
      ),
    );
  }
}

// ─── TYPE CHIP ────────────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondaryLight,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          fontSize: 13,
        )),
      ),
    );
  }
}

// ─── CATEGORY ITEM ────────────────────────────────────────────────
class _CategoryItem extends StatelessWidget {
  final String icon, label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _CategoryItem({required this.icon, required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        margin: const EdgeInsets.only(right: 8, bottom: 6, top: 4),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? color : AppColors.textSecondaryLight)),
          ],
        ),
      ),
    );
  }
}

// ─── LISTING CARD ─────────────────────────────────────────────────
class _ListingCard extends StatelessWidget {
  final MarketplaceListingModel listing;
  final VoidCallback onTap;
  const _ListingCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: listing.isPremium ? Border.all(color: AppColors.premiumGold, width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: listing.imagesUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: listing.imagesUrls.first,
                            width: double.infinity, fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: AppColors.primary.withOpacity(0.08),
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                            errorWidget: (_, __, ___) => _Placeholder(type: listing.type),
                          )
                        : _Placeholder(type: listing.type),
                  ),
                  // Badges
                  Positioned(top: 8, left: 8, child: Row(children: [
                    if (listing.isPremium) _Badge(label: '⭐', color: AppColors.premiumGold),
                    if (listing.isVerified) const SizedBox(width: 4),
                    if (listing.isVerified) _Badge(label: '✓', color: AppColors.success),
                  ])),
                  Positioned(top: 8, right: 8,
                    child: _Badge(
                      label: listing.type == ListingType.product ? '🛍️' : '🔧',
                      color: listing.type == ListingType.product ? AppColors.info : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),

            // Infos
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(listing.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (listing.city != null)
                          Text(listing.city!, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        if (listing.price != null)
                          Text(
                            listing.isPriceNegotiable
                                ? '${NumberFormat('#,###').format(listing.price)} ${listing.currency} (négociable)'
                                : '${NumberFormat('#,###').format(listing.price)} ${listing.currency}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          )
                        else
                          const Text('Prix à convenir', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ListingType type;
  const _Placeholder({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary.withOpacity(0.08),
      child: Center(child: Text(type == ListingType.product ? '📦' : '🔧', style: const TextStyle(fontSize: 40))),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── SHIMMER CARD ─────────────────────────────────────────────────
class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.withOpacity(0.15),
      highlightColor: Colors.grey.withOpacity(0.05),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
