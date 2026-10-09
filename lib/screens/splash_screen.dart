import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/flip_themes.dart';
import 'menu_screen.dart';
import 'ui_kit.dart';

/// Single launch splash: game logo + name, animated loading line, credits.
/// Pre-warms audio and starts menu music while showing.
class SplashScreen extends StatefulWidget {
  final FlipAudio audio;
  final FlipSettings settings;
  final FlipStore store;
  const SplashScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    widget.store.init(); // fire-and-forget; pro screen reads it later
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = flipThemeById(widget.settings.themeId,
        custom: widget.settings.customTheme);
    return Scaffold(
      body: Container(
        decoration: FlipUi.backdrop(t),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      offset: const Offset(0, 12),
                      blurRadius: 28,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/flipbottle_logo.png',
                    fit: BoxFit.cover),
              ),
              const SizedBox(height: 22),
              Text('Flip Bottle', style: FlipUi.display(46, t)),
              const SizedBox(height: 6),
              Text('ONE FLICK. ONE PERFECT LANDING.',
                  style: FlipUi.label(13, t)),
              const SizedBox(height: 30),
              SizedBox(
                width: 220,
                child: AnimatedBuilder(
                  animation: _loader,
                  builder: (_, _) => Column(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.black.withValues(alpha: 0.18),
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.5)),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _loader.value.clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: t.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _loader.value < 1
                            ? 'Filling the bottles…'
                            : 'Ready!',
                        style: FlipUi.body(13, t,
                            color: t.text.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 44),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/wajiha_logo.png',
                      width: 30, height: 30, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Text('Credits: WAJIHA', style: FlipUi.label(14, t)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
