import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Flip Bottle — hold to charge, release to flip, land it upright.
class FlipBottleScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const FlipBottleScreen({super.key, required this.players, required this.callbacks});

  @override
  State<FlipBottleScreen> createState() => _FlipBottleScreenState();
}

class _FlipBottleScreenState extends State<FlipBottleScreen>
    with SingleTickerProviderStateMixin {
  int streak = 0;
  int misses = 0;
  int best = 0;
  bool over = false;

  bool charging = false;
  double power = 0; // 0..1
  late AnimationController _charge; // ping-pong meter
  late AnimationController _flight;
  double _flightSpin = 0; // total degrees
  bool _landed = false;
  bool _landOk = false;

  @override
  void initState() {
    super.initState();
    _charge = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..addListener(() {
        if (charging) setState(() => power = _charge.value);
      });
    _flight = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _resolveLanding();
      });
    _loadBest();
  }

  Future<void> _loadBest() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => best = sp.getInt('flipbottle_best') ?? 0);
  }

  Future<void> _saveBest() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('flipbottle_best', best);
  }

  @override
  void dispose() {
    _charge.dispose();
    _flight.dispose();
    super.dispose();
  }

  double get _tolerance => max(12, 26 - streak * 1.5); // degrees

  void _startCharge() {
    if (over || _flight.isAnimating) return;
    setState(() {
      charging = true;
    });
    _charge.repeat(reverse: true);
    Sfx.tap();
  }

  void _release() {
    if (over || !charging || _flight.isAnimating) return;
    _charge.stop();
    setState(() => charging = false);
    // total spin: power * 3 full turns
    _flightSpin = power * 1080;
    _landed = false;
    Sfx.move();
    _flight.forward(from: 0);
  }

  void _resolveLanding() {
    final mod = _flightSpin % 360;
    final upright = mod < _tolerance || mod > 360 - _tolerance;
    setState(() {
      _landed = true;
      _landOk = upright;
    });
    if (upright) {
      final gained = 10 + streak * 5;
      widget.players[0].score += gained;
      widget.callbacks.refreshHud();
      setState(() {
        streak++;
        if (streak > best) {
          best = streak;
          _saveBest();
        }
      });
      Sfx.win();
    } else {
      setState(() => misses++);
      Sfx.lose();
      if (misses >= 3) {
        _endGame();
        return;
      }
    }
    // brief pause showing result, then reset for next flip
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || over) return;
      setState(() {
        _landed = false;
        power = 0;
      });
    });
  }

  void _endGame() {
    setState(() => over = true);
    widget.callbacks.finish(
        headline: 'Streak: $streak! 🍾',
        subline: best > 0
            ? 'Best streak ever: $best. The bottles fear you.'
            : 'Not bad for a first flip!');
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat(t, '🔥 Streak', '$streak'),
              const SizedBox(width: 12),
              _stat(t, '🏆 Best', '$best'),
              const SizedBox(width: 12),
              _stat(t, '💔 Misses', '${3 - misses} left'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GestureDetector(
              onTapDown: (_) => _startCharge(),
              onTapUp: (_) => _release(),
              onTapCancel: () => _release(),
              child: LayoutBuilder(builder: (ctx, box) {
                final size = box.biggest;
                return CustomPaint(
                  size: size,
                  painter: _BottlePainter(
                    theme: t,
                    charging: charging,
                    power: power,
                    flightT: _flight.isAnimating ? _flight.value : -1,
                    spin: _flightSpin,
                    landed: _landed,
                    landOk: _landOk,
                    tolerance: _tolerance,
                    streak: streak,
                  ),
                );
              }),
            ),
          ),
          Text(
              over
                  ? 'Game over!'
                  : charging
                      ? 'Release at a GREEN zone! 🟢'
                      : 'Hold anywhere to charge…',
              style: TextStyle(
                  color: t.text, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _stat(GameTheme t, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration:
          BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: t.muted, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: t.text, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  final GameTheme theme;
  final bool charging;
  final double power;
  final double flightT;
  final double spin;
  final bool landed;
  final bool landOk;
  final double tolerance;
  final int streak;

  _BottlePainter({
    required this.theme,
    required this.charging,
    required this.power,
    required this.flightT,
    required this.spin,
    required this.landed,
    required this.landOk,
    required this.tolerance,
    required this.streak,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final platY = size.height * 0.72;
    final leftX = size.width * 0.22;
    final gap = min(size.width * 0.45, 120.0 + streak * 8.0);
    final rightX = leftX + gap;
    final platW = max(56.0, 110.0 - streak * 4.0);

    // platforms
    final platPaint = Paint()..color = theme.secondary;
    for (final x in [leftX, rightX]) {
      final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, platY + 8), width: platW, height: 16),
          const Radius.circular(8));
      canvas.drawRRect(rect, platPaint);
    }

    // bottle position + rotation
    Offset pos;
    double rot;
    if (flightT >= 0) {
      final t = flightT;
      pos = Offset(
        leftX + (rightX - leftX) * t,
        platY - 46 - sin(t * pi) * (90 + streak * 4.0),
      );
      rot = spin * t * pi / 180;
    } else if (landed) {
      pos = Offset(rightX, platY - 46);
      final mod = spin % 360;
      rot = (landOk ? 0 : (mod > 180 ? -1 : 1) * (90 - tolerance / 2)) * pi / 180;
    } else {
      pos = Offset(leftX, platY - 46);
      rot = 0;
    }
    _bottle(canvas, pos, rot);

    // power meter (right side)
    final meterX = size.width - 44;
    final meterTop = size.height * 0.15;
    final meterH = size.height * 0.45;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(meterX, meterTop, 26, meterH), const Radius.circular(13)),
        Paint()..color = theme.surface);
    // green sweet zones at 0, 1/3, 2/3, 1
    for (final z in [0.0, 1 / 3, 2 / 3, 1.0]) {
      final zy = meterTop + meterH * (1 - z);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(meterX + 13, zy), width: 26, height: 14),
              const Radius.circular(7)),
          Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.85));
    }
    if (charging) {
      final my = meterTop + meterH * (1 - power);
      canvas.drawCircle(Offset(meterX + 13, my), 12,
          Paint()..color = theme.accent);
      canvas.drawCircle(Offset(meterX + 13, my), 12,
          Paint()..color = theme.text..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    final label = TextPainter(
        text: TextSpan(
            text: 'POWER',
            style: TextStyle(
                color: theme.muted, fontSize: 11, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr)
      ..layout();
    label.paint(canvas, Offset(meterX - 4, meterTop - 20));

    // result banner
    if (landed) {
      final tp = TextPainter(
          text: TextSpan(
              text: landOk ? 'NAILED IT! 🎯' : 'SO CLOSE! 💦',
              style: TextStyle(
                  color: landOk ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                  fontSize: 30,
                  fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas,
          Offset(size.width / 2 - tp.width / 2, size.height * 0.12));
    }
  }

  void _bottle(Canvas canvas, Offset c, double rot) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    // body
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 6), width: 34, height: 62),
        const Radius.circular(10));
    canvas.drawRRect(body, Paint()..color = theme.primary);
    // water
    final water = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 16), width: 26, height: 34),
        const Radius.circular(8));
    canvas.drawRRect(water, Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.8));
    // neck + cap
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, -30), width: 16, height: 14),
        Paint()..color = theme.primary);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, -40), width: 20, height: 10),
            const Radius.circular(4)),
        Paint()..color = theme.accent);
    // shine
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-11, -16, 6, 44), const Radius.circular(3)),
        Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BottlePainter old) => true;
}
