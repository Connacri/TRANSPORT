// lib/presentation/screens/transporter/transporter_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class TransporterSetupScreen extends StatefulWidget {
  const TransporterSetupScreen({super.key});
  @override State<TransporterSetupScreen> createState() => _TransporterSetupScreenState();
}

class _TransporterSetupScreenState extends State<TransporterSetupScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _pageCtrl      = PageController();
  int   _currentPage   = 0;
  final int _totalPages = 3;

  // Page 1 — Véhicule
  final _typeCtrl    = TextEditingController();
  final _brandCtrl   = TextEditingController();
  final _modelCtrl   = TextEditingController();
  final _yearCtrl    = TextEditingController();
  final _plateCtrl   = TextEditingController();
  final _capKgCtrl   = TextEditingController();
  final _capM3Ctrl   = TextEditingController();
  String? _selectedVehicleType;

  // Page 2 — Services & Tarifs
  bool   _offersHandling   = false;
  double _handlingRate     = 15;
  bool   _offersInsurance  = false;
  double _insuranceRate    = 3;
  final _priceKmCtrl   = TextEditingController();
  final _minPriceCtrl  = TextEditingController();

  // Page 3 — Documents
  XFile? _vehiclePhoto;
  XFile? _facePhoto;
  XFile? _licensePhoto;
  XFile? _registrationPhoto;
  XFile? _insurancePhoto;
  XFile? _technicalPhoto;

  final _picker = ImagePicker();

  static const _vehicleTypes = [
    'Camion', 'Semi-remorque', 'Camionnette', 'Fourgon',
    'Pick-up', 'Moto-cargo', 'Voiture', 'Tracteur agricole',
  ];

  @override
  void dispose() {
    _typeCtrl.dispose(); _brandCtrl.dispose(); _modelCtrl.dispose();
    _yearCtrl.dispose(); _plateCtrl.dispose(); _capKgCtrl.dispose();
    _capM3Ctrl.dispose(); _priceKmCtrl.dispose(); _minPriceCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String field) async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() {
      switch (field) {
        case 'vehicle':      _vehiclePhoto      = file; break;
        case 'face':         _facePhoto         = file; break;
        case 'license':      _licensePhoto      = file; break;
        case 'registration': _registrationPhoto = file; break;
        case 'insurance':    _insurancePhoto    = file; break;
        case 'technical':    _technicalPhoto    = file; break;
      }
    });
  }

  void _nextPage() {
    if (_currentPage == 0 && !_validatePage1()) return;
    if (_currentPage == 1 && !_validatePage2()) return;
    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage++);
    } else {
      _submit();
    }
  }

  bool _validatePage1() {
    if (_selectedVehicleType == null) {
      _showSnack('Sélectionnez le type de véhicule');
      return false;
    }
    if (_plateCtrl.text.isEmpty) {
      _showSnack('La plaque d\'immatriculation est requise');
      return false;
    }
    return true;
  }

  bool _validatePage2() {
    if (_priceKmCtrl.text.isEmpty) {
      _showSnack('Renseignez votre tarif au kilomètre');
      return false;
    }
    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  Future<void> _submit() async {
    if (_vehiclePhoto == null) {
      _showSnack('La photo du véhicule est obligatoire');
      return;
    }
    final auth      = context.read<AuthProvider>();
    final transProv = context.read<TransporterProvider>();

    final ok = await transProv.createTransporterProfile(
      profileId: auth.profile!.id,
      vehicleType: _selectedVehicleType!,
      vehicleBrand: _brandCtrl.text.isEmpty ? null : _brandCtrl.text,
      vehicleModel: _modelCtrl.text.isEmpty ? null : _modelCtrl.text,
      vehicleYear: int.tryParse(_yearCtrl.text),
      vehiclePlate: _plateCtrl.text,
      capacityKg: double.tryParse(_capKgCtrl.text),
      capacityM3: double.tryParse(_capM3Ctrl.text),
      vehiclePhoto: _vehiclePhoto!,
      facePhoto: _facePhoto,
      licensePhoto: _licensePhoto,
      registrationPhoto: _registrationPhoto,
      insurancePhoto: _insurancePhoto,
      technicalControlPhoto: _technicalPhoto,
      offersHandling: _offersHandling,
      handlingFeeRate: _handlingRate,
      offersInsurance: _offersInsurance,
      insuranceRate: _insuranceRate,
      basePricePerKm: double.tryParse(_priceKmCtrl.text),
      minimumPrice: double.tryParse(_minPriceCtrl.text),
      regionId: auth.profile?.regionId,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profil créé ! En attente de validation admin.'), backgroundColor: AppColors.success),
      );
      context.go('/home/transporter');
    } else {
      _showSnack(transProv.error ?? 'Erreur lors de la création du profil');
    }
  }

  @override
  Widget build(BuildContext context) {
    final transProv = context.watch<TransporterProvider>();
    final theme     = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil transporteur'),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  setState(() => _currentPage--);
                },
              )
            : null,
      ),
      body: Column(
        children: [
          // Stepper progress
          _SetupStepper(current: _currentPage, total: _totalPages),

          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Page1Vehicle(
                  selectedType: _selectedVehicleType,
                  vehicleTypes: _vehicleTypes,
                  onTypeChanged: (v) => setState(() => _selectedVehicleType = v),
                  brandCtrl: _brandCtrl,
                  modelCtrl: _modelCtrl,
                  yearCtrl: _yearCtrl,
                  plateCtrl: _plateCtrl,
                  capKgCtrl: _capKgCtrl,
                  capM3Ctrl: _capM3Ctrl,
                ),
                _Page2Services(
                  offersHandling: _offersHandling,
                  onHandlingToggle: (v) => setState(() => _offersHandling = v),
                  handlingRate: _handlingRate,
                  onHandlingRateChanged: (v) => setState(() => _handlingRate = v),
                  offersInsurance: _offersInsurance,
                  onInsuranceToggle: (v) => setState(() => _offersInsurance = v),
                  insuranceRate: _insuranceRate,
                  onInsuranceRateChanged: (v) => setState(() => _insuranceRate = v),
                  priceKmCtrl: _priceKmCtrl,
                  minPriceCtrl: _minPriceCtrl,
                ),
                _Page3Documents(
                  vehiclePhoto: _vehiclePhoto,
                  facePhoto: _facePhoto,
                  licensePhoto: _licensePhoto,
                  registrationPhoto: _registrationPhoto,
                  insurancePhoto: _insurancePhoto,
                  technicalPhoto: _technicalPhoto,
                  onPick: _pickImage,
                ),
              ],
            ),
          ),

          // Bouton suivant/soumettre
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppButton(
              label: _currentPage < _totalPages - 1 ? 'Suivant' : 'Soumettre pour validation',
              icon: _currentPage < _totalPages - 1 ? Icons.arrow_forward : Icons.send_outlined,
              isLoading: transProv.isLoading,
              onPressed: _nextPage,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── STEPPER ──────────────────────────────────────────────────────
class _SetupStepper extends StatelessWidget {
  final int current, total;
  const _SetupStepper({required this.current, required this.total});

  static const _labels = ['Véhicule', 'Services', 'Documents'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: List.generate(total * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(child: Container(height: 2,
              color: i ~/ 2 < current ? AppColors.primary : Colors.grey.withOpacity(0.3)));
          }
          final idx     = i ~/ 2;
          final isDone  = idx < current;
          final isCurr  = idx == current;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isDone || isCurr ? AppColors.primary : Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text('${idx + 1}', style: TextStyle(
                          color: isCurr ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 4),
              Text(_labels[idx], style: TextStyle(
                fontSize: 10,
                color: isCurr ? AppColors.primary : Colors.grey,
                fontWeight: isCurr ? FontWeight.w700 : FontWeight.w400,
              )),
            ],
          );
        }),
      ),
    );
  }
}

