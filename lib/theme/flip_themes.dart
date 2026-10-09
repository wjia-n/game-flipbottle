import 'package:flutter/material.dart';

/// Flip Bottle art direction: warm, physical, tactile. Real tables, real
/// bottles, sunlight and shadows — never neon, never AI-dashboard.
///
/// 12 venue themes (color schemes), 8 bottle styles, 8 table styles.
/// Free players get the first 8 themes / 5 bottles / 5 tables; PRO unlocks
/// everything plus the custom theme creator.
class FlipThemeDef {
  final String id;
  final String name;
  final Color skyTop;
  final Color skyBottom;
  final Color platformTop;
  final Color platformEdge;
  final Color accent;
  final Color water;
  final Color text;
  final Color muted;
  final bool proOnly;

  const FlipThemeDef({
    required this.id,
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.platformTop,
    required this.platformEdge,
    required this.accent,
    required this.water,
    required this.text,
    required this.muted,
    this.proOnly = false,
  });
}

const flipThemes = <FlipThemeDef>[
  FlipThemeDef(
    id: 'sunny_kitchen',
    name: 'Sunny Kitchen',
    skyTop: Color(0xFFFFF3D6),
    skyBottom: Color(0xFFFFD98E),
    platformTop: Color(0xFFB07B45),
    platformEdge: Color(0xFF7A4E28),
    accent: Color(0xFFE07B39),
    water: Color(0xFF4FC3F7),
    text: Color(0xFF4A2E17),
    muted: Color(0xFF8A6A4A),
  ),
  FlipThemeDef(
    id: 'beach_day',
    name: 'Beach Day',
    skyTop: Color(0xFFBEE9F5),
    skyBottom: Color(0xFFFFF1C9),
    platformTop: Color(0xFFE8C87E),
    platformEdge: Color(0xFFB8934E),
    accent: Color(0xFF1B9AAA),
    water: Color(0xFF29B6F6),
    text: Color(0xFF14424E),
    muted: Color(0xFF5E8B96),
  ),
  FlipThemeDef(
    id: 'gym_floor',
    name: 'Gym Floor',
    skyTop: Color(0xFF3E3A38),
    skyBottom: Color(0xFF211E1D),
    platformTop: Color(0xFFC98F4E),
    platformEdge: Color(0xFF8A5A28),
    accent: Color(0xFFE53935),
    water: Color(0xFF4FC3F7),
    text: Color(0xFFF5EFE6),
    muted: Color(0xFFA79B8E),
  ),
  FlipThemeDef(
    id: 'meadow',
    name: 'Meadow',
    skyTop: Color(0xFFBDE7C7),
    skyBottom: Color(0xFFFFF6D9),
    platformTop: Color(0xFF7CB342),
    platformEdge: Color(0xFF4E7A26),
    accent: Color(0xFFFF8F00),
    water: Color(0xFF4DD0E1),
    text: Color(0xFF2E4A1E),
    muted: Color(0xFF6E8B5E),
  ),
  FlipThemeDef(
    id: 'sunset_porch',
    name: 'Sunset Porch',
    skyTop: Color(0xFFFFB27D),
    skyBottom: Color(0xFFE2725B),
    platformTop: Color(0xFF8A5A3B),
    platformEdge: Color(0xFF5C3A24),
    accent: Color(0xFFFFD54F),
    water: Color(0xFF4FC3F7),
    text: Color(0xFFFFF3E0),
    muted: Color(0xFFE0B48F),
  ),
  FlipThemeDef(
    id: 'pool_party',
    name: 'Pool Party',
    skyTop: Color(0xFF9FD8EF),
    skyBottom: Color(0xFFE8FBFF),
    platformTop: Color(0xFF64B5F6),
    platformEdge: Color(0xFF3E7CB1),
    accent: Color(0xFFFF7043),
    water: Color(0xFF00B0FF),
    text: Color(0xFF0D3B4F),
    muted: Color(0xFF5E93A8),
  ),
  FlipThemeDef(
    id: 'library',
    name: 'Library',
    skyTop: Color(0xFF3B4A3A),
    skyBottom: Color(0xFF222B21),
    platformTop: Color(0xFF6D4C2F),
    platformEdge: Color(0xFF4A3120),
    accent: Color(0xFFD4AF37),
    water: Color(0xFF80CBC4),
    text: Color(0xFFF0E8D5),
    muted: Color(0xFF9A917E),
  ),
  FlipThemeDef(
    id: 'desert',
    name: 'Desert Dunes',
    skyTop: Color(0xFFFFE3B3),
    skyBottom: Color(0xFFFFC37E),
    platformTop: Color(0xFFD9A85F),
    platformEdge: Color(0xFFA5763A),
    accent: Color(0xFFBF360C),
    water: Color(0xFF4FC3F7),
    text: Color(0xFF5C3A1E),
    muted: Color(0xFF9A7A52),
  ),
  // --- PRO-only venues ---
  FlipThemeDef(
    id: 'mountain_cabin',
    name: 'Mountain Cabin',
    skyTop: Color(0xFFA8C3D1),
    skyBottom: Color(0xFFE8EEF2),
    platformTop: Color(0xFF5D4037),
    platformEdge: Color(0xFF3E2723),
    accent: Color(0xFFEF6C00),
    water: Color(0xFF81D4FA),
    text: Color(0xFFF5EFE6),
    muted: Color(0xFF9AA5AD),
    proOnly: true,
  ),
  FlipThemeDef(
    id: 'campfire',
    name: 'Campfire',
    skyTop: Color(0xFF4A2E2A),
    skyBottom: Color(0xFF241512),
    platformTop: Color(0xFF7B5E42),
    platformEdge: Color(0xFF4E3A28),
    accent: Color(0xFFFFB300),
    water: Color(0xFF4FC3F7),
    text: Color(0xFFFFF3E0),
    muted: Color(0xFFB08D6B),
    proOnly: true,
  ),
  FlipThemeDef(
    id: 'snow_cabin',
    name: 'Snow Cabin',
    skyTop: Color(0xFFDCEBF5),
    skyBottom: Color(0xFFFFFFFF),
    platformTop: Color(0xFF90A4AE),
    platformEdge: Color(0xFF607D8B),
    accent: Color(0xFFD32F2F),
    water: Color(0xFF29B6F6),
    text: Color(0xFF263238),
    muted: Color(0xFF7E96A3),
    proOnly: true,
  ),
  FlipThemeDef(
    id: 'arcade_carpet',
    name: 'Arcade Carpet',
    skyTop: Color(0xFF5C4A72),
    skyBottom: Color(0xFF3A2E4A),
    platformTop: Color(0xFF8E6FB8),
    platformEdge: Color(0xFF5E4480),
    accent: Color(0xFFFFD54F),
    water: Color(0xFF4DD0E1),
    text: Color(0xFFFFF3E0),
    muted: Color(0xFFB9A8D6),
    proOnly: true,
  ),
];

