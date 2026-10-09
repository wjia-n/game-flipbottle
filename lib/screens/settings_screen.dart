import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/flip_themes.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';
import 'ui_kit.dart';

/// Settings: audio, renameable player, theme/bottle/table pickers, custom
/// theme creator (PRO), stats reset.
class SettingsScreen extends StatelessWidget {
  final FlipAudio audio;
  final FlipSettings settings;
  final FlipStore store;
  const SettingsScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  FlipThemeDef themeOf(FlipSettings s) =>
      flipThemeById(s.themeId, custom: s.customTheme);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) {
        final t = themeOf(settings);
        return Scaffold(
          body: Container(
            decoration: FlipUi.backdrop(t),
            child: SafeArea(
              child: Column(
                children: [
                  _appBar(context, t),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section(t, 'PLAYER'),
                          _nameRow(context, t),
                          const SizedBox(height: 14),
                          _section(t, 'SOUND'),
                          _toggleRow(t, 'Music', Icons.music_note,
                              settings.musicOn, (v) {
                            settings.setMusic(v);
                            audio.configure(
                                musicOn: v,
                                sfxOn: settings.sfxOn,
                                volume: settings.volume);
                            if (v) {
                              audio.startMenuMusic();
                            }
                          }),
                          _toggleRow(t, 'Sound effects', Icons.volume_up,
                              settings.sfxOn, (v) {
                            settings.setSfx(v);
                            audio.configure(
                                musicOn: settings.musicOn,
                                sfxOn: v,
                                volume: settings.volume);
                            if (v) audio.click();
                          }),
                          _volumeRow(t),
                          const SizedBox(height: 14),
                          _section(t, 'VENUE THEME  (${flipThemes.length})'),
                          _themeGrid(context, t),
                          if (!settings.isPro)
                            _proNudge(context, t,
                                'PRO unlocks 4 more venues + the custom theme studio'),
                          const SizedBox(height: 14),
                          _section(t, 'BOTTLE STYLE  (${bottleStyles.length})'),
                          _bottleGrid(context, t),
                          const SizedBox(height: 14),
                          _section(t, 'TABLE MATERIAL  (${tableStyles.length})'),
                          _tableGrid(context, t),
                          const SizedBox(height: 14),
                          _section(t, 'STATS'),
                          _statsCard(context, t),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _appBar(BuildContext context, FlipThemeDef t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          FlipUi.iconButton(t,
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: () {
                audio.click();
                Navigator.of(context).pop();
              }),
          const SizedBox(width: 12),
          Text('Settings', style: FlipUi.display(26, t)),
        ],
      ),
    );
  }

  Widget _section(FlipThemeDef t, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: FlipUi.label(13, t)),
      );

  Widget _nameRow(BuildContext context, FlipThemeDef t) {
    return FlipUi.card(t,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Display name', style: FlipUi.body(14, t, color: t.muted)),
                  Text(settings.playerName,
                      style: FlipUi.body(20, t)),
                ],
              ),
            ),
            FlipUi.iconButton(t, icon: Icons.edit, tooltip: 'Rename',
                onTap: () {
              audio.click();
              final ctrl =
                  TextEditingController(text: settings.playerName);
              final focus = FocusNode();
              // Commit on focus loss (per-keystroke saves keep JSON fresh).
              focus.addListener(() {
                if (!focus.hasFocus) {
                  settings.setPlayerName(ctrl.text);
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
                    // Save on EVERY keystroke — never only on keyboard-done.
                    onChanged: (v) => settings.setPlayerName(v),
                    onSubmitted: (_) => Navigator.of(context).pop(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        settings.setPlayerName(ctrl.text);
                        audio.click();
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
            }),
          ],
        ));
  }

  Widget _toggleRow(FlipThemeDef t, String label, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    return FlipUi.card(t,
        child: Row(
          children: [
            Icon(icon, color: t.text),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: FlipUi.body(16, t))),
            Switch(
              value: value,
              activeThumbColor: t.accent,
              onChanged: (v) {
                audio.click();
                onChanged(v);
              },
            ),
          ],
        ));
  }

  Widget _volumeRow(FlipThemeDef t) {
    return FlipUi.card(t,
        child: Row(
          children: [
            const Icon(Icons.tune),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: settings.volume,
                activeColor: t.accent,
                onChanged: (v) {
                  settings.setVolume(v);
                  audio.configure(
                      musicOn: settings.musicOn,
                      sfxOn: settings.sfxOn,
                      volume: v);
                },
              ),
            ),
            Text('${(settings.volume * 100).round()}%',
                style: FlipUi.body(14, t)),
          ],
        ));
  }

  Widget _themeGrid(BuildContext context, FlipThemeDef t) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.35,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: flipThemes.length,
      itemBuilder: (_, i) {
        final th = flipThemes[i];
        final unlocked = settings.themeUnlocked(th.id);
        final selected = settings.themeId == th.id;
        return GestureDetector(
          onTap: () {
            audio.click();
            if (!unlocked) {
              _openPro(context);
              return;
            }
            settings.setTheme(th.id);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [th.skyTop, th.skyBottom],
              ),
              border: Border.all(
                  color: selected ? th.accent : Colors.black.withValues(alpha: 0.12),
                  width: selected ? 4 : 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(th.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: th.text)),
                  ),
                ),
                if (!unlocked)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.lock, size: 16, color: Colors.white),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottleGrid(BuildContext context, FlipThemeDef t) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: bottleStyles.length,
      itemBuilder: (_, i) {
        final b = bottleStyles[i];
        final unlocked = settings.bottleUnlocked(i);
        final selected = settings.bottleStyle == i;
        return GestureDetector(
          onTap: () {
            audio.click();
            if (!unlocked) {
              _openPro(context);
              return;
            }
            settings.setBottleStyle(i);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? t.accent : Colors.black.withValues(alpha: 0.1),
                  width: selected ? 4 : 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 40,
                        decoration: BoxDecoration(
                          color: b.body,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.2)),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 12,
                            height: 8,
                            decoration: BoxDecoration(
                              color: b.cap,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(b.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: t.text)),
                      ),
                    ],
                  ),
                ),
                if (!unlocked)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.lock, size: 14, color: t.muted),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tableGrid(BuildContext context, FlipThemeDef t) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: tableStyles.length,
      itemBuilder: (_, i) {
        final tb = tableStyles[i];
        final unlocked = settings.tableUnlocked(i);
        final selected = settings.tableStyle == i;
        return GestureDetector(
          onTap: () {
            audio.click();
            if (!unlocked) {
              _openPro(context);
              return;
            }
            settings.setTableStyle(i);
          },
          child: Container(
            decoration: BoxDecoration(
              color: tb.top,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? t.accent : Colors.black.withValues(alpha: 0.15),
                  width: selected ? 4 : 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(tb.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 3)
                            ])),
                  ),
                ),
                if (!unlocked)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.lock, size: 14, color: Colors.white),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _proNudge(BuildContext context, FlipThemeDef t, String text) {
    return GestureDetector(
      onTap: () {
        audio.click();
        _openPro(context);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.star, color: t.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: FlipUi.body(13, t))),
            Icon(Icons.arrow_forward, color: t.accent),
          ],
        ),
      ),
    );
  }

  Widget _statsCard(BuildContext context, FlipThemeDef t) {
    final s = settings;
    return FlipUi.card(t,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat(t, '${s.gamesPlayed}', 'GAMES'),
                _stat(t, '${s.totalFlips}', 'FLIPS'),
                _stat(t, '${s.perfectLandings}', 'PERFECT'),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                audio.click();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Reset all stats?',
                        style: FlipUi.body(18, t)),
                    content: Text(
                        'This clears your best streaks, scores and totals.',
                        style: FlipUi.body(14, t)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CANCEL'),
                      ),
                      TextButton(
                        onPressed: () {
                          settings.resetStats();
                          audio.click();
                          Navigator.of(context).pop();
                        },
                        child: const Text('RESET',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: Text('Reset stats',
                  style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            const SizedBox(height: 10),
            FlipUi.chunkyButton(
              t: t,
              text: settings.isPro
                  ? 'CUSTOM THEME STUDIO'
                  : 'CUSTOM THEME STUDIO  🔒',
              fontSize: 14,
              onTap: () {
                audio.click();
                if (!settings.isPro) {
                  _openPro(context);
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                        audio: audio, settings: settings),
                  ),
                );
              },
            ),
          ],
        ));
  }

  Widget _stat(FlipThemeDef t, String value, String label) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: t.text, fontWeight: FontWeight.w900, fontSize: 20)),
          Text(label, style: TextStyle(color: t.muted, fontSize: 10)),
        ],
      );

  void _openPro(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProScreen(audio: audio, settings: settings, store: store),
      ),
    );
  }
}
