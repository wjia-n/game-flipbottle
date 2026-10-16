import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Flip Bottle engine: owns ALL game state and phases.
///
/// Phases: idle -> charging -> flying -> resolving -> settling -> idle…
/// …or gameOver when the run ends. Every phase is advanced by an
/// engine-owned timer, and a watchdog verifies every phase has a live timer;
/// stuck states are impossible by construction. The UI only renders.
enum FlipPhase { idle, charging, flying, resolving, settling, gameOver }

enum GameMode { classic, endless, scoreAttack }

enum FlipDifficulty { rookie, skilled, legend }

enum LandQuality { miss, ok, perfect }

/// Per-difficulty tuning. Higher tiers: tighter landing tolerance, faster
/// charge meter (harder to time), more spin, longer gaps, narrower platforms.
class FlipTuning {
  final double toleranceDeg;
  final int chargePeriodMs;
  final double maxTurns;
  final double gapBase; // fraction of play width
  final double platW; // fraction of play width
  final int basePoints;

  const FlipTuning({
    required this.toleranceDeg,
    required this.chargePeriodMs,
    required this.maxTurns,
    required this.gapBase,
    required this.platW,
    required this.basePoints,
  });
}

const flipTunings = <FlipTuning>[
  FlipTuning(
      toleranceDeg: 30,
      chargePeriodMs: 1400,
      maxTurns: 3.0,
      gapBase: 0.40,
      platW: 0.24,
      basePoints: 10), // rookie
  FlipTuning(
      toleranceDeg: 21,
      chargePeriodMs: 1100,
      maxTurns: 3.5,
      gapBase: 0.46,
      platW: 0.20,
      basePoints: 15), // skilled
  FlipTuning(
      toleranceDeg: 13,
      chargePeriodMs: 880,
      maxTurns: 4.0,
      gapBase: 0.52,
      platW: 0.16,
      basePoints: 25), // legend
];

/// Result of one flip, for the UI to celebrate (or mourn) visibly.
class FlipResult {
  final LandQuality quality;
  final int points;
  final double finalAngleDeg;
  final int bannerSeq;

  const FlipResult({
    required this.quality,
    required this.points,
    required this.finalAngleDeg,
    required this.bannerSeq,
  });
}

/// A ground prop in world coordinates. The engine keeps a rolling window
/// of props around the camera: spawned ahead, recycled behind.
class WorldProp {
  final double wx; // world x, in screen-width units
  final int kind; // 0 tuft, 1 pebble, 2 flower, 3 cone, 4 sign
  final double seed; // 0..1 visual variation

  const WorldProp({required this.wx, required this.kind, required this.seed});
}

class FlipEngine extends ChangeNotifier {
  final FlipDifficulty difficulty;
  final GameMode mode;
  final Random _rng;

  FlipEngine({
    required this.difficulty,
    required this.mode,
    Random? rng,
  }) : _rng = rng ?? Random();

  // ------------------------------------------------------------ state
  FlipPhase phase = FlipPhase.idle;
  double power = 0; // 0..1 charge meter
  double flightT = 0; // 0..1 flight progress
  double spinTotalDeg = 0;
  double startX = 0.18; // logical 0..1 across play width
  double targetX = 0.60;
  double platW = 0.24;
  double apex = 0.34; // peak height, logical 0..1 of play height
  int streak = 0;
  int misses = 0; // classic lives used
  int score = 0;
  int flips = 0;
  int perfects = 0;
  int level = 1; // progression tier inside a run
  double timeLeft = 60; // score attack
  int livesLeft = 3; // classic

  FlipResult? lastResult;
  int _bannerSeq = 0;

  // ------------------------------------------------------------ world scroll
  // Side-scrolling camera: worldX advances with the bottle's forward
  // momentum, so the bottle stays pinned near [camAnchor] on screen while
  // the world moves beneath it. World units == logical screen widths.
  double worldX = 0;
  double bottleWorldX = 0.18;
  static const double camAnchor = 0.42;
  final List<WorldProp> props = [];
  double _nextPropAt = 0;

  // ---- cheat flags (wired by the cheat menu) ----
  bool cheatInfiniteLives = false;

  // ------------------------------------------------------------ timers
  Timer? _chargeTimer;
  Timer? _flightTimer;
  Timer? _resolveTimer;
  Timer? _settleTimer;
  Timer? _clockTimer;
  Timer? _watchdog;

