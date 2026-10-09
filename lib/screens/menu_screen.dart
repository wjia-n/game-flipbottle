import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/flip_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/flip_themes.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'ui_kit.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.flipbottle';

const _modeNames = ['Classic', 'Endless', 'Score Attack'];
const _modeDescs = [
  '3 misses and the run ends. Pure streak chasing.',
  'One miss ends it all — but landings pay 1.5x. High risk, high glory.',
  '60 seconds, unlimited flips. Most points wins. (PRO)',
];
const _diffNames = ['Rookie', 'Skilled', 'Legend'];
const _diffDescs = [
  'Wide landing window, slow meter. Learn the flick.',
  'Tighter window, faster meter. The real game.',
  'Razor-thin window, blazing meter. For legends only.',
];

/// Main menu: logo, renameable player, bests, mode + difficulty pickers,
/// play, and links to themes/settings/pro/share.
class MenuScreen extends StatefulWidget {
  final FlipAudio audio;
  final FlipSettings settings;
  final FlipStore store;
  const MenuScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  FlipSettings get s => widget.settings;
  FlipThemeDef get t =>
      flipThemeById(s.themeId, custom: s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
  }

  void _play() {
    widget.audio.gameStart();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: s,
          store: widget.store,
          difficulty: FlipDifficulty.values[s.difficulty],
          mode: GameMode.values[s.mode],
        ),
      ),
    );
  }

  void _rename() {
    widget.audio.click();
    final ctrl = TextEditingController(text: s.playerName);
    final focus = FocusNode();
    // Commit on focus loss (per-keystroke saves already keep the JSON fresh).
    focus.addListener(() {
      if (!focus.hasFocus) {
        s.setPlayerName(ctrl.text);
      }
    });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Your name', style: FlipUi.body(20, t)),
        content: TextField(
          controller: ctrl,
          focusNode: focus,
          maxLength: 20,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Flipper'),
          // Save on EVERY keystroke — never only on keyboard-done.
          onChanged: (v) => s.setPlayerName(v),
          onSubmitted: (_) => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              s.setPlayerName(ctrl.text);
              widget.audio.click();
              Navigator.of(context).pop();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    ).then((_) {
      focus.dispose();
      ctrl.dispose();
    });
  }

  void _share() {
    widget.audio.click();
    Share.share(
        'I\'m flipping bottles in Flip Bottle! 🍾 Think you can beat my streak? $_storeUrl');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) {
        final theme = flipThemeById(s.themeId, custom: s.customTheme);
        return Scaffold(
          body: Container(
            decoration: FlipUi.backdrop(theme),
            child: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  children: [
                    // Logo + title
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: const Offset(0, 8),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/flipbottle_logo.png',
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 10),
                    Text('Flip Bottle', style: FlipUi.display(40, theme)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _rename,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('👋 ${s.playerName}',
                              style: FlipUi.body(17, theme)),
                          const SizedBox(width: 6),
                          Icon(Icons.edit,
                              size: 16,
                              color: theme.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Bests row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _best(theme, '🏆 Classic', '${s.bestClassic}'),
                        const SizedBox(width: 10),
                        _best(theme, '🔥 Endless', '${s.bestEndless}'),
                        const SizedBox(width: 10),
                        _best(theme, '⭐ Score', '${s.bestScore}'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Mode picker
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('GAME MODE', style: FlipUi.label(13, theme)),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(3, (i) {
                      final locked = i == 2 && !s.scoreAttackUnlocked;
                      final selected = s.mode == i;
                      return GestureDetector(
                        onTap: () {
                          widget.audio.click();
                          if (locked) {
                            _openPro();
                          } else {
                            s.setMode(i);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.accent.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: selected
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.08),
                                width: 2),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_modeNames[i],
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            color: selected
                                                ? Colors.white
                                                : theme.text)),
                                    Text(_modeDescs[i],
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: selected
                                                ? Colors.white
                                                    .withValues(alpha: 0.9)
                                                : theme.muted)),
                                  ],
                                ),
                              ),
                              if (locked)
                                const Icon(Icons.lock,
                                    color: Colors.white, size: 20)
                              else if (selected)
                                const Icon(Icons.check_circle,
                                    color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    // Difficulty picker
                    Align(
                      alignment: Alignment.centerLeft,
                      child:
                          Text('DIFFICULTY', style: FlipUi.label(13, theme)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(3, (i) {
                        final selected = s.difficulty == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              widget.audio.click();
                              s.setDifficulty(i);
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                  right: i < 2 ? 8 : 0),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.accent
                                    : Colors.white
                                        .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.black
                                        .withValues(alpha: 0.1),
                                    width: 2),
                              ),
                              child: Column(
                                children: [
                                  Text(_diffNames[i],
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: selected
                                              ? Colors.white
                                              : theme.text)),
                                  const SizedBox(height: 2),
                                  Text('🍾' * (i + 1),
                                      style: const TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_diffDescs[s.difficulty],
                          style: FlipUi.body(12, theme,
                              color: theme.muted)),
                    ),
                    const SizedBox(height: 18),
                    FlipUi.chunkyButton(
                      t: theme,
                      text: 'PLAY',
                      icon: Icons.play_arrow,
                      fontSize: 22,
                      onTap: _play,
                    ),
                    const SizedBox(height: 16),
                    // Utility row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FlipUi.iconButton(theme,
                            icon: Icons.palette,
                            tooltip: 'Themes & bottles',
                            onTap: () {
                              widget.audio.click();
                              _openSettings();
                            }),
                        const SizedBox(width: 14),
                        FlipUi.iconButton(theme,
                            icon: Icons.star,
                            tooltip: 'Go PRO',
                            onTap: () {
                              widget.audio.click();
                              _openPro();
                            }),
                        const SizedBox(width: 14),
                        FlipUi.iconButton(theme,
                            icon: Icons.share,
                            tooltip: 'Share',
                            onTap: _share),
                        const SizedBox(width: 14),
                        FlipUi.iconButton(theme,
                            icon: Icons.help_outline,
                            tooltip: 'How to play',
                            onTap: () {
                              widget.audio.click();
                              _howTo(theme);
                            }),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Hold to charge, release to flip.\nLand it upright!',
                        textAlign: TextAlign.center,
                        style: FlipUi.body(13, theme,
                            color: theme.muted)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _best(FlipThemeDef theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(color: theme.muted, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
            audio: widget.audio, settings: s, store: widget.store),
      ),
    );
  }

  void _openPro() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
            audio: widget.audio, settings: s, store: widget.store),
      ),
    );
  }

  void _howTo(FlipThemeDef theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('How to play', style: FlipUi.body(20, theme)),
        content: Text(
          '• PRESS AND HOLD anywhere to charge your flip.\n\n'
          '• RELEASE to send the bottle flying!\n\n'
          '• Land it UPRIGHT on the next platform to score.\n\n'
          '• Green zones on the meter = perfect spin. Dead-center = PERFECT bonus!\n\n'
          '• Every 5 streaks the game speeds up: tighter landings, faster meter, longer gaps.\n\n'
          '• Classic: 3 misses end the run. Endless: one miss ends it. Score Attack: 60 seconds, go wild!',
          style: FlipUi.body(14, theme),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }
}
