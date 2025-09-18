import 'dart:async';
import 'dart:math' as math;
import '../controllers/game_controller.dart';
import '../models/gem.dart';
import '../utils/constants.dart';

/// Simple AI opponent that makes random valid moves
class AIOpponent {
  final GameController _controller;
  final math.Random _random = math.Random();
  Timer? _moveTimer;
  bool _isActive = false;

  // AI settings
  static const int minMoveDelayMs = 1000; // 1 second
  static const int maxMoveDelayMs = 2000; // 2 seconds

  AIOpponent(this._controller);

  /// Start the AI opponent
  void start() {
    if (_isActive) return;
    _isActive = true;
    _schedulNextMove();
  }

  /// Stop the AI opponent
  void stop() {
    _isActive = false;
    _moveTimer?.cancel();
    _moveTimer = null;
  }

  /// Pause the AI (when game is paused)
  void pause() {
    _moveTimer?.cancel();
    _moveTimer = null;
  }

  /// Resume the AI (when game is unpaused)
  void resume() {
    if (_isActive) {
      _schedulNextMove();
    }
  }

  /// Schedule the next AI move
  void _schedulNextMove() {
    if (!_isActive) return;

    final delay =
        minMoveDelayMs + _random.nextInt(maxMoveDelayMs - minMoveDelayMs);

    _moveTimer = Timer(Duration(milliseconds: delay), () {
      if (_isActive) {
        _makeMove();
        _schedulNextMove();
      }
    });
  }

  /// Make a random valid move
  void _makeMove() {
    final validMoves = _findValidMoves();

    if (validMoves.isNotEmpty) {
      final move = validMoves[_random.nextInt(validMoves.length)];
      _controller.processTurn(move.pos1, move.pos2);
    }
  }

  /// Find all valid moves on the current board
  List<_Move> _findValidMoves() {
    final moves = <_Move>[];

    for (int row = 0; row < GameConstants.boardSize; row++) {
      for (int col = 0; col < GameConstants.boardSize; col++) {
        final currentPos = Position(row, col);
        final currentGem = _controller.getGemAt(row, col);

        // Skip if no gem or blocked tile
        if (currentGem == null || currentGem.type == GemType.blocked) continue;

        // Check all adjacent positions
        final adjacentPositions = [
          Position(row - 1, col), // Up
          Position(row + 1, col), // Down
          Position(row, col - 1), // Left
          Position(row, col + 1), // Right
        ];

        for (final adjPos in adjacentPositions) {
          if (_isValidPosition(adjPos)) {
            final adjGem = _controller.getGemAt(adjPos.row, adjPos.column);

            // Skip if no gem or blocked tile
            if (adjGem == null || adjGem.type == GemType.blocked) continue;

            // Test if this swap would create a match
            if (_wouldCreateMatch(currentPos, adjPos)) {
              moves.add(_Move(currentPos, adjPos));
            }
          }
        }
      }
    }

    return moves;
  }

  /// Check if a position is valid (within board boundaries)
  bool _isValidPosition(Position pos) {
    return pos.row >= 0 &&
        pos.row < GameConstants.boardSize &&
        pos.column >= 0 &&
        pos.column < GameConstants.boardSize;
  }

  /// Test if swapping two positions would create a match
  bool _wouldCreateMatch(Position pos1, Position pos2) {
    // Get current gems
    final gem1 = _controller.getGemAt(pos1.row, pos1.column);
    final gem2 = _controller.getGemAt(pos2.row, pos2.column);

    if (gem1 == null || gem2 == null) return false;
    if (gem1.type == GemType.blocked || gem2.type == GemType.blocked) {
      return false;
    }

    // Temporarily swap gems in memory (not on actual board)
    final tempBoard = _copyBoard();
    tempBoard[pos1.row][pos1.column] =
        gem2.copyWith(row: pos1.row, column: pos1.column);
    tempBoard[pos2.row][pos2.column] =
        gem1.copyWith(row: pos2.row, column: pos2.column);

    // Check if either position would have a match after swap
    return _hasMatchAt(tempBoard, pos1.row, pos1.column) ||
        _hasMatchAt(tempBoard, pos2.row, pos2.column);
  }

  /// Create a copy of the current board
  List<List<Gem?>> _copyBoard() {
    return List.generate(
      GameConstants.boardSize,
      (row) => List.generate(
        GameConstants.boardSize,
        (col) => _controller.getGemAt(row, col),
      ),
    );
  }

  /// Check if there's a match at the given position on the given board
  bool _hasMatchAt(List<List<Gem?>> board, int row, int col) {
    final gem = board[row][col];
    if (gem == null || gem.type == GemType.blocked) return false;

    // Check horizontal matches
    int horizontalCount = 1;

    // Count left
    for (int c = col - 1; c >= 0; c--) {
      final leftGem = board[row][c];
      if (leftGem?.type == gem.type && leftGem!.type != GemType.blocked) {
        horizontalCount++;
      } else {
        break;
      }
    }

    // Count right
    for (int c = col + 1; c < GameConstants.boardSize; c++) {
      final rightGem = board[row][c];
      if (rightGem?.type == gem.type && rightGem!.type != GemType.blocked) {
        horizontalCount++;
      } else {
        break;
      }
    }

    if (horizontalCount >= GameConstants.minMatchLength) return true;

    // Check vertical matches
    int verticalCount = 1;

    // Count up
    for (int r = row - 1; r >= 0; r--) {
      final upGem = board[r][col];
      if (upGem?.type == gem.type && upGem!.type != GemType.blocked) {
        verticalCount++;
      } else {
        break;
      }
    }

    // Count down
    for (int r = row + 1; r < GameConstants.boardSize; r++) {
      final downGem = board[r][col];
      if (downGem?.type == gem.type && downGem!.type != GemType.blocked) {
        verticalCount++;
      } else {
        break;
      }
    }

    return verticalCount >= GameConstants.minMatchLength;
  }

  /// Cleanup resources
  void dispose() {
    stop();
  }
}

/// Simple data class to represent a potential move
class _Move {
  final Position pos1;
  final Position pos2;

  _Move(this.pos1, this.pos2);
}
