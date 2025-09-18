import 'dart:math' as math;
import 'dart:async';
import '../models/gem.dart';
import '../models/attack_system.dart';
import '../utils/constants.dart';

/// Main game controller that handles all game logic
/// This class manages the game state and provides methods for game operations
class GameController {
  // 2D list representing the game board - board[row][column]
  // List<List<Gem?>> means a list of lists of nullable Gems
  List<List<Gem?>> board = [];

  int score = 0;
  Position? selectedGemPosition; // Currently selected gem position

  // New strategic attack system
  final ComboTracker comboTracker = ComboTracker();
  final AttackInventory attackInventory = AttackInventory();

  final math.Random _random = math.Random();

  // Timer for color wipe restoration
  Timer? _colorWipeTimer;
  GemType? _wipedColor;
  List<Position>? _wipedPositions;

  /// Initialize the game board with random gems
  void initializeBoard() {
    board = List.generate(
      GameConstants.boardSize,
      (row) => List.generate(
        GameConstants.boardSize,
        (column) => Gem(
          type: GemTypeExtension.getRandomType(),
          row: row,
          column: column,
        ),
      ),
    );

    // Make sure we don't start with existing matches
    _clearInitialMatches();
  }

  /// Clear any matches that exist on the initial board
  /// We don't want players to start with matches already made
  void _clearInitialMatches() {
    bool hasMatches = true;
    int attempts = 0;
    const maxAttempts = 50; // Prevent infinite loops

    while (hasMatches && attempts < maxAttempts) {
      hasMatches = false;
      attempts++;

      for (int row = 0; row < GameConstants.boardSize; row++) {
        for (int column = 0; column < GameConstants.boardSize; column++) {
          if (_hasMatchAt(row, column)) {
            hasMatches = true;
            // Replace this gem with a different random type
            board[row][column] = Gem(
              type: GemTypeExtension.getRandomType(),
              row: row,
              column: column,
            );
          }
        }
      }
    }
  }

  /// Check if there's a match at the given position
  bool _hasMatchAt(int row, int column) {
    final gem = board[row][column];
    if (gem == null) return false;

    // Check horizontal matches (3 or more in a row)
    int horizontalCount = 1;
    // Count gems to the left
    for (int c = column - 1; c >= 0; c--) {
      if (board[row][c]?.type == gem.type) {
        horizontalCount++;
      } else {
        break;
      }
    }
    // Count gems to the right
    for (int c = column + 1; c < GameConstants.boardSize; c++) {
      if (board[row][c]?.type == gem.type) {
        horizontalCount++;
      } else {
        break;
      }
    }

    // Check vertical matches (3 or more in a column)
    int verticalCount = 1;
    // Count gems above
    for (int r = row - 1; r >= 0; r--) {
      if (board[r][column]?.type == gem.type) {
        verticalCount++;
      } else {
        break;
      }
    }
    // Count gems below
    for (int r = row + 1; r < GameConstants.boardSize; r++) {
      if (board[r][column]?.type == gem.type) {
        verticalCount++;
      } else {
        break;
      }
    }

    return horizontalCount >= GameConstants.minMatchLength ||
        verticalCount >= GameConstants.minMatchLength;
  }

  /// Find all gems that are part of matches and return match information
  /// Returns a map with matched positions and largest match size
  Map<String, dynamic> findMatchesWithSize() {
    Set<Position> matchedPositions = {};
    int largestMatchSize = 0;

    for (int row = 0; row < GameConstants.boardSize; row++) {
      for (int column = 0; column < GameConstants.boardSize; column++) {
        final gem = board[row][column];
        if (gem == null || gem.type == GemType.blocked) {
          continue; // Skip blocked tiles
        }

        // Find horizontal matches
        List<Position> horizontalMatch = [Position(row, column)];
        // Check right
        for (int c = column + 1; c < GameConstants.boardSize; c++) {
          final nextGem = board[row][c];
          if (nextGem?.type == gem.type && nextGem!.type != GemType.blocked) {
            horizontalMatch.add(Position(row, c));
          } else {
            break;
          }
        }

        if (horizontalMatch.length >= GameConstants.minMatchLength) {
          matchedPositions.addAll(horizontalMatch);
          largestMatchSize = math.max(largestMatchSize, horizontalMatch.length);
        }

        // Find vertical matches
        List<Position> verticalMatch = [Position(row, column)];
        // Check down
        for (int r = row + 1; r < GameConstants.boardSize; r++) {
          final nextGem = board[r][column];
          if (nextGem?.type == gem.type && nextGem!.type != GemType.blocked) {
            verticalMatch.add(Position(r, column));
          } else {
            break;
          }
        }

        if (verticalMatch.length >= GameConstants.minMatchLength) {
          matchedPositions.addAll(verticalMatch);
          largestMatchSize = math.max(largestMatchSize, verticalMatch.length);
        }
      }
    }

    return {
      'matches': matchedPositions.toList(),
      'largestMatchSize': largestMatchSize,
    };
  }

