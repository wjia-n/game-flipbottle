import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/flip_themes.dart';

/// Persisted settings + player profile + stats for Flip Bottle.
///
/// The player profile (name + bests + stats) is stored as ONE JSON string
/// under [_kProfileJson]. Android's SharedPreferences stores StringLists as
/// an unordered StringSet, so ordered data must NEVER use setStringList.
/// Legacy keys are migrated once and then removed.
class FlipSettings extends ChangeNotifier {
  static const _kMusic = 'flipbottle_music_on';
  static const _kSfx = 'flipbottle_sfx_on';
  static const _kVolume = 'flipbottle_volume';
  static const _kTheme = 'flipbottle_theme_id';
  static const _kBottle = 'flipbottle_bottle_style';
  static const _kTable = 'flipbottle_table_style';
  static const _kDifficulty = 'flipbottle_difficulty'; // 0 rookie, 1 skilled, 2 legend
  static const _kMode = 'flipbottle_mode'; // 0 classic, 1 endless, 2 score attack
  static const _kIsPro = 'flipbottle_is_pro';
  static const _kReviewPromptDate = 'flipbottle_review_prompt';
  static const _kCustomPrefix = 'flipbottle_custom_';

  /// Order-safe profile storage: a single JSON string.
  static const _kProfileJson = 'flipbottle_profile_json';

  /// Player display names as ONE order-preserving JSON string array via
  /// setString. NEVER use setStringList: on Android it is backed by an
  /// unordered StringSet (HashSet) and names come back scrambled across
  /// slots after every app restart. Flip Bottle has one slot; the array
  /// holds [playerName] at index 0 so the pattern scales if slots are added.
  static const _kNamesJson = 'flipbottle_player_names_json';

  /// Legacy keys to migrate: the old single-best int.
  static const _kLegacyBest = 'flipbottle_best';

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String themeId = 'sunny_kitchen';
  int bottleStyle = 0;
  int tableStyle = 0;
  int difficulty = 0; // rookie default
  int mode = 0; // classic default
  bool isPro = true; // everything unlocked — no Pro version

  // ---- Profile (persisted as ONE JSON string) ----
  String playerName = 'Flipper';
  int bestClassic = 0; // best streak, classic
  int bestEndless = 0; // best streak, endless
  int bestScore = 0; // best score, score attack
  int gamesPlayed = 0;
  int totalFlips = 0;
  int perfectLandings = 0;

