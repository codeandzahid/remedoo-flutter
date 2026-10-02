import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

class _Slide {
  final String emoji;
  final String bgEmoji;
  final String title;
  final String text;
  final LinearGradient gradient;

  const _Slide({
    required this.emoji,
    required this.bgEmoji,
    required this.title,
    required this.text,
    required this.gradient,
  });
}

LinearGradient _g(Color c) => LinearGradient(
      colors: [c, c.withValues(alpha: 0.75)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

final _slides = [
  _Slide(
    emoji: '📅',
    bgEmoji: '🩺',
    title: 'Book Appointments',
    text:
        'Easily schedule visits with doctors, hospitals, labs, and pharmacies — all in one place.',
    gradient: _g(RemedooTheme.primary),
  ),
  _Slide(
    emoji: '🚨',
    bgEmoji: '🚑',
    title: 'Emergency SOS',
    text:
        'One tap to send your location and dispatch the nearest ambulance instantly.',
    gradient: _g(RemedooTheme.emergency),
  ),
  _Slide(
    emoji: '📍',
    bgEmoji: '🗺️',
    title: 'Live Tracking',
    text: 'Real-time GPS tracking of your ambulance with live ETA updates.',
    gradient: _g(RemedooTheme.success),
  ),
  _Slide(
    emoji: '🔒',
    bgEmoji: '🛡️',
    title: 'Secure & Private',
    text:
        'Your medical data is encrypted and protected. HIPAA-compliant security for peace of mind.',
    gradient: _g(RemedooTheme.warning),
  ),
];

/// 4-slide onboarding carousel (React Onboarding.tsx copy + styling).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _finish() {
    AppStateScope.of(context).markOnboardingSeen();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: MaxWidthBox(
          maxWidth: 480,
          child: Column(
            children: [
              // Skip link.
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Illustration tile with floating bg emoji accents.
                          SizedBox(
                            width: 170,
                            height: 170,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Opacity(
                                    opacity: 0.25,
                                    child: Text(s.bgEmoji,
                                        style: const TextStyle(
                                            fontSize: 40)),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: Opacity(
                                    opacity: 0.2,
                                    child: Text(s.bgEmoji,
                                        style: const TextStyle(
                                            fontSize: 32)),
                                  ),
                                ),
                                Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    gradient: s.gradient,
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: s.gradient.colors.first
                                            .withValues(alpha: 0.35),
                                        blurRadius: 28,
                                        offset: const Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    s.emoji,
                                    style: const TextStyle(fontSize: 60),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            s.title,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.text,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Dot indicators (active = long orange pill).
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? RemedooTheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // CTA — orange pill; green gradient on the final slide.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: last
                    ? _GreenPillButton(
                        label: 'Get Started',
                        onPressed: _finish,
                      )
                    : RButton(
                        label: 'Continue',
                        icon: Icons.chevron_right,
                        fullWidth: true,
                        onPressed: () => _ctrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green gradient pill (React's "Get Started" final CTA).
class _GreenPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GreenPillButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  RemedooTheme.success,
                  RemedooTheme.success.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: RemedooTheme.success.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