// ─── PAGE 1 : VÉHICULE ───────────────────────────────────────────
class _Page1Vehicle extends StatelessWidget {
  final String? selectedType;
  final List<String> vehicleTypes;
  final ValueChanged<String?> onTypeChanged;
  final TextEditingController brandCtrl, modelCtrl, yearCtrl, plateCtrl, capKgCtrl, capM3Ctrl;

  const _Page1Vehicle({
    required this.selectedType, required this.vehicleTypes, required this.onTypeChanged,
    required this.brandCtrl, required this.modelCtrl, required this.yearCtrl,
    required this.plateCtrl, required this.capKgCtrl, required this.capM3Ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(title: '🚛 Votre véhicule', subtitle: 'Renseignez les informations de votre véhicule de transport'),
          const SizedBox(height: 20),

          // Type de véhicule
          Text('Type de véhicule *', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: vehicleTypes.map((t) {
              final sel = selectedType == t;
              return ChoiceChip(
                label: Text(t),
                selected: sel,
                selectedColor: AppColors.primary.withOpacity(0.15),
                side: BorderSide(color: sel ? AppColors.primary : Colors.grey.withOpacity(0.3)),
                labelStyle: TextStyle(color: sel ? AppColors.primary : null, fontWeight: sel ? FontWeight.w600 : null),
                onSelected: (_) => onTypeChanged(t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: AppTextField(controller: brandCtrl, label: 'Marque', prefixIcon: Icons.branding_watermark_outlined)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: modelCtrl, label: 'Modèle', prefixIcon: Icons.directions_car_outlined)),
          ]),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: AppTextField(controller: yearCtrl, label: 'Année', prefixIcon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: plateCtrl, label: 'Immatriculation *', prefixIcon: Icons.badge_outlined,
              validator: (v) => (v?.isEmpty ?? true) ? 'Requis' : null)),
          ]),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: AppTextField(controller: capKgCtrl, label: 'Capacité (kg)', prefixIcon: Icons.fitness_center_outlined,
              keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: capM3Ctrl, label: 'Capacité (m³)', prefixIcon: Icons.view_in_ar_outlined,
              keyboardType: TextInputType.number)),
          ]),
        ],
      ),
    );
  }
}

