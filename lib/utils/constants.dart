/// Game constants - all the fixed values used throughout our game
/// Having constants in one place makes it easy to adjust game balance
/// and ensures consistency across the app
library;

class GameConstants {
  // Board dimensions
  static const int boardSize = 8; // 8x8 grid as requested
  static const int minMatchLength = 3; // Minimum gems needed for a match

  // Visual constants
  static const double gemSize = 40.0; // Size of each gem widget
  static const double gemSpacing = 2.0; // Space between gems
  static const double borderRadius = 8.0; // Rounded corners for gems

  // Animation durations (in milliseconds)
  static const int swapAnimationDuration = 300;
  static const int fallAnimationDuration = 500;
  static const int matchAnimationDuration = 200;
  static const int newGemAnimationDuration = 400;

  // Scoring
  static const int baseMatchScore = 100; // Points for a 3-gem match
  static const int bonusPerExtraGem = 50; // Extra points for 4+, 5+, etc.
  static const int cascadeBonusMultiplier = 2; // Bonus for chain reactions

  // Game settings
  static const bool enableAnimations = true;
  static const bool enableSoundEffects =
      false; // We'll keep this simple for now

  // Colors and styling (if we want to customize beyond gem colors)
  static const double boardPadding = 16.0;
  static const double scoreFontSize = 24.0;
}
