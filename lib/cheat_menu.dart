import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Universal cheat/debug menu for Wajiha games.
///
/// Integration:
/// 1. Drop this file into `lib/` (e.g. `lib/cheat_menu.dart`).
/// 2. Add a discreet trigger in settings or menu screen, e.g.:
///      CheatMenuTrigger(onUnlocked: () => CheatMenu.show(context, callbacks))
///    The trigger requires 5 rapid taps on its child to open the menu.
/// 3. Pass a [CheatCallbacks] wired to the game's engine.
///
/// The menu offers: Skip Level, Instant Win, Infinite Lives/Hints,
/// Unlock All, and Reset Cheats. State persists via SharedPreferences
/// so cheats survive restarts (until explicitly reset).
class CheatCallbacks {
  /// Skip the current level/round. If the game has no levels, restart
  /// with a win or advance the score — implement per game.
  final VoidCallback? onSkipLevel;

  /// Immediately trigger the win condition.
  final VoidCallback? onInstantWin;

  /// Grant unlimited lives. Called once when toggled on.
  final VoidCallback? onInfiniteLives;

  /// Grant unlimited hints. Called once when toggled on.
  final VoidCallback? onInfiniteHints;

  /// Unlock every locked item (themes, shapes, levels, pictures...).
  final VoidCallback? onUnlockAll;

  /// Fully reset the game to a clean state (for "stuck" recovery).
  final VoidCallback? onResetGame;

  const CheatCallbacks({
    this.onSkipLevel,
    this.onInstantWin,
    this.onInfiniteLives,
    this.onInfiniteHints,
    this.onUnlockAll,
    this.onResetGame,
  });
}

class CheatMenu {
  static const _kLives = 'cheat_infinite_lives';
  static const _kHints = 'cheat_infinite_hints';

  /// Returns true if infinite lives cheat is active.
  static Future<bool> get infiniteLives async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kLives) ?? false;
  }

  /// Returns true if infinite hints cheat is active.
  static Future<bool> get infiniteHints async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kHints) ?? false;
  }

  static Future<void> show(BuildContext context, CheatCallbacks cb) async {
    final p = await SharedPreferences.getInstance();
    bool lives = p.getBool(_kLives) ?? false;
    bool hints = p.getBool(_kHints) ?? false;

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cheats',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'For testing & stuck recovery. Progress is yours.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (cb.onSkipLevel != null)
                  _btn(ctx, 'Skip level / round', Icons.skip_next, () {
                    Navigator.pop(ctx);
                    cb.onSkipLevel!();
                  }),
                if (cb.onInstantWin != null)
                  _btn(ctx, 'Instant win', Icons.emoji_events, () {
                    Navigator.pop(ctx);
                    cb.onInstantWin!();
                  }),
                SwitchListTile(
                  title: const Text('Infinite lives',
                      style: TextStyle(color: Colors.white)),
                  value: lives,
                  activeColor: Colors.amber,
                  onChanged: cb.onInfiniteLives == null
                      ? null
                      : (v) async {
                          await p.setBool(_kLives, v);
                          setS(() => lives = v);
                          if (v) cb.onInfiniteLives!();
                        },
                ),
                SwitchListTile(
                  title: const Text('Infinite hints',
                      style: TextStyle(color: Colors.white)),
                  value: hints,
                  activeColor: Colors.amber,
                  onChanged: cb.onInfiniteHints == null
                      ? null
                      : (v) async {
                          await p.setBool(_kHints, v);
                          setS(() => hints = v);
                          if (v) cb.onInfiniteHints!();
                        },
                ),
                if (cb.onUnlockAll != null)
                  _btn(ctx, 'Unlock everything', Icons.lock_open, () {
                    Navigator.pop(ctx);
                    cb.onUnlockAll!();
                  }),
                if (cb.onResetGame != null)
                  _btn(ctx, 'Reset game (unstick)', Icons.refresh, () {
                    Navigator.pop(ctx);
                    cb.onResetGame!();
                  }),
                _btn(ctx, 'Reset all cheats', Icons.restore, () async {
                  await p.setBool(_kLives, false);
                  await p.setBool(_kHints, false);
                  if (ctx.mounted) Navigator.pop(ctx);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _btn(
      BuildContext ctx, String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E2E3E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }

  /// Consume one life, respecting the infinite-lives cheat.
  /// Returns the new life count.
  static Future<int> consumeLife(int current) async {
    if (await infiniteLives) return current;
    return current - 1;
  }

  /// Consume one hint, respecting the infinite-hints cheat.
  /// Returns the new hint count.
  static Future<int> consumeHint(int current) async {
    if (await infiniteHints) return current;
    return current - 1;
  }
}

/// A discreet trigger widget: tap the child 5 times quickly to unlock
/// the cheat menu. Place it around a version label or a small icon in
/// settings/menu so it's discoverable but not prominent.
class CheatMenuTrigger extends StatefulWidget {
  final Widget child;
  final CheatCallbacks callbacks;

  const CheatMenuTrigger(
      {super.key, required this.child, required this.callbacks});

  @override
  State<CheatMenuTrigger> createState() => _CheatMenuTriggerState();
}

class _CheatMenuTriggerState extends State<CheatMenuTrigger> {
  int _taps = 0;
  DateTime _last = DateTime.now();

  void _onTap() {
    final now = DateTime.now();
    if (now.difference(_last).inSeconds > 2) _taps = 0;
    _last = now;
    _taps++;
    if (_taps >= 5) {
      _taps = 0;
      CheatMenu.show(context, widget.callbacks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _onTap, child: widget.child);
  }
}
