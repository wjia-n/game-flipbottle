import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const FlipBottleApp());

class FlipBottleApp extends StatelessWidget {
  const FlipBottleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.midnightNeon,
      title: 'Flip Bottle',
      tagline: 'One flick, one perfect landing. Become a bottle-flip legend!',
      emoji: '🍾',
      slug: 'flipbottle',
      howToPlay:
          '• PRESS AND HOLD anywhere to charge your flip.\n• RELEASE to send the bottle flying!\n• Land it UPRIGHT on the next platform to keep your streak.\n• Green zones on the meter = perfect spin. Nail them! 🎯\n• 3 misses and the run is over. How long can you last?',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => FlipBottleScreen(players: players, callbacks: cb),
    );
  }
}