// ─── PAGE 2 : SERVICES ────────────────────────────────────────────
class _Page2Services extends StatelessWidget {
  final bool offersHandling;
  final ValueChanged<bool> onHandlingToggle;
  final double handlingRate;
  final ValueChanged<double> onHandlingRateChanged;
  final bool offersInsurance;
  final ValueChanged<bool> onInsuranceToggle;
  final double insuranceRate;
  final ValueChanged<double> onInsuranceRateChanged;
  final TextEditingController priceKmCtrl, minPriceCtrl;

  const _Page2Services({
    required this.offersHandling, required this.onHandlingToggle,
    required this.handlingRate, required this.onHandlingRateChanged,
    required this.offersInsurance, required this.onInsuranceToggle,
    required this.insuranceRate, required this.onInsuranceRateChanged,
    required this.priceKmCtrl, required this.minPriceCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(title: '⚙️ Vos services', subtitle: 'Définissez vos tarifs et services proposés'),
          const SizedBox(height: 20),

          // Tarification
          Text('Tarification *', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: AppTextField(controller: priceKmCtrl, label: 'Prix / km (DA) *',
              prefixIcon: Icons.payments_outlined, keyboardType: TextInputType.number,
              validator: (v) => (v?.isEmpty ?? true) ? 'Requis' : null)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: minPriceCtrl, label: 'Prix minimum (DA)',
              prefixIcon: Icons.money_outlined, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 20),

          // Manutention
          _ServiceToggleCard(
            icon: Icons.people_outline,
            title: 'Manutention',
            subtitle: 'Proposer le déchargement/chargement',
            value: offersHandling,
            onToggle: onHandlingToggle,
            color: AppColors.info,
            child: offersHandling ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('Frais manutention : ${handlingRate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: handlingRate, min: 5, max: 50, divisions: 45,
                  activeColor: AppColors.info,
                  label: '${handlingRate.toStringAsFixed(0)}%',
                  onChanged: onHandlingRateChanged,
                ),
              ],
            ) : null,
          ),
          const SizedBox(height: 12),

          // Assurance
          _ServiceToggleCard(
            icon: Icons.security_outlined,
            title: 'Assurance transport',
            subtitle: 'Couvrir les marchandises transportées',
            value: offersInsurance,
            onToggle: onInsuranceToggle,
            color: AppColors.success,
            child: offersInsurance ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('Taux assurance : ${insuranceRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: insuranceRate, min: 0.5, max: 10, divisions: 19,
                  activeColor: AppColors.success,
                  label: '${insuranceRate.toStringAsFixed(1)}%',
                  onChanged: onInsuranceRateChanged,
                ),
              ],
            ) : null,
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Ces taux sont indicatifs. L\'admin peut les modifier depuis le dashboard.',
                    style: TextStyle(fontSize: 12, color: AppColors.info)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceToggleCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onToggle;
  final Color color;
  final Widget? child;

  const _ServiceToggleCard({
    required this.icon, required this.title, required this.subtitle,
    required this.value, required this.onToggle, required this.color, this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.08) : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: value ? color : Colors.grey, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: value ? color : null)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  ],
                ),
              ),
              Switch.adaptive(value: value, onChanged: onToggle, activeColor: color),
            ],
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