  DateTime? _phaseEnteredAt;
  Duration _phaseBudget = Duration.zero; // for watchdog recovery math
  bool _paused = false;
  bool _disposed = false;

  static const _tick = Duration(milliseconds: 16);

  FlipTuning get _t => flipTunings[difficulty.index];

  /// Effective tuning with in-run progression: every 5 streaks the game gets
  /// faster, tighter, longer — visible difficulty ramp.
  double get toleranceDeg =>
      max(8.0, _t.toleranceDeg * pow(0.94, (level - 1)));
  int get chargePeriodMs =>
      max(700, (_t.chargePeriodMs * pow(0.96, (level - 1))).round());
  double get gapBase => min(0.62, _t.gapBase + 0.02 * (level - 1));
  double get platWFrac => max(0.12, _t.platW * pow(0.96, (level - 1)));

  int get maxLives => mode == GameMode.classic ? 3 : 1;
  bool get isScoreAttack => mode == GameMode.scoreAttack;

  // ------------------------------------------------------------ lifecycle
  void start() {
    _newRound();
    _watchdog ??= Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!_disposed) _watchdogCheck();
    });
    if (isScoreAttack) {
      _clockTimer?.cancel();
      _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_disposed || _paused) return;
        if (phase == FlipPhase.gameOver) return;
        timeLeft -= 0.25;
        if (timeLeft <= 0) {
          timeLeft = 0;
          _finishGame();
        }
        notifyListeners();
      });
    }
  }

  void _enter(FlipPhase p, {Duration? budget}) {
    phase = p;
    _phaseEnteredAt = DateTime.now();
    _phaseBudget = budget ?? Duration.zero;
    notifyListeners();
  }

  void _newRound() {
    // Move the target platform: the bottle "lands" on the next table.
    startX = targetX;
    targetX = (startX + gapBase + _rng.nextDouble() * 0.10)
        .clamp(0.30, 0.92);
    if (targetX - startX < 0.28) {
      targetX = (startX + 0.34).clamp(0.30, 0.92);
    }
    platW = platWFrac;
    apex = 0.30 + _rng.nextDouble() * 0.10 + level * 0.008;
    power = 0;
    flightT = 0;
    lastResult = null;
    // Camera: bottle rests on the start platform, pinned at the anchor.
    bottleWorldX = startX;
    worldX = startX - camAnchor;
    _maintainProps();
    _enter(FlipPhase.idle);
  }

  /// Keeps the rolling prop window around the camera: recycles props that
  /// fell behind, spawns fresh ones ahead of the view.
  void _maintainProps() {
    if (props.isEmpty) _nextPropAt = worldX - 0.6;
    props.removeWhere((p) => p.wx < worldX - 0.8);
    var guard = 0;
    while (_nextPropAt < worldX + 2.0 && guard++ < 40) {
      props.add(WorldProp(
        wx: _nextPropAt,
        kind: _rng.nextInt(5),
        seed: _rng.nextDouble(),
      ));
      _nextPropAt += 0.16 + _rng.nextDouble() * 0.34;
    }
  }

  /// Advances the camera with the bottle's horizontal motion during flight.
  void _updateCamera() {
    bottleWorldX = startX + (targetX - startX) * flightT;
    worldX = bottleWorldX - camAnchor;
    _maintainProps();
  }

  // ------------------------------------------------------------ input
  /// Press-and-hold begins. Only legal from idle.
  void pressDown() {
    if (_paused || phase != FlipPhase.idle) return;
    _enter(FlipPhase.charging, budget: const Duration(seconds: 14));
    _chargeTimer?.cancel();
    final period = chargePeriodMs;
    var dir = 1.0;
    _chargeTimer = Timer.periodic(_tick, (_) {
      if (_disposed || _paused) return;
      power += dir * (_tick.inMilliseconds / period);
      if (power >= 1) {
        power = 1;
        dir = -1;
      } else if (power <= 0) {
        power = 0;
        dir = 1;
      }
      notifyListeners();
    });
    // Safety: a hold that never releases auto-fires after 12s.
    Timer(const Duration(seconds: 12), () {
      if (!_disposed && !_paused && phase == FlipPhase.charging) {
        release();
      }
    });
  }

  /// Release fires the flip. Only legal while charging.
  void release() {
    if (_paused || phase != FlipPhase.charging) return;
    _chargeTimer?.cancel();
    _chargeTimer = null;
    spinTotalDeg = power * _t.maxTurns * 360;
    flightT = 0;
    _enter(FlipPhase.flying, budget: const Duration(seconds: 3));
    _flightTimer?.cancel();
    const flightMs = 850;
    _flightTimer = Timer.periodic(_tick, (_) {
      if (_disposed || _paused) return;
      flightT += _tick.inMilliseconds / flightMs;
      if (flightT >= 1) {
        flightT = 1;
      }
      _updateCamera(); // world scrolls under the flying bottle
      if (flightT >= 1) {
        _resolveLanding();
      }
      notifyListeners();
    });
  }

  /// Touch cancelled mid-charge: settle back to idle, no penalty.
  void cancelCharge() {
    if (phase != FlipPhase.charging) return;
    _chargeTimer?.cancel();
    _chargeTimer = null;
    power = 0;
    _enter(FlipPhase.idle);
  }

  // ------------------------------------------------------------ resolution
  void _resolveLanding() {
    _flightTimer?.cancel();
    _flightTimer = null;
    final angle = spinTotalDeg % 360;
    final tol = toleranceDeg;
    final upright = angle <= tol || angle >= 360 - tol;
    final perfectZone = tol / 3;
    final perfect = angle <= perfectZone || angle >= 360 - perfectZone;
    final quality =
        perfect ? LandQuality.perfect : (upright ? LandQuality.ok : LandQuality.miss);

    flips++;
    int points = 0;
    if (quality != LandQuality.miss) {
      streak++;
      if (streak % 5 == 0) level++; // visible progression ramp
      final mult = mode == GameMode.endless ? 1.5 : 1.0;
      points = ((_t.basePoints + streak * 2) * mult).round();
      if (quality == LandQuality.perfect) {
        points *= 2;
        perfects++;
      }
      score += points;
    } else {
      streak = 0;
      misses++;
      // Infinite-lives cheat: misses still count for accuracy stats, but
      // the run never ends on lives.
      livesLeft = cheatInfiniteLives ? maxLives : max(0, maxLives - misses);
    }

    _bannerSeq++;
    lastResult = FlipResult(
      quality: quality,
      points: points,
      finalAngleDeg: angle,
      bannerSeq: _bannerSeq,
    );
    _enter(FlipPhase.resolving, budget: const Duration(milliseconds: 700));
    _resolveTimer?.cancel();
    _resolveTimer = Timer(const Duration(milliseconds: 650), () {
      if (!_disposed && !_paused) _settle();
    });
  }

  void _settle() {
    if (phase != FlipPhase.resolving) return;
    _enter(FlipPhase.settling, budget: const Duration(milliseconds: 1200));
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 1100), () {
      if (_disposed || _paused) return;
      _advance();
    });
  }

  void _advance() {
    final runOver = isScoreAttack
        ? false // clock ends score attack
        : (!cheatInfiniteLives && misses >= maxLives);
    if (runOver) {
      _finishGame();
    } else {
      _newRound();
    }
  }

  void _cancelPhaseTimers() {
    for (final t in [_chargeTimer, _flightTimer, _resolveTimer, _settleTimer]) {
      t?.cancel();
    }
    _chargeTimer = _flightTimer = _resolveTimer = _settleTimer = null;
  }

  void _finishGame() {
    _cancelPhaseTimers();
    _clockTimer?.cancel();
    _enter(FlipPhase.gameOver);
  }

  // ------------------------------------------------------------ cheat debug
  /// Cheat: skip the current round — bank bonus points, bump the level
  /// ramp, and move on to the next platform.
  void debugSkipLevel() {
    if (phase == FlipPhase.gameOver || _disposed) return;
    _cancelPhaseTimers();
    score += 50 * level;
    streak += 2;
    level++;
    _newRound();
  }

  /// Cheat: trigger the win state right now (game-over overlay + win jingle).
  void debugInstantWin() {
    if (phase == FlipPhase.gameOver || _disposed) return;
    _cancelPhaseTimers();
    score += 1000;
    streak = max(streak, 8);
    _finishGame();
  }

  // ------------------------------------------------------------ watchdog
  /// Recovers any phase found without a live timer. Runs every 700ms.
  void _watchdogCheck() {
    if (_paused || phase == FlipPhase.gameOver || phase == FlipPhase.idle) {
      return;
    }
    final entered = _phaseEnteredAt;
    final overdue = entered != null &&
        _phaseBudget != Duration.zero &&
        DateTime.now().difference(entered) >
            _phaseBudget + const Duration(milliseconds: 900);
    switch (phase) {
      case FlipPhase.charging:
        if (_chargeTimer == null || !(_chargeTimer?.isActive ?? false) || overdue) {
          // Recover: fire the flip rather than stranding the player.
          if (_chargeTimer == null) {
            release();
          } else {
            _chargeTimer?.cancel();
            _chargeTimer = null;
            _enter(FlipPhase.idle);
          }
        }
        break;
      case FlipPhase.flying:
        if (_flightTimer == null || !(_flightTimer?.isActive ?? false) || overdue) {
          _resolveLanding();
        }
        break;
      case FlipPhase.resolving:
        if (_resolveTimer == null || !(_resolveTimer?.isActive ?? false) || overdue) {
          _settle();
        }
        break;
      case FlipPhase.settling:
        if (_settleTimer == null || !(_settleTimer?.isActive ?? false) || overdue) {
          _advance();
        }
        break;
      case FlipPhase.idle:
      case FlipPhase.gameOver:
        break;
    }
  }

  // ------------------------------------------------------------ pause
  void pauseEngine() {
    if (_paused || phase == FlipPhase.gameOver) return;
    _paused = true;
    for (final t in [_chargeTimer, _flightTimer, _resolveTimer, _settleTimer, _clockTimer]) {
      t?.cancel();
    }
    notifyListeners();
  }

  void resumeEngine() {
    if (!_paused) return;
    _paused = false;
    // Restart the timer that owns the current phase.
    switch (phase) {
      case FlipPhase.charging:
        final p = power;
        pressDownRestore(p);
        break;
      case FlipPhase.flying:
        _restartFlight(flightT);
        break;
      case FlipPhase.resolving:
        _resolveTimer?.cancel();
        _resolveTimer = Timer(const Duration(milliseconds: 400), () {
          if (!_disposed && !_paused) _settle();
        });
        break;
      case FlipPhase.settling:
        _settleTimer?.cancel();
        _settleTimer = Timer(const Duration(milliseconds: 600), () {
          if (!_disposed && !_paused) _advance();
        });
        break;
      case FlipPhase.idle:
      case FlipPhase.gameOver:
        break;
    }
    if (isScoreAttack && phase != FlipPhase.gameOver) {
      _clockTimer?.cancel();
      _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_disposed || _paused) return;
        if (phase == FlipPhase.gameOver) return;
        timeLeft -= 0.25;
        if (timeLeft <= 0) {
          timeLeft = 0;
          _finishGame();
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _restartFlight(double fromT) {
    _flightTimer?.cancel();
    const flightMs = 850;
    var t = fromT;
    _flightTimer = Timer.periodic(_tick, (_) {
      if (_disposed || _paused) return;
      t += _tick.inMilliseconds / flightMs;
      flightT = t;
      if (flightT >= 1) {
        flightT = 1;
      }
      _updateCamera();
      if (flightT >= 1) {
        _resolveLanding();
      }
      notifyListeners();
    });
  }

  /// Resume a charge from a saved power level after pause.
  void pressDownRestore(double savedPower) {
    if (phase != FlipPhase.charging) return;
    power = savedPower;
    _enter(FlipPhase.charging, budget: const Duration(seconds: 14));
    _chargeTimer?.cancel();
    final period = chargePeriodMs;
    var dir = power >= 1 ? -1.0 : 1.0;
    _chargeTimer = Timer.periodic(_tick, (_) {
      if (_disposed || _paused) return;
      power += dir * (_tick.inMilliseconds / period);
      if (power >= 1) {
        power = 1;
        dir = -1;
      } else if (power <= 0) {
        power = 0;
        dir = 1;
      }
      notifyListeners();
    });
  }

  bool get isPaused => _paused;

  @override
  void dispose() {
    _disposed = true;
    for (final t in [
      _chargeTimer,
      _flightTimer,
      _resolveTimer,
      _settleTimer,
      _clockTimer,
      _watchdog
    ]) {
      t?.cancel();
    }
    super.dispose();
  }
}