  /// Custom theme colors (ARGB ints).
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'skyTop': 0xFFFFF3D6,
    'skyBottom': 0xFFFFD98E,
    'platformTop': 0xFFB07B45,
    'platformEdge': 0xFF7A4E28,
    'accent': 0xFFE07B39,
    'water': 0xFF4FC3F7,
    'text': 0xFF4A2E17,
    'muted': 0xFF8A6A4A,
  };

  FlipThemeDef get customTheme => buildCustomTheme(customColors);

  static Map<String, dynamic> encodeProfile(FlipSettings s) => {
        'bestClassic': s.bestClassic,
        'bestEndless': s.bestEndless,
        'bestScore': s.bestScore,
        'gamesPlayed': s.gamesPlayed,
        'totalFlips': s.totalFlips,
        'perfectLandings': s.perfectLandings,
      };

  void _decodeProfile(String? raw) {
    if (raw == null) return;
    try {
      final d = jsonDecode(raw);
      if (d is Map) {
        bestClassic = (d['bestClassic'] as num?)?.toInt() ?? 0;
        bestEndless = (d['bestEndless'] as num?)?.toInt() ?? 0;
        bestScore = (d['bestScore'] as num?)?.toInt() ?? 0;
        gamesPlayed = (d['gamesPlayed'] as num?)?.toInt() ?? 0;
        totalFlips = (d['totalFlips'] as num?)?.toInt() ?? 0;
        perfectLandings = (d['perfectLandings'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    musicOn = sp.getBool(_kMusic) ?? true;
    sfxOn = sp.getBool(_kSfx) ?? true;
    volume = (sp.getDouble(_kVolume) ?? 0.8).clamp(0.0, 1.0);
    themeId = sp.getString(_kTheme) ?? 'sunny_kitchen';
    bottleStyle = sp.getInt(_kBottle) ?? 0;
    tableStyle = sp.getInt(_kTable) ?? 0;
    difficulty = (sp.getInt(_kDifficulty) ?? 0).clamp(0, 2);
    mode = (sp.getInt(_kMode) ?? 0).clamp(0, 2);
    isPro = sp.getBool(_kIsPro) ?? false;

    // Legacy migration: old single best int -> profile.bestClassic, then drop.
    final legacy = sp.getInt(_kLegacyBest);
    _decodeProfile(sp.getString(_kProfileJson));
    if (legacy != null) {
      if (legacy > bestClassic) bestClassic = legacy;
      await sp.remove(_kLegacyBest);
    }

    // Player names: canonical key wins; legacy profile 'name' field migrates.
    final namesRaw = sp.getString(_kNamesJson);
    String? migrated;
    if (namesRaw == null) {
      migrated = _legacyNameFromProfile(sp.getString(_kProfileJson));
    } else {
      migrated = _nameFromNamesJson(namesRaw);
    }
    if (migrated != null && migrated.trim().isNotEmpty) {
      playerName = migrated.trim().substring(0, migrated.trim().length.clamp(0, 20));
      await _saveNames(); // canonicalize under the mandated key
    }

    for (final k in _defaultCustomColors.keys) {
      customColors[k] = sp.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    notifyListeners();
  }

  Future<void> _saveProfile() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProfileJson, jsonEncode(encodeProfile(this)));
  }

  /// Save player names NOW: one JSON array string via setString, on every
  /// keystroke and on focus loss. No keyboard-done dependency.
  Future<void> _saveNames() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kNamesJson, jsonEncode([playerName]));
  }

  /// Read slot 0 from the names JSON array; null when absent/unparseable.
  static String? _nameFromNamesJson(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is List && d.isNotEmpty && d[0] is String) {
        final n = (d[0] as String).trim();
        return n.isEmpty ? null : n;
      }
    } catch (_) {}
    return null;
  }

  /// One-time migration: name stored in the legacy profile JSON object.
  static String? _legacyNameFromProfile(String? raw) {
    if (raw == null) return null;
    try {
      final d = jsonDecode(raw);
      if (d is Map && d['name'] is String) {
        final n = (d['name'] as String).trim();
        return n.isEmpty ? null : n;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _save(String key, Object v) async {
    final sp = await SharedPreferences.getInstance();
    if (v is bool) {
      await sp.setBool(key, v);
    } else if (v is int) {
      await sp.setInt(key, v);
    } else if (v is double) {
      await sp.setDouble(key, v);
    } else if (v is String) {
      await sp.setString(key, v);
    }
  }

  // ---- Mutators (persist + notify) ----
  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save(_kMusic, v);
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save(_kSfx, v);
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save(_kVolume, volume);
  }

  Future<void> setTheme(String id) async {
    themeId = id;
    notifyListeners();
    await _save(_kTheme, id);
  }

  Future<void> setBottleStyle(int i) async {
    bottleStyle = i.clamp(0, bottleStyles.length - 1);
    notifyListeners();
    await _save(_kBottle, bottleStyle);
  }

  Future<void> setTableStyle(int i) async {
    tableStyle = i.clamp(0, tableStyles.length - 1);
    notifyListeners();
    await _save(_kTable, tableStyle);
  }

  Future<void> setDifficulty(int i) async {
    difficulty = i.clamp(0, 2);
    notifyListeners();
    await _save(_kDifficulty, difficulty);
  }

  Future<void> setMode(int i) async {
    mode = i.clamp(0, 2);
    notifyListeners();
    await _save(_kMode, mode);
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    notifyListeners();
    await _save(_kIsPro, v);
  }

  /// Rename: saves the name immediately (every keystroke) to the
  /// order-preserving `flipbottle_player_names_json` key. Called on each
  /// onChanged and again on focus loss; stats stay in the profile JSON.
  Future<void> setPlayerName(String name) async {
    final n = name.trim();
    playerName = n.isEmpty ? 'Flipper' : n.substring(0, n.length.clamp(0, 20));
    notifyListeners();
    await _saveNames();
  }

  Future<void> setCustomColor(String key, int argb) async {
    customColors[key] = argb;
    notifyListeners();
    await _save('$_kCustomPrefix$key', argb);
  }

  /// Record a finished run's stats. Returns true if a new best was set.
  Future<bool> recordRun({
    required int streak,
    required int score,
    required int flips,
    required int perfects,
    required bool isScoreAttack,
    required bool isEndless,
  }) async {
    bool newBest = false;
    gamesPlayed++;
    totalFlips += flips;
    perfectLandings += perfects;
    if (isScoreAttack) {
      if (score > bestScore) {
        bestScore = score;
        newBest = true;
      }
    } else if (isEndless) {
      if (streak > bestEndless) {
        bestEndless = streak;
        newBest = true;
      }
    } else {
      if (streak > bestClassic) {
        bestClassic = streak;
        newBest = true;
      }
    }
    notifyListeners();
    await _saveProfile();
    return newBest;
  }

  Future<void> resetStats() async {
    bestClassic = 0;
    bestEndless = 0;
    bestScore = 0;
    gamesPlayed = 0;
    totalFlips = 0;
    perfectLandings = 0;
    notifyListeners();
    await _saveProfile();
  }

  // ---- Review prompt throttle (max once per day) ----
  Future<bool> shouldPromptReview() async {
    final sp = await SharedPreferences.getInstance();
    final last = sp.getString(_kReviewPromptDate);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return last != today;
  }

  Future<void> markReviewPrompted() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _kReviewPromptDate, DateTime.now().toIso8601String().substring(0, 10));
  }

  // ---- Gating helpers ----
  bool get themeLocked => false; // picker UI decides per-theme
  bool themeUnlocked(String id) {
    final t = flipThemeById(id);
    return !t.proOnly || isPro;
  }

  bool bottleUnlocked(int i) =>
      i < bottleStyles.length && (!bottleStyles[i].proOnly || isPro);

  bool tableUnlocked(int i) =>
      i < tableStyles.length && (!tableStyles[i].proOnly || isPro);

  bool get scoreAttackUnlocked => isPro;
}
