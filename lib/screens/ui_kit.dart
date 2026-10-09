import 'package:flutter/material.dart';
import '../theme/flip_themes.dart';

/// Shared warm, physical UI styling for Flip Bottle.
class FlipUi {
  static BoxDecoration backdrop(FlipThemeDef t) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.skyTop, t.skyBottom],
        ),
      );

  static TextStyle display(double size, FlipThemeDef t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: t.text,
        letterSpacing: 0.5,
        shadows: [
          Shadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 2),
              blurRadius: 4),
        ],
      );

  static TextStyle body(double size, FlipThemeDef t, {Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? t.text,
      );

  static TextStyle label(double size, FlipThemeDef t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: t.muted,
        letterSpacing: 1.2,
      );

  /// Chunky physical button with a bottom "edge" for depth.
  static Widget chunkyButton({
    required FlipThemeDef t,
    required String text,
    required VoidCallback onTap,
    Color? color,
    double fontSize = 18,
    IconData? icon,
    bool enabled = true,
  }) {
    final c = color ?? t.accent;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.black.withValues(alpha: 0.15), width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  offset: const Offset(0, 5),
                  blurRadius: 0),
              BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  offset: const Offset(0, 2),
                  blurRadius: 0,
                  spreadRadius: -1),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: fontSize + 4),
                const SizedBox(width: 8),
              ],
              Text(text,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  static Widget card(FlipThemeDef t, {required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.black.withValues(alpha: 0.08), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, 4),
                blurRadius: 10),
          ],
        ),
        child: child,
      );

  static Widget iconButton(FlipThemeDef t,
      {required IconData icon,
      required VoidCallback onTap,
      String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.7),
            border: Border.all(
                color: Colors.black.withValues(alpha: 0.12), width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(0, 3),
                  blurRadius: 0),
            ],
          ),
          child: Icon(icon, color: t.text, size: 26),
        ),
      ),
    );
  }
}
