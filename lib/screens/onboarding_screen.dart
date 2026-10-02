import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String text;

  const _Slide(this.icon, this.title, this.text);
}

const _slides = [
  _Slide(
    Icons.calendar_month,
    'Book Appointments',
    'Schedule visits with doctors, hospitals, labs and pharmacies — all in one place.',
  ),
  _Slide(
    Icons.sos,
    'Emergency SOS',
    'One tap shares your location and dispatches the nearest ambulance to you.',
  ),
  _Slide(
    Icons.location_on,
    'Live Tracking',
    'Follow your ambulance in real time with live GPS tracking and accurate ETAs.',
  ),
  _Slide(
    Icons.lock,
    'Secure & Private',
    'Your health data stays encrypted and private. Only you control who sees it.',
  ),
];

/// 4-slide onboarding carousel.
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
    return Scaffold(
      body: SafeArea(
        child: MaxWidthBox(
          maxWidth: 480,
          child: Column(
            children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip',
                    style: TextStyle(color: RemedooTheme.primary)),
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
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            gradient: RemedooTheme.headerGradient,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: RemedooTheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(s.icon,
                              size: 72, color: Colors.white),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          s.title,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.text,
                          style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? RemedooTheme.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FilledButton(
                onPressed: () {
                  if (last) {
                    _finish();
                  } else {
                    _ctrl.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(last ? 'Get Started' : 'Continue'),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
