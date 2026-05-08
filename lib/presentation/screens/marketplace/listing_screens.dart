// lib/presentation/screens/marketplace/listing_detail_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';
import '../../../main.dart';
import '../../providers/auth_provider.dart';
// Imports
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
// import '../../providers/providers.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});
  @override State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  MarketplaceListingModel? _listing;
  bool _loading = true;
  int  _imgIdx  = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await SupabaseService.instance.client
          .from('marketplace_listings')
          .update({'views_count': SupabaseService.instance.client.rpc('increment_views')})
          .eq('id', widget.listingId);
    } catch (_) {}

    try {
      final data = await SupabaseService.instance.client
          .from('marketplace_listings')
          .select('*, profiles(*)')
          .eq('id', widget.listingId)
          .single();
      if (mounted) setState(() { _listing = MarketplaceListingModel.fromJson(data); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_listing == null) return const Scaffold(body: Center(child: Text('Annonce introuvable')));

    final l     = _listing!;
    final auth  = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isOwner = l.sellerId == auth.profile?.id;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── APP BAR + IMAGES ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              if (isOwner) IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
              IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: l.imagesUrls.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          itemCount: l.imagesUrls.length,
                          onPageChanged: (i) => setState(() => _imgIdx = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
                            imageUrl: l.imagesUrls[i], fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: AppColors.primary.withValues(alpha: 0.08)),
                          ),
                        ),
                        if (l.imagesUrls.length > 1)
                          Positioned(
                            bottom: 12, left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(l.imagesUrls.length, (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _imgIdx == i ? 18 : 6, height: 6,
                                decoration: BoxDecoration(
                                  color: _imgIdx == i ? Colors.white : Colors.white54,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              )),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      child: Center(child: Text(l.type == ListingType.product ? '📦' : '🔧',
                        style: const TextStyle(fontSize: 80))),
                    ),
            ),
          ),

          // ── CONTENU ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Badges
                  Row(
                    children: [
                      _TypeBadge(type: l.type),
                      if (l.isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.premiumGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star, size: 12, color: AppColors.premiumGold),
                            SizedBox(width: 4),
                            Text('Premium', style: TextStyle(color: AppColors.premiumGold, fontWeight: FontWeight.w700, fontSize: 11)),
                          ]),
                        ),
                      ],
                      if (l.isVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.verified, color: AppColors.success, size: 18),
                      ],
                      const Spacer(),
                      Row(children: [
                        const Icon(Icons.remove_red_eye_outlined, size: 14, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Text('${l.viewsCount} vues', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Titre + prix
                  Text(l.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (l.price != null)
                    Text(
                      '${NumberFormat('#,###').format(l.price)} ${l.currency}${l.isPriceNegotiable ? ' (négociable)' : ''}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
                    )
                  else
                    const Text('Prix à convenir', style: TextStyle(fontSize: 18, color: AppColors.textSecondaryLight)),

                  if (l.city != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text(l.city!, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                    ]),
                  ],
                  const SizedBox(height: 20),

                  // Description
                  if (l.description != null && l.description!.isNotEmpty) ...[
                    const Text('📋 Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(l.description!, style: const TextStyle(height: 1.6, fontSize: 14)),
                    const SizedBox(height: 20),
                  ],

                  // Vendeur
                  const Text('👤 Vendeur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  _SellerCard(seller: l.seller),
                  const SizedBox(height: 20),

                  // Date
                  Text('Publié le ${DateFormat('dd/MM/yyyy').format(l.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── BOTTOM BAR CONTACT ─────────────────────────────────────
      bottomNavigationBar: isOwner ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (l.seller?.phone != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Appeler'),
                    onPressed: () => launchUrl(Uri.parse('tel:${l.seller!.phone}')),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Contacter'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fonctionnalité chat disponible en V2')));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ListingType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isProduct = type == ListingType.product;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isProduct ? AppColors.info : AppColors.warning).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isProduct ? '🛍️ Article' : '🔧 Service',
        style: TextStyle(color: isProduct ? AppColors.info : AppColors.warning, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final ProfileModel? seller;
  const _SellerCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage: seller?.avatarUrl != null ? NetworkImage(seller!.avatarUrl!) : null,
            child: seller?.avatarUrl == null
                ? Text(seller?.displayName.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 18))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seller?.displayName ?? 'Vendeur', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (seller?.phone != null)
                  Text(seller!.phone!, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (seller?.roleColor ?? AppColors.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(seller?.roleLabel ?? '', style: TextStyle(
                    fontSize: 11, color: seller?.roleColor ?? AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CREATE LISTING SCREEN
// ════════════════════════════════════════════════════════════════
// lib/presentation/screens/marketplace/create_listing_screen.dart
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});
  @override State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _cityCtrl   = TextEditingController();

  ListingType _type     = ListingType.product;
  bool  _negotiable     = false;
  String? _categoryId;
  List<Map<String, dynamic>> _categories = [];
  List<XFile> _images = [];
  bool _loading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final res = await SupabaseService.instance.client
        .from('marketplace_categories').select().eq('is_active', true).order('sort_order');
    if (mounted) setState(() => _categories = List<Map<String, dynamic>>.from(res as List));
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() => _images = [..._images, ...picked].take(8).toList());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final sm = ScaffoldMessenger.of(context);
    final nav = context.pop;

    if (_images.isEmpty) {
      sm.showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une photo'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final marketplace = context.read<MarketplaceProvider>();

    try {
      // Upload images
      final urls = <String>[];
      for (int i = 0; i < _images.length; i++) {
        final bytes = await _images[i].readAsBytes();
        final url = await SupabaseService.instance.uploadFile(
          bucket: AppConstants.bucketListings,
          path: '${auth.profile!.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          bytes: bytes,
        );
        urls.add(url);
      }

      final ok = await marketplace.createListing(
        sellerId: auth.profile!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoryId: _categoryId,
        type: _type,
        price: double.tryParse(_priceCtrl.text.replaceAll(',', '.')),
        isPriceNegotiable: _negotiable,
        imagesUrls: urls,
        regionId: auth.profile?.regionId,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      );

      if (ok) {
        sm.showSnackBar(
          const SnackBar(content: Text('✅ Annonce publiée !'), backgroundColor: AppColors.success));
        nav();
      }
    } catch (e) {
      sm.showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _priceCtrl.dispose(); _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publier une annonce')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── TYPE ──────────────────────────────────────────────
            const _SectionLabel('Type d\'annonce'),
            Row(
              children: [
                Expanded(child: _TypeToggle(
                  label: '🛍️ Article', selected: _type == ListingType.product,
                  onTap: () => setState(() => _type = ListingType.product),
                )),
                const SizedBox(width: 12),
                Expanded(child: _TypeToggle(
                  label: '🔧 Service', selected: _type == ListingType.service,
                  onTap: () => setState(() => _type = ListingType.service),
                )),
              ],
            ),
            const SizedBox(height: 20),

            // ── PHOTOS ────────────────────────────────────────────
            const _SectionLabel('Photos * (max 8)'),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 90, height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
                          SizedBox(height: 4),
                          Text('Ajouter', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  ..._images.asMap().entries.map((e) => Stack(
                    children: [
                      Container(
                        width: 90, height: 90,
                        margin: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(e.value.path, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.withValues(alpha: 0.2))),
                        ),
                      ),
                      Positioned(top: 4, right: 14,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(e.key)),
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── TITRE ─────────────────────────────────────────────
            const _SectionLabel('Titre *'),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Ex: Camion Mercedes 14 tonnes...'),
              validator: (v) => (v?.isEmpty ?? true) ? 'Titre requis' : null,
            ),
            const SizedBox(height: 14),

            // ── CATÉGORIE ─────────────────────────────────────────
            const _SectionLabel('Catégorie'),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(hintText: 'Sélectionnez une catégorie'),
              items: _categories.map((c) => DropdownMenuItem<String>(
                value: c['id'] as String,
                child: Text(c['name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 14),

            // ── DESCRIPTION ───────────────────────────────────────
            const _SectionLabel('Description'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Décrivez votre article ou service en détail...'),
            ),
            const SizedBox(height: 14),

            // ── PRIX ──────────────────────────────────────────────
            const _SectionLabel('Prix (DA)'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _negotiable,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _negotiable = v ?? false),
                    ),
                    const Text('Négociable', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── VILLE ─────────────────────────────────────────────
            const _SectionLabel('Ville'),
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(hintText: 'Ex: Alger, Oran...', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 30),

            // ── COMMISSION INFO ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('Une commission de 5% sera prélevée lors de chaque vente.',
                    style: TextStyle(fontSize: 12, color: AppColors.info))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Publier l\'annonce'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : Colors.grey.withValues(alpha: 0.25), width: selected ? 1.5 : 1),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.primary : null,
            fontSize: 14,
          )),
        ),
      ),
    );
  }
}
