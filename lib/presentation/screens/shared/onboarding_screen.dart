// lib/presentation/screens/shared/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page   = 0;

  static const _slides = [
    _Slide(
      emoji: '🚛',
      title: 'Trouvez le bon transporteur',
      subtitle: 'Camion, fourgon, semi-remorque… Trouvez le véhicule adapté à votre cargaison, disponible près de vous en temps réel.',
      color: AppColors.primary,
    ),
    _Slide(
      emoji: '📍',
      title: 'Suivi en temps réel',
      subtitle: 'Suivez votre colis sur la carte comme avec Uber. Soyez alerté à chaque étape de votre transport.',
      color: Color(0xFF2196F3),
    ),
    _Slide(
      emoji: '🏪',
      title: 'Marketplace intégrée',
      subtitle: 'Achetez et vendez des services ou articles. Tout en un seul endroit.',
      color: AppColors.success,
    ),
    _Slide(
      emoji: '💼',
      title: 'Devenez superviseur',
      subtitle: 'Parrainez des transporteurs, gérez votre réseau et touchez des commissions sur chaque transport.',
      color: Color(0xFF9C27B0),
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/login');
  }

  @override
  void initState() {
    super.initState();
    _checkDone();
  }

  Future<void> _checkDone() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('onboarding_done') == true && mounted) {
      context.go('/login');
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _slides.length,
            itemBuilder: (_, i) => _SlidePage(slide: _slides[i], size: size),
          ),

          // Skip
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: TextButton(
              onPressed: _finish,
              child: const Text('Passer', style: TextStyle(color: Colors.white70)),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40, left: 24, right: 24,
            child: Column(
              children: [
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
                const SizedBox(height: 24),

                // Bouton
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _page < _slides.length - 1
                        ? () => _ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                        : _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _slides[_page].color,
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: Text(
                      _page < _slides.length - 1 ? 'Suivant' : 'Commencer',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
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

class _Slide {
  final String emoji, title, subtitle;
  final Color color;
  const _Slide({required this.emoji, required this.title, required this.subtitle, required this.color});
}

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  final Size size;
  const _SlidePage({required this.slide, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slide.color, slide.color.withOpacity(0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Text(slide.emoji, style: const TextStyle(fontSize: 90)),
              const SizedBox(height: 40),
              Text(slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 16),
              Text(slide.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