  /// Find all gems that are part of matches (legacy method for compatibility)
  List<Position> findMatches() {
    final result = findMatchesWithSize();
    return result['matches'] as List<Position>;
  }

  /// Remove matched gems and update score
  int removeMatches(List<Position> matches) {
    if (matches.isEmpty) return 0;

    // Calculate score for this match
    int matchScore = matches.length * GameConstants.baseMatchScore +
        (matches.length - GameConstants.minMatchLength) *
            GameConstants.bonusPerExtraGem;

    // Remove gems from board
    for (Position position in matches) {
      board[position.row][position.column] = null;
    }

    // Also clear any blocked tiles adjacent to this match
    _clearBlockedTilesAdjacentToMatches(matches);

    return matchScore;
  }

  /// Clear blocked tiles that are adjacent to matched positions
  void _clearBlockedTilesAdjacentToMatches(List<Position> matches) {
    Set<Position> tilesToClear = {};

    for (Position matchPos in matches) {
      // Check all 4 adjacent positions
      final adjacentPositions = [
        Position(matchPos.row - 1, matchPos.column), // Up
        Position(matchPos.row + 1, matchPos.column), // Down
        Position(matchPos.row, matchPos.column - 1), // Left
        Position(matchPos.row, matchPos.column + 1), // Right
      ];

      for (Position adjPos in adjacentPositions) {
        if (_isValidPosition(adjPos)) {
          final gem = board[adjPos.row][adjPos.column];
          if (gem?.type == GemType.blocked) {
            tilesToClear.add(adjPos);
          }
        }
      }
    }

    // Clear the blocked tiles
    for (Position pos in tilesToClear) {
      board[pos.row][pos.column] = null;
    }
  }

  /// Process match and check for attack earning and board recovery
  void processMatchForAttacks(int largestMatchSize) {
    if (largestMatchSize >= 3) {
      // Record the combo
      comboTracker.recordCombo(largestMatchSize);

      // Check for board recovery (6+ matches within 20 seconds)
      if (comboTracker.checkForBoardRecovery()) {
        _clearAllBlockedTiles();
        comboTracker.reset(); // Reset to prevent retriggering immediately
        return; // Skip attack earning when recovery triggers
      }

      // Check if an attack should be earned
      final earnedAttackType = comboTracker.checkForEarnedAttack();
      if (earnedAttackType != null) {
        // Add attack to inventory
        attackInventory.addAttack(Attack(type: earnedAttackType));

        // Reset combo tracker to prevent double-dipping
        comboTracker.reset();
      }
    }
  }

  /// Clear all blocked tiles from the board (board recovery)
  void _clearAllBlockedTiles() {
    for (int row = 0; row < GameConstants.boardSize; row++) {
      for (int col = 0; col < GameConstants.boardSize; col++) {
        final gem = board[row][col];
        if (gem?.type == GemType.blocked) {
          board[row][col] = null;
        }
      }
    }

    // Apply gravity and fill empty spaces
    applyGravity();
    fillEmptySpaces();
  }

  /// Use an attack from inventory on target board
  bool useAttack(int slotIndex, GameController? target) {
    final attack = attackInventory.useAttack(slotIndex);
    if (attack != null && target != null) {
      attack.execute(target.board, GameConstants.boardSize,
          onColorWipe: target._handleColorWipe);
      return true;
    }
    return false;
  }

  /// Handle color wipe effect - store wiped color and positions for restoration
  void _handleColorWipe(GemType wipedColor, List<Position> wipedPositions) {
    // Cancel any existing timer
    _colorWipeTimer?.cancel();

    // Store the wiped color and positions
    _wipedColor = wipedColor;
    _wipedPositions = wipedPositions;

    // Set timer to restore color after 8 seconds
    _colorWipeTimer = Timer(const Duration(seconds: 8), _restoreWipedColor);
  }

  /// Restore the wiped color to empty positions
  void _restoreWipedColor() {
    if (_wipedColor == null || _wipedPositions == null) return;

    for (final position in _wipedPositions!) {
      // Only restore if the position is currently empty
      if (board[position.row][position.column] == null) {
        board[position.row][position.column] = Gem(
          type: _wipedColor!,
          row: position.row,
          column: position.column,
        );
      }
    }

    // Apply gravity to settle the restored gems
    applyGravity();

    // Clear stored data
    _wipedColor = null;
    _wipedPositions = null;
    _colorWipeTimer = null;
  }

  /// Apply gravity - make gems fall down to fill empty spaces
  bool applyGravity() {
    bool changed = false;

    // Process each column from bottom to top
    for (int column = 0; column < GameConstants.boardSize; column++) {
      for (int row = GameConstants.boardSize - 1; row >= 0; row--) {
        if (board[row][column] == null) {
          // Find the nearest gem above this empty space
          for (int r = row - 1; r >= 0; r--) {
            if (board[r][column] != null) {
              // Move gem down
              board[row][column] = board[r][column]!.copyWith(
                row: row,
                column: column,
              );
              board[r][column] = null;
              changed = true;
              break;
            }
          }
        }
      }
    }

    return changed;
  }

