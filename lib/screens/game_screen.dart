import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/flip_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/flip_themes.dart';
import 'ui_kit.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.flipbottle';

/// Game screen: renders the FlipEngine. The engine owns ALL state; this
/// widget renders phases, plays sounds on engine events, and adds juice
/// (particles, squash, slosh, banners). No silent scoring — every flip
/// resolves with a visible banner + points popup + sound.
class GameScreen extends StatefulWidget {
  final FlipAudio audio;
  final FlipSettings settings;
  final FlipStore store;
  final FlipDifficulty difficulty;
  final GameMode mode;
  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
    required this.difficulty,
    required this.mode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _Particle {
  Offset pos;
  Offset vel;
  double life; // 0..1
  Color color;
  double size;
  _Particle(this.pos, this.vel, this.life, this.color, this.size);
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final FlipEngine engine;
  late final AnimationController _fx; // drives particles + slosh time
  final List<_Particle> _particles = [];
  final _rand = Random();

  FlipPhase _prevPhase = FlipPhase.idle;
  int _prevBanner = 0;
  int _prevLevel = 1;
  int _prevSecondsLeft = 60;
  DateTime? _resolveAt;
  bool _over = false;
  bool _newBest = false;
  bool _recorded = false;

  FlipThemeDef get t => flipThemeById(widget.settings.themeId,
      custom: widget.settings.customTheme);
  BottleStyle get bottle =>
      bottleStyles[widget.settings.bottleStyle.clamp(0, bottleStyles.length - 1)];
  TableStyle get table =>
      tableStyles[widget.settings.tableStyle.clamp(0, tableStyles.length - 1)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine = FlipEngine(difficulty: widget.difficulty, mode: widget.mode);
    engine.addListener(_onEngine);
    _fx = AnimationController(
        vsync: this, duration: const Duration(days: 1))
      ..addListener(_tickFx);
    _fx.forward();
    widget.audio.startGameMusic();
    engine.start();
    widget.audio.gameStart();
  }

  void _tickFx() {
    if (_particles.isEmpty) return;
    for (final p in _particles) {
      p.life -= 0.03;
      p.pos += p.vel;
      p.vel += const Offset(0, 0.9); // gravity in logical px/frame
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  void _onEngine() {
    if (!mounted) return;
    // --- sounds + juice on phase/result changes ---
    if (engine.phase != _prevPhase) {
      if (engine.phase == FlipPhase.charging && _prevPhase == FlipPhase.idle) {
        widget.audio.chargeStart();
      }
      if (engine.phase == FlipPhase.flying) {
        widget.audio.flip();
      }
      if (engine.phase == FlipPhase.gameOver && !_over) {
        _onGameOver();
      }
      _prevPhase = engine.phase;
    }
    final r = engine.lastResult;
    if (r != null && r.bannerSeq != _prevBanner) {
      _prevBanner = r.bannerSeq;
      _resolveAt = DateTime.now();
      _burst(r);
      switch (r.quality) {
        case LandQuality.perfect:
          widget.audio.perfect();
          break;
        case LandQuality.ok:
          widget.audio.landOk();
          break;
        case LandQuality.miss:
          widget.audio.landBad();
          break;
      }
    }
    if (engine.level != _prevLevel) {
      _prevLevel = engine.level;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LEVEL ${engine.level} — faster, tighter, longer!',
                style: FlipUi.body(14, t, color: Colors.white)),
            backgroundColor: t.accent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    if (engine.isScoreAttack && !_over) {
      final s = engine.timeLeft.ceil();
      if (s != _prevSecondsLeft) {
        _prevSecondsLeft = s;
        if (s <= 5 && s > 0) widget.audio.tick();
      }
    }
    setState(() {});
  }

  void _burst(FlipResult r) {
    // Spawn particles at the landing platform. Positions are logical 0..1;
    // the painter maps them to pixels — store logical here.
    final base = Offset(engine.targetX, 0.70);
    if (r.quality == LandQuality.perfect) {
      for (int i = 0; i < 26; i++) {
        final a = _rand.nextDouble() * 2 * pi;
        final sp = 0.004 + _rand.nextDouble() * 0.012;
        _particles.add(_Particle(
          base,
          Offset(cos(a) * sp, sin(a) * sp - 0.008),
          1,
          i % 3 == 0 ? t.accent : Colors.white,
          3 + _rand.nextDouble() * 4,
        ));
      }
    } else if (r.quality == LandQuality.ok) {
      for (int i = 0; i < 12; i++) {
        final a = -pi / 2 + (_rand.nextDouble() - 0.5) * 2;
        final sp = 0.004 + _rand.nextDouble() * 0.008;
        _particles.add(_Particle(
          base,
          Offset(cos(a) * sp, sin(a) * sp),
          1,
          t.water,
          2.5 + _rand.nextDouble() * 3,
        ));
      }
    } else {
      for (int i = 0; i < 18; i++) {
        final a = _rand.nextDouble() * 2 * pi;
        final sp = 0.005 + _rand.nextDouble() * 0.012;
        _particles.add(_Particle(
          base,
          Offset(cos(a) * sp, sin(a) * sp - 0.004),
          1,
          t.water.withValues(alpha: 0.9),
          3 + _rand.nextDouble() * 4,
        ));
      }
    }
  }

  Future<void> _onGameOver() async {
    _over = true;
    final s = widget.settings;
    _newBest = await s.recordRun(
      streak: engine.streak,
      score: engine.score,
      flips: engine.flips,
      perfects: engine.perfects,
      isScoreAttack: engine.isScoreAttack,
      isEndless: engine.mode == GameMode.endless,
    );
    if (_newBest) {
      widget.audio.win();
    } else {
      widget.audio.lose();
    }
    _recorded = true;
    // Sensible review moment: a real new best on a real run. Throttled to
    // once a day, and fully guarded — no-ops when not installed from Play.
    try {
      final bigRun = engine.isScoreAttack
          ? engine.score >= 200
          : engine.streak >= 8;
      if (_newBest && bigRun && await s.shouldPromptReview()) {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await s.markReviewPrompted();
          await review.requestReview();
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      engine.pauseEngine();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
      if (!_over) engine.resumeEngine();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    engine.removeListener(_onEngine);
    engine.dispose();
    _fx.dispose();
    widget.audio.startMenuMusic();
    super.dispose();
  }

  void _togglePause() {
    widget.audio.click();
    if (engine.isPaused) {
      engine.resumeEngine();
    } else {
      engine.pauseEngine();
    }
    setState(() {});
  }

  void _restart() {
    widget.audio.click();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
          difficulty: widget.difficulty,
          mode: widget.mode,
        ),
      ),
    );
  }

  void _shareScore() {
    widget.audio.click();
    final line = engine.isScoreAttack
        ? 'I scored ${engine.score} points'
        : 'I hit a ${engine.streak}-flip streak';
    Share.share(
        '$line in Flip Bottle! 🍾 Can you beat me? $_storeUrl');
  }

  @override
  Widget build(BuildContext context) {
    final theme = t;
    return Scaffold(
      body: Container(
        decoration: FlipUi.backdrop(theme),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _hud(theme),
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (_) => engine.pressDown(),
                      onTapUp: (_) => engine.release(),
                      onTapCancel: () => engine.cancelCharge(),
                      child: LayoutBuilder(builder: (ctx, box) {
                        return CustomPaint(
                          size: box.biggest,
                          painter: _FlipPainter(
                            theme: theme,
                            bottle: bottle,
                            table: table,
                            engine: engine,
                            particles: _particles,
                            fxTime: _fx.value,
                            resolveAt: _resolveAt,
                          ),
                        );
                      }),
                    ),
                  ),
                  _hintBar(theme),
                  const SizedBox(height: 10),
                ],
              ),
              if (engine.isPaused && !_over) _pauseOverlay(theme),
              if (_over && _recorded) _gameOverOverlay(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud(FlipThemeDef theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          FlipUi.iconButton(theme,
              icon: engine.isPaused ? Icons.play_arrow : Icons.pause,
              tooltip: 'Pause',
              onTap: _togglePause),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat(theme, '🔥 ${engine.streak}', 'STREAK'),
                const SizedBox(width: 10),
                _stat(theme, '${engine.score}', 'SCORE'),
                const SizedBox(width: 10),
                if (engine.isScoreAttack)
                  _stat(theme, '${engine.timeLeft.ceil()}s', 'TIME')
                else
                  _stat(theme,
                      '❤' * engine.livesLeft + '🖤' * (engine.maxLives - engine.livesLeft),
                      'LIVES'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Lv ${engine.level}',
                style: TextStyle(
                    color: theme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _stat(FlipThemeDef theme, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          Text(label,
              style: TextStyle(color: theme.muted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _hintBar(FlipThemeDef theme) {
    String text;
    if (_over) {
      text = 'Game over!';
    } else if (engine.isPaused) {
      text = 'Paused';
    } else {
      switch (engine.phase) {
        case FlipPhase.idle:
          text = 'Hold anywhere to charge…';
          break;
        case FlipPhase.charging:
          text = 'Release in a GREEN zone! 🟢';
          break;
        case FlipPhase.flying:
          text = 'Flying… 🍾';
          break;
        case FlipPhase.resolving:
        case FlipPhase.settling:
          final r = engine.lastResult;
          text = r == null
              ? ''
              : (r.quality == LandQuality.perfect
                  ? 'PERFECT! +${r.points} ⭐'
                  : r.quality == LandQuality.ok
                      ? 'Landed! +${r.points}'
                      : 'Missed! 💦');
          break;
        case FlipPhase.gameOver:
          text = 'Game over!';
          break;
      }
    }
    return Text(text,
        style: TextStyle(
            color: theme.text, fontWeight: FontWeight.bold, fontSize: 16));
  }

  Widget _pauseOverlay(FlipThemeDef theme) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: FlipUi.card(theme,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Paused', style: FlipUi.display(30, theme)),
                const SizedBox(height: 16),
                FlipUi.chunkyButton(
                    t: theme,
                    text: 'RESUME',
                    icon: Icons.play_arrow,
                    onTap: _togglePause),
                const SizedBox(height: 10),
                FlipUi.chunkyButton(
                    t: theme,
                    text: 'RESTART',
                    icon: Icons.refresh,
                    color: theme.muted,
                    onTap: _restart),
                const SizedBox(height: 10),
                FlipUi.chunkyButton(
                    t: theme,
                    text: 'QUIT',
                    icon: Icons.home,
                    color: theme.muted,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    }),
              ],
            )),
      ),
    );
  }

  Widget _gameOverOverlay(FlipThemeDef theme) {
    final headline = engine.isScoreAttack
        ? 'Score: ${engine.score}!'
        : 'Streak: ${engine.streak}! 🍾';
    final acc = engine.flips == 0
        ? 0
        : ((engine.flips - engine.misses) * 100 / engine.flips).round();
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: SingleChildScrollView(
          child: FlipUi.card(theme,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_newBest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('🏆 NEW BEST!',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                  const SizedBox(height: 8),
                  Text(headline, style: FlipUi.display(32, theme)),
                  const SizedBox(height: 8),
                  Text(
                      '${engine.flips} flips • ${engine.perfects} perfect • $acc% landed',
                      style: FlipUi.body(13, theme,
                          color: theme.muted)),
                  const SizedBox(height: 18),
                  FlipUi.chunkyButton(
                      t: theme,
                      text: 'FLIP AGAIN',
                      icon: Icons.refresh,
                      onTap: _restart),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FlipUi.chunkyButton(
                          t: theme,
                          text: 'SHARE',
                          icon: Icons.share,
                          fontSize: 15,
                          color: theme.muted,
                          onTap: _shareScore),
                      const SizedBox(width: 10),
                      FlipUi.chunkyButton(
                          t: theme,
                          text: 'MENU',
                          icon: Icons.home,
                          fontSize: 15,
                          color: theme.muted,
                          onTap: () {
                            widget.audio.click();
                            Navigator.of(context).pop();
                          }),
                    ],
                  ),
                ],
              )),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter: physical bottle, sloshing water, squash on landing, particles,
// power meter with sweet zones, platforms in the chosen table material.
// ---------------------------------------------------------------------------
class _FlipPainter extends CustomPainter {
  final FlipThemeDef theme;
  final BottleStyle bottle;
  final TableStyle table;
  final FlipEngine engine;
  final List<_Particle> particles;
  final double fxTime;
  final DateTime? resolveAt;

  _FlipPainter({
    required this.theme,
    required this.bottle,
    required this.table,
    required this.engine,
    required this.particles,
    required this.fxTime,
    required this.resolveAt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    final platY = H * 0.72;
    final bh = H * 0.17; // bottle height px

    // --- platforms (table material, soft shadow) ---
    _platform(canvas, W * engine.startX, platY, W * engine.platW, true);
    _platform(canvas, W * engine.targetX, platY, W * engine.platW, false);

    // --- bottle transform ---
    Offset pos;
    double rot; // radians
    double squash = 0;
    if (engine.phase == FlipPhase.flying) {
      final t = engine.flightT;
      final x0 = W * engine.startX;
      final x1 = W * engine.targetX;
      pos = Offset(
        x0 + (x1 - x0) * t,
        platY - bh * 0.55 - sin(t * pi) * H * engine.apex,
      );
      rot = engine.spinTotalDeg * t * pi / 180;
      // motion streaks
      _motionLines(canvas, pos, rot, bh);
    } else if (engine.phase == FlipPhase.resolving ||
        engine.phase == FlipPhase.settling) {
      pos = Offset(W * engine.targetX, platY - bh * 0.55);
      final r = engine.lastResult;
      final since =
          resolveAt == null ? 1.0 : DateTime.now().difference(resolveAt!).inMilliseconds / 650.0;
      final wobble = exp(-3.0 * since.clamp(0.0, 2.0));
      squash = (r?.quality == LandQuality.miss ? 0.10 : 0.22) * wobble;
      if (r == null || r.quality == LandQuality.miss) {
        // tipped over: fall to the side with a dying wobble
        final dir = (r?.finalAngleDeg ?? 90) > 180 ? -1.0 : 1.0;
        rot = dir * (pi / 2.15) * (1 - 0.12 * wobble * sin(since * 9));
        pos = Offset(pos.dx + dir * bh * 0.28, platY - bh * 0.30);
      } else {
        rot = 0.10 * wobble * sin(since * 12); // upright wobble
      }
    } else {
      // idle / charging / gameOver(rest): bottle waits on the start platform
      pos = Offset(W * engine.startX, platY - bh * 0.55);
      rot = engine.phase == FlipPhase.charging
          ? 0.04 * sin(fxTime * 40)
          : 0; // tremble while charging
    }

    _bottle(canvas, pos, rot, bh, squash);

    // --- particles (logical 0..1 -> px) ---
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.pos.dx * W, p.pos.dy * H),
        p.size * p.life.clamp(0.0, 1.0),
        Paint()..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0)),
      );
    }

    // --- power meter with sweet zones ---
    _meter(canvas, size);

    // --- result banner ---
    final r = engine.lastResult;
    if ((engine.phase == FlipPhase.resolving ||
            engine.phase == FlipPhase.settling) &&
        r != null) {
      _banner(canvas, size, r);
    }
  }

  void _platform(Canvas canvas, double cx, double y, double w, bool isStart) {
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + 4, y + 14), width: w, height: 18),
          const Radius.circular(9)),
      shadow,
    );
    // edge (thickness)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y + 10), width: w, height: 18),
          const Radius.circular(9)),
      Paint()..color = table.edge,
    );
    // top surface with highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y + 4), width: w, height: 14),
          const Radius.circular(7)),
      Paint()..color = table.top,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - w / 2 + 6, y - 2, cx + w / 2 - 6, y + 2),
          const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    if (!isStart) {
      // landing target ring
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, y + 4), width: w * 0.55, height: 10),
            const Radius.circular(5)),
        Paint()
          ..color = theme.accent.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _motionLines(Canvas canvas, Offset pos, double rot, double bh) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 3; i++) {
      final back = i * bh * 0.28;
      canvas.drawLine(
        Offset(pos.dx - back, pos.dy - bh * 0.1 * i),
        Offset(pos.dx - back - bh * 0.22, pos.dy - bh * 0.1 * i),
        p,
      );
    }
  }

  void _bottle(Canvas canvas, Offset c, double rot, double bh, double squash) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.scale(1 + squash * 0.7, 1 - squash); // squash & stretch on landing
    final bw = bh * 0.42;
    final bodyC = bottle.body;
    final dark = _darken(bodyC, 0.25);

    // shadow ellipse under bottle (drawn unrotated-ish: fake by counter-scale)
    // (skipped when flying high — painter draws it on the platform instead)
    final shape = bottle.shape;
    final radius = shape == 2 ? bw * 0.42 : bw * 0.30;

    // body
    final bodyRect = Rect.fromCenter(
        center: Offset(0, bh * 0.08), width: bw, height: bh * 0.72);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(radius)),
      Paint()..color = bodyC,
    );
    // side shading for roundness
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bodyRect.left, bodyRect.top, bw * 0.22,
              bodyRect.height),
          Radius.circular(radius)),
      Paint()..color = dark.withValues(alpha: 0.35),
    );
    // water: clipped inside body, surface tilted by slosh
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(bodyRect.deflate(bw * 0.10),
            Radius.circular(radius * 0.7)));
    final sloshTilt = -rot * 0.55 + 0.12 * sin(fxTime * 55);
    final waterTop = bodyRect.top + bodyRect.height * 0.38;
    canvas.save();
    canvas.translate(0, waterTop);
    canvas.rotate(sloshTilt.clamp(-0.5, 0.5));
    canvas.drawRect(
      Rect.fromLTWH(-bw, 0, bw * 3, bodyRect.height),
      Paint()..color = theme.water.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      Rect.fromLTWH(-bw, 0, bw * 3, 4),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.restore();
    canvas.restore();
    // glass shine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(
              bodyRect.left + bw * 0.16, bodyRect.top + 6, bw * 0.12,
              bodyRect.height - 12),
          const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    // neck + cap per shape
    final neckW = shape == 1 ? bw * 0.42 : bw * 0.34;
    final neckTop = bodyRect.top - bh * (shape == 3 ? 0.16 : 0.12);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(0, (bodyRect.top + neckTop) / 2),
          width: neckW,
          height: bodyRect.top - neckTop + 4),
      Paint()..color = _darken(bodyC, 0.12),
    );
    final capH = shape == 1 ? bh * 0.10 : bh * 0.07;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(0, neckTop - capH / 2 + 2),
              width: neckW + 8,
              height: capH),
          const Radius.circular(4)),
      Paint()..color = bottle.cap,
    );
    if (shape == 1) {
      // sport spout
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, neckTop - capH - 4),
                width: neckW * 0.5,
                height: 10),
            const Radius.circular(3)),
        Paint()..color = bottle.cap,
      );
    }
    canvas.restore();
  }

  Color _darken(Color c, double amt) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amt).clamp(0.0, 1.0)).toColor();
  }

  void _meter(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    final meterX = W - 52;
    final meterTop = H * 0.16;
    final meterH = H * 0.42;
    final charging =
        engine.phase == FlipPhase.charging || engine.phase == FlipPhase.flying;

    // track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(meterX, meterTop, 30, meterH),
          const Radius.circular(15)),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    // sweet zones: multiples of full turns land upright (0, 1/maxTurns, ...)
    final turns = flipTunings[engine.difficulty.index].maxTurns;
    final zoneH = 16.0;
    for (int k = 0; k <= turns.round(); k++) {
      final z = k / turns;
      final zy = meterTop + meterH * (1 - z);
      final perfect = k == 0 || k == turns.round();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(meterX + 15, zy), width: 30, height: zoneH),
            const Radius.circular(8)),
        Paint()
          ..color = (perfect ? const Color(0xFF66BB6A) : const Color(0xFFAED581))
              .withValues(alpha: 0.9),
      );
    }
    // needle
    if (charging) {
      final my = meterTop + meterH * (1 - engine.power);
      canvas.drawCircle(Offset(meterX + 15, my), 13,
          Paint()..color = theme.accent);
      canvas.drawCircle(
          Offset(meterX + 15, my),
          13,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    final label = TextPainter(
        text: TextSpan(
            text: 'POWER',
            style: TextStyle(
                color: theme.text.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)
      ..layout();
    label.paint(canvas, Offset(meterX - 2, meterTop - 20));
  }

  void _banner(Canvas canvas, Size size, FlipResult r) {
    final text = r.quality == LandQuality.perfect
        ? 'PERFECT! +${r.points} ⭐'
        : r.quality == LandQuality.ok
            ? 'NAILED IT! +${r.points}'
            : 'MISS! 💦';
    final color = r.quality == LandQuality.miss
        ? const Color(0xFFE53935)
        : const Color(0xFF2E7D32);
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                color: color,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      offset: const Offset(0, 2),
                      blurRadius: 6),
                ])),
        textDirection: TextDirection.ltr)
      ..layout();
    // pop-in scale by banner age
    tp.paint(canvas,
        Offset(size.width / 2 - tp.width / 2, size.height * 0.10));
  }

  @override
  bool shouldRepaint(covariant _FlipPainter old) => true;
}
