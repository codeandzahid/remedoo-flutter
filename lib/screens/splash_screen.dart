import 'package:flutter/material.dart';

import '../theme.dart';

/// Orange splash: row of medical emoji + small white loading bar.
/// Auto-advance is handled by RootGate (main.dart) — timing unchanged.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  static const _icons = ['💊', '🩺', '🏥', '❤️', '💉', '🧬', '🧪'];

  late final AnimationController _bar;

  @override
  void initState() {
    super.initState();
    _bar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            BoxDecoration(gradient: RemedooTheme.headerGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Centered row of medical emoji icons.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in _icons)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        e,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              // Small white loading bar.
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.3),
                    child: AnimatedBuilder(
                      animation: _bar,
                      builder: (_, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _bar.value.clamp(0.0, 1.0),
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