  /// Fill empty spaces at the top with new random gems
  bool fillEmptySpaces() {
    bool changed = false;

    for (int column = 0; column < GameConstants.boardSize; column++) {
      for (int row = 0; row < GameConstants.boardSize; row++) {
        if (board[row][column] == null) {
          board[row][column] = Gem(
            type: GemTypeExtension.getRandomType(),
            row: row,
            column: column,
          );
          changed = true;
        }
      }
    }

    return changed;
  }

  /// Check if two gems are adjacent (horizontally or vertically)
  bool areAdjacent(Position pos1, Position pos2) {
    int rowDiff = (pos1.row - pos2.row).abs();
    int columnDiff = (pos1.column - pos2.column).abs();

    // Adjacent means exactly one space away in either row or column, but not both
    return (rowDiff == 1 && columnDiff == 0) ||
        (rowDiff == 0 && columnDiff == 1);
  }

  /// Swap two gems on the board (blocked tiles cannot be moved)
  void swapGems(Position pos1, Position pos2) {
    final gem1 = board[pos1.row][pos1.column];
    final gem2 = board[pos2.row][pos2.column];

    // Don't allow swapping if either gem is blocked
    if (gem1?.type == GemType.blocked || gem2?.type == GemType.blocked) {
      return;
    }

    if (gem1 != null && gem2 != null) {
      board[pos1.row][pos1.column] = gem2.copyWith(
        row: pos1.row,
        column: pos1.column,
      );
      board[pos2.row][pos2.column] = gem1.copyWith(
        row: pos2.row,
        column: pos2.column,
      );
    }
  }

  /// Process a complete turn: swap gems, check for matches, apply gravity, etc.
  /// Returns the total score gained from this turn
  Future<int> processTurn(Position pos1, Position pos2) async {
    if (!areAdjacent(pos1, pos2)) return 0;

    // Try the swap
    swapGems(pos1, pos2);

    // Check if this swap creates any matches
    final matchResult = findMatchesWithSize();
    List<Position> matches = matchResult['matches'] as List<Position>;

    if (matches.isEmpty) {
      // No matches created, swap back
      swapGems(pos1, pos2);
      return 0;
    }

    int totalScore = 0;
    int cascadeMultiplier = 1;
    int largestMatchThisTurn = 0;

    // Keep processing matches until no more are found
    while (matches.isNotEmpty) {
      final currentResult = findMatchesWithSize();
      matches = currentResult['matches'] as List<Position>;
      final largestMatch = currentResult['largestMatchSize'] as int;

      if (matches.isEmpty) break;

      // Track largest match for attack system
      largestMatchThisTurn = math.max(largestMatchThisTurn, largestMatch);

      int matchScore = removeMatches(matches) * cascadeMultiplier;
      totalScore += matchScore;

      // Apply gravity
      applyGravity();

      // Fill empty spaces
      fillEmptySpaces();

      cascadeMultiplier = GameConstants.cascadeBonusMultiplier;
    }

    // Process attacks if any matches were made
    if (largestMatchThisTurn > 0) {
      processMatchForAttacks(largestMatchThisTurn);
    }

    return totalScore;
  }

  /// Check if there are any possible moves on the current board
  bool hasPossibleMoves() {
    for (int row = 0; row < GameConstants.boardSize; row++) {
      for (int column = 0; column < GameConstants.boardSize; column++) {
        Position currentPos = Position(row, column);

        // Check all adjacent positions
        List<Position> adjacentPositions = [
          Position(row - 1, column), // Up
          Position(row + 1, column), // Down
          Position(row, column - 1), // Left
          Position(row, column + 1), // Right
        ];

        for (Position adjacentPos in adjacentPositions) {
          if (_isValidPosition(adjacentPos)) {
            // Temporarily swap and check for matches
            swapGems(currentPos, adjacentPos);
            bool hasMatches = findMatches().isNotEmpty;
            // Swap back
            swapGems(currentPos, adjacentPos);

            if (hasMatches) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Check if a position is valid (within board boundaries)
  bool _isValidPosition(Position position) {
    return position.row >= 0 &&
        position.row < GameConstants.boardSize &&
        position.column >= 0 &&
        position.column < GameConstants.boardSize;
  }

  /// Get gem at specific position
  Gem? getGemAt(int row, int column) {
    if (_isValidPosition(Position(row, column))) {
      return board[row][column];
    }
    return null;
  }

  /// Add score to the total
  void addScore(int points) {
    score += points;
  }

  /// Reset the game
  void resetGame() {
    score = 0;
    selectedGemPosition = null;
    comboTracker.reset();
    attackInventory.clear();

    // Clean up color wipe timer
    _colorWipeTimer?.cancel();
    _colorWipeTimer = null;
    _wipedColor = null;
    _wipedPositions = null;

    initializeBoard();
  }
}