FlipThemeDef flipThemeById(String id, {FlipThemeDef? custom}) {
  if (id == 'custom' && custom != null) return custom;
  for (final t in flipThemes) {
    if (t.id == id) return t;
  }
  return flipThemes.first;
}

/// 8 physical bottle styles. [shape]: 0 classic PET, 1 sport neck,
/// 2 round juice, 3 tall slim.
class BottleStyle {
  final String name;
  final Color body;
  final Color cap;
  final int shape;
  final bool proOnly;

  const BottleStyle({
    required this.name,
    required this.body,
    required this.cap,
    required this.shape,
    this.proOnly = false,
  });
}

const bottleStyles = <BottleStyle>[
  BottleStyle(name: 'Classic Clear', body: Color(0xFFDCEEF7), cap: Color(0xFF1E88E5), shape: 0),
  BottleStyle(name: 'Blue Sport', body: Color(0xFFBBDEFB), cap: Color(0xFF1565C0), shape: 1),
  BottleStyle(name: 'Green Soda', body: Color(0xFFC8E6C9), cap: Color(0xFF2E7D32), shape: 0),
  BottleStyle(name: 'Amber Glass', body: Color(0xFFFFE0B2), cap: Color(0xFF6D4C41), shape: 2),
  BottleStyle(name: 'Frosted', body: Color(0xFFE1F5FE), cap: Color(0xFF78909C), shape: 3),
  BottleStyle(
      name: 'Red Pop', body: Color(0xFFFFCDD2), cap: Color(0xFFC62828), shape: 1, proOnly: true),
  BottleStyle(
      name: 'Black Stealth', body: Color(0xFF616161), cap: Color(0xFF212121), shape: 3, proOnly: true),
  BottleStyle(
      name: 'Berry Juice', body: Color(0xFFF8BBD0), cap: Color(0xFFAD1457), shape: 2, proOnly: true),
];

/// 8 physical table materials for the platforms.
class TableStyle {
  final String name;
  final Color top;
  final Color edge;
  final bool proOnly;

  const TableStyle({required this.name, required this.top, required this.edge, this.proOnly = false});
}

const tableStyles = <TableStyle>[
  TableStyle(name: 'Oak Wood', top: Color(0xFFB07B45), edge: Color(0xFF7A4E28)),
  TableStyle(name: 'Marble', top: Color(0xFFEDEDED), edge: Color(0xFFB0B0B0)),
  TableStyle(name: 'Steel', top: Color(0xFF9E9E9E), edge: Color(0xFF616161)),
  TableStyle(name: 'Grass', top: Color(0xFF7CB342), edge: Color(0xFF4E7A26)),
  TableStyle(name: 'Sand', top: Color(0xFFE8C87E), edge: Color(0xFFB8934E)),
  TableStyle(
      name: 'Ice', top: Color(0xFFB3E5FC), edge: Color(0xFF4FA3D1), proOnly: true),
  TableStyle(
      name: 'Carpet', top: Color(0xFF8E6FB8), edge: Color(0xFF5E4480), proOnly: true),
  TableStyle(
      name: 'Carbon', top: Color(0xFF424242), edge: Color(0xFF212121), proOnly: true),
];

/// Custom theme built by the player (PRO).
FlipThemeDef buildCustomTheme(Map<String, int> c) {
  Color k(String key, int fb) => Color(c[key] ?? fb);
  return FlipThemeDef(
    id: 'custom',
    name: 'My Creation',
    skyTop: k('skyTop', 0xFFFFF3D6),
    skyBottom: k('skyBottom', 0xFFFFD98E),
    platformTop: k('platformTop', 0xFFB07B45),
    platformEdge: k('platformEdge', 0xFF7A4E28),
    accent: k('accent', 0xFFE07B39),
    water: k('water', 0xFF4FC3F7),
    text: k('text', 0xFF4A2E17),
    muted: k('muted', 0xFF8A6A4A),
  );
}