// ─── PAGE 3 : DOCUMENTS ───────────────────────────────────────────
class _Page3Documents extends StatelessWidget {
  final XFile? vehiclePhoto, facePhoto, licensePhoto, registrationPhoto, insurancePhoto, technicalPhoto;
  final void Function(String) onPick;

  const _Page3Documents({
    required this.vehiclePhoto, required this.facePhoto,
    required this.licensePhoto, required this.registrationPhoto,
    required this.insurancePhoto, required this.technicalPhoto,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(title: '📄 Documents', subtitle: 'Plus vous ajoutez de documents, plus votre score de validation est élevé'),
          const SizedBox(height: 20),

          _DocUploadTile(label: 'Photo du véhicule *', icon: Icons.local_shipping_outlined,
            file: vehiclePhoto, field: 'vehicle', onPick: onPick, required: true, scorePoints: 20),
          _DocUploadTile(label: 'Photo de visage', icon: Icons.face_outlined,
            file: facePhoto, field: 'face', onPick: onPick, scorePoints: 10),
          _DocUploadTile(label: 'Permis de conduire', icon: Icons.credit_card_outlined,
            file: licensePhoto, field: 'license', onPick: onPick, scorePoints: 20),
          _DocUploadTile(label: 'Carte grise', icon: Icons.description_outlined,
            file: registrationPhoto, field: 'registration', onPick: onPick, scorePoints: 20),
          _DocUploadTile(label: 'Assurance véhicule', icon: Icons.security_outlined,
            file: insurancePhoto, field: 'insurance', onPick: onPick, scorePoints: 20),
          _DocUploadTile(label: 'Contrôle technique', icon: Icons.engineering_outlined,
            file: technicalPhoto, field: 'technical', onPick: onPick, scorePoints: 10),

          const SizedBox(height: 12),
          _ScorePreview(
            vehicle: vehiclePhoto, face: facePhoto, license: licensePhoto,
            registration: registrationPhoto, insurance: insurancePhoto, technical: technicalPhoto,
          ),
        ],
      ),
    );
  }
}

class _DocUploadTile extends StatelessWidget {
  final String label, field;
  final IconData icon;
  final XFile? file;
  final void Function(String) onPick;
  final bool required;
  final int scorePoints;

  const _DocUploadTile({
    required this.label, required this.icon, required this.file,
    required this.field, required this.onPick,
    this.required = false, this.scorePoints = 0,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = file != null;
    return GestureDetector(
      onTap: () => onPick(field),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: uploaded ? AppColors.success.withOpacity(0.08) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: uploaded ? AppColors.success.withOpacity(0.5)
                : this.required ? AppColors.error.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(uploaded ? Icons.check_circle : icon,
              color: uploaded ? AppColors.success : (this.required ? AppColors.error : Colors.grey),
              size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: uploaded ? AppColors.success : null,
                      )),
                      if (this.required)
                        const Text(' *', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                  Text(uploaded ? '✅ Photo ajoutée' : 'Appuyez pour téléverser',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (uploaded ? AppColors.success : AppColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('+$scorePoints%',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: uploaded ? AppColors.success : AppColors.primary,
                )),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePreview extends StatelessWidget {
  final XFile? vehicle, face, license, registration, insurance, technical;
  const _ScorePreview({this.vehicle, this.face, this.license, this.registration, this.insurance, this.technical});

  int get _score {
    int s = 0;
    if (vehicle != null)      s += 20;
    if (face != null)         s += 10;
    if (license != null)      s += 20;
    if (registration != null) s += 20;
    if (insurance != null)    s += 20;
    if (technical != null)    s += 10;
    return s;
  }

  Color get _color => _score >= 80 ? AppColors.success : _score >= 50 ? AppColors.warning : AppColors.error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text('$_score%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _color)),
              Text('Score', style: TextStyle(color: _color, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_score >= 80 ? '🏆 Excellent profil !' : _score >= 50 ? '👍 Bon profil' : '⚠️ Profil incomplet',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _color)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _score / 100,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(_color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PAGE HEADER ─────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final String title, subtitle;
  const _PageHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
      ],
    );
  }
}
