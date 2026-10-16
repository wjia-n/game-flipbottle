import 'engine/flip_engine.dart';

/// Lets the settings-screen cheat trigger reach the live game engine.
/// The active [GameScreen] registers its engine on init and clears it on
/// dispose; cheat callbacks from outside a run simply no-op.
class CheatEngineBus {
  static FlipEngine? active;
}
