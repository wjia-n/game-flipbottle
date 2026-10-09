import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/flip_themes.dart';
import 'ui_kit.dart';

/// PRO: custom theme studio. Pick the venue colors; live preview; saved to
/// the custom theme slot.
class CustomThemeScreen extends StatefulWidget {
  final FlipAudio audio;
  final FlipSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

const _colorKeys = [
  'skyTop',
  'skyBottom',
  'platformTop',
  'platformEdge',
  'accent',
  'water',
  'text',
  'muted',
];

const _colorLabels = {
  'skyTop': 'Sky top',
  'skyBottom': 'Sky bottom',
  'platformTop': 'Platform top',
  'platformEdge': 'Platform edge',
  'accent': 'Accent',
  'water': 'Water',
  'text': 'Text',
  'muted': 'Muted text',
};

const _palette = [
  0xFFFFF3D6, 0xFFFFD98E, 0xFFFFB27D, 0xFFE2725B, 0xFFC62828, 0xFF6D4C41,
  0xFFB07B45, 0xFF7A4E28, 0xFFD4AF37, 0xFFFFD54F, 0xFF7CB342, 0xFF2E7D32,
  0xFF4FC3F7, 0xFF29B6F6, 0xFF1565C0, 0xFF1B9AAA, 0xFF80CBC4, 0xFF00695C,
  0xFFB39DDB, 0xFF5E4480, 0xFFF8BBD0, 0xFFAD1457, 0xFFEDEDED, 0xFF9E9E9E,
  0xFF424242, 0xFF211E1D, 0xFFFFFFFF, 0xFF4A2E17, 0xFF14424E, 0xFF0D3B4F,
];

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  String _editing = 'skyTop';

  FlipSettings get s => widget.settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) {
        final t = s.customTheme;
        final screenTheme =
            flipThemeById(s.themeId, custom: s.customTheme);
        return Scaffold(
          body: Container(
            decoration: FlipUi.backdrop(t),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                    child: Row(
                      children: [
                        FlipUi.iconButton(screenTheme,
                            icon: Icons.arrow_back,
                            tooltip: 'Back',
                            onTap: () {
                              widget.audio.click();
                              Navigator.of(context).pop();
                            }),
                        const SizedBox(width: 12),
                        Text('Theme Studio',
                            style: FlipUi.display(26, screenTheme)),
                      ],
                    ),
                  ),
                  // Live preview
                  Container(
                    margin: const EdgeInsets.all(16),
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [t.skyTop, t.skyBottom],
                      ),
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.15),
                          width: 2),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 40,
                          right: 40,
                          bottom: 44,
                          child: Container(
                            height: 26,
                            decoration: BoxDecoration(
                              color: t.platformTop,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                  color: t.platformEdge, width: 3),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 18,
                          child: Center(
                            child: Text('My Creation',
                                style: FlipUi.display(24, t)),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          right: 16,
                          child: Container(
                            width: 26,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.accent, width: 2),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: t.water,
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(6)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Color key selector
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      children: _colorKeys.map((k) {
                        final sel = _editing == k;
                        return GestureDetector(
                          onTap: () {
                            widget.audio.click();
                            setState(() => _editing = k);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            decoration: BoxDecoration(
                              color: sel
                                  ? t.accent
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: Colors.black
                                      .withValues(alpha: 0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Color(
                                        s.customColors[k] ?? 0xFF000000),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black26),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(_colorLabels[k]!,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: sel
                                            ? Colors.white
                                            : t.text)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _palette.length,
                      itemBuilder: (_, i) {
                        final c = _palette[i];
                        final sel = s.customColors[_editing] == c;
                        return GestureDetector(
                          onTap: () {
                            widget.audio.click();
                            s.setCustomColor(_editing, c);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(c),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: sel
                                      ? Colors.white
                                      : Colors.black
                                          .withValues(alpha: 0.15),
                                  width: sel ? 4 : 2),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8)
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FlipUi.chunkyButton(
                      t: screenTheme,
                      text: s.themeId == 'custom'
                          ? 'USING MY CREATION ✓'
                          : 'USE MY CREATION',
                      icon: Icons.check,
                      onTap: () {
                        widget.audio.click();
                        s.setTheme('custom');
                        Navigator.of(context).pop();
                      },
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
}
