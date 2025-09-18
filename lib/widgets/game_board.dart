import 'package:flutter/material.dart';
import '../models/gem.dart';
import '../controllers/game_controller.dart';
import '../widgets/gem_widget.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';

/// Main game board widget that displays the 8x8 grid of gems
/// This is where most of the game interaction happens
class GameBoard extends StatefulWidget {
  final GameController? controller; // Optional external controller
  final Function(int score)? onTurnComplete; // Callback when turn completes
  final Future<int> Function(Position, Position)? onSwap; // Custom swap handler
  // When true, render only the square board grid (no score/reset/instructions)
  final bool compact;

  const GameBoard({
    super.key,
    this.controller,
    this.onTurnComplete,
    this.onSwap,
    this.compact = false,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  // For multiple animations

  // Game controller handles all the game logic
  late GameController _gameController;

  // Animation controllers for different game animations
  late AnimationController _swapAnimationController;
  late AnimationController _matchAnimationController;

  // Currently selected gem position
  Position? _selectedPosition;

  // Track if we're currently processing a move (prevents rapid tapping)
  bool _isProcessingMove = false;

  // Track swapping gems for animation
  Position? _swappingGem1;
  Position? _swappingGem2;
  late Animation<double> _swapProgressAnimation;

  @override
  void initState() {
    super.initState();

    // Use external controller if provided, otherwise create new one
    _gameController = widget.controller ?? GameController();
    if (widget.controller == null) {
      _gameController.initializeBoard();
    }

    // Initialize animation controllers
    _swapAnimationController = AnimationController(
      duration: Duration(milliseconds: GameConstants.swapAnimationDuration),
      vsync: this,
    );

    _matchAnimationController = AnimationController(
      duration: Duration(milliseconds: GameConstants.matchAnimationDuration),
      vsync: this,
    );

    // Initialize swap progress animation
    _swapProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _swapAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    // Clean up animation controllers
    _swapAnimationController.dispose();
    _matchAnimationController.dispose();
    super.dispose();
  }

  /// Handle gem tap - either select a gem or attempt to swap with selected gem
  void _onGemTapped(int row, int column) async {
    if (_isProcessingMove) return; // Prevent actions during animations

    Position tappedPosition = Position(row, column);

    if (_selectedPosition == null) {
      // No gem selected yet, select this one
      setState(() {
        _selectedPosition = tappedPosition;
      });
    } else if (_selectedPosition == tappedPosition) {
      // Tapped the same gem, deselect it
      setState(() {
        _selectedPosition = null;
      });
    } else {
      // Try to swap with the selected gem
      await _attemptSwap(_selectedPosition!, tappedPosition);
    }
  }

  /// Attempt to swap two gems and process the resulting matches
  Future<void> _attemptSwap(Position pos1, Position pos2) async {
    setState(() {
      _isProcessingMove = true;
      _selectedPosition = null; // Clear selection
    });

    // Check if gems are adjacent
    if (!_gameController.areAdjacent(pos1, pos2)) {
      setState(() {
        _isProcessingMove = false;
      });
      return;
    }

    // Set up swap animation positions
    _swappingGem1 = pos1;
    _swappingGem2 = pos2;

    // Animate the swap
    await _swapAnimationController.forward();

    // Process the turn and get the score
    int scoreGained;
    if (widget.onSwap != null) {
      // Use custom swap handler
      scoreGained = await widget.onSwap!(pos1, pos2);
    } else {
      // Use default game controller
      scoreGained = await _gameController.processTurn(pos1, pos2);
    }

    if (scoreGained > 0) {
      // Valid move - update score and animate matches
      if (widget.controller == null) {
        // Only add score if using internal controller
        _gameController.addScore(scoreGained);
      }

      // Notify parent if callback provided
      widget.onTurnComplete?.call(scoreGained);

      await _matchAnimationController.forward();
      await _matchAnimationController.reverse();
    }

    // Reset animation
    await _swapAnimationController.reverse();

    // Clear swap positions
    _swappingGem1 = null;
    _swappingGem2 = null;

    setState(() {
      _isProcessingMove = false;
    });
  }

  /// Build the grid of gems
  Widget _buildGameGrid() {
    final spacing = ResponsiveHelper.getSpacing(context);
    final padding = ResponsiveHelper.getPadding(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine the max square board size within available constraints
        final maxBoard = constraints.biggest;
        final boardSize = maxBoard.shortestSide;
        // Compute cell size considering spacing: total spacing across N-1 gaps
        final totalGaps = (GameConstants.boardSize - 1) * spacing;
        final cellSize = (boardSize - totalGaps - padding.horizontal) /
            GameConstants.boardSize;

        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: GameConstants.boardSize,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: 1.0,
            ),
            itemCount: GameConstants.boardSize * GameConstants.boardSize,
            itemBuilder: (context, index) {
              int row = index ~/ GameConstants.boardSize;
              int column = index % GameConstants.boardSize;

              final gem = _gameController.getGemAt(row, column);

              if (gem == null) {
                return const SizedBox.expand();
              }

              bool isSelected = _selectedPosition?.row == row &&
                  _selectedPosition?.column == column;

              final currentPos = Position(row, column);
              final isSwapping =
                  (currentPos == _swappingGem1 || currentPos == _swappingGem2);

              Widget gemWidget = GemWidget(
                gem: gem,
                isSelected: isSelected,
                onTap: () => _onGemTapped(row, column),
              );

              if (isSwapping &&
                  _swappingGem1 != null &&
                  _swappingGem2 != null) {
                return AnimatedBuilder(
                  animation: _swapProgressAnimation,
                  builder: (context, child) {
                    // Use the computed cellSize plus spacing stride for translation
                    final stride = cellSize + spacing;
                    return _buildSwappingGem(gem, currentPos, stride);
                  },
                );
              }

              return gemWidget;
            },
          ),
        );
      },
    );
  }

  /// Build the square board area (AspectRatio 1:1 containing the grid)
  Widget _buildSquareBoardArea() {
    return Center(
      child: AspectRatio(
        // Keep the game board square regardless of screen size
        aspectRatio: 1.0,
        child: _buildGameGrid(),
      ),
    );
  }

  /// Build the score display
  Widget _buildScoreDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.shade300, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            color: Colors.deepPurple.shade700,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            'Score: ${_gameController.score}',
            style: TextStyle(
              fontSize: GameConstants.scoreFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a gem with swap animation applied
  Widget _buildSwappingGem(Gem gem, Position currentPos, double cellSize) {
    if (_swappingGem1 == null || _swappingGem2 == null) {
      return GemWidget(
        gem: gem,
        isSelected: false,
        onTap: () => _onGemTapped(currentPos.row, currentPos.column),
      );
    }

    // Calculate the target position for the swap animation
    Position targetPos;
    if (currentPos == _swappingGem1) {
      targetPos = _swappingGem2!;
    } else {
      targetPos = _swappingGem1!;
    }

    // Calculate the offset based on animation progress
    final deltaRow = targetPos.row - currentPos.row;
    final deltaColumn = targetPos.column - currentPos.column;

    final offsetX = deltaColumn * cellSize * _swapProgressAnimation.value;
    final offsetY = deltaRow * cellSize * _swapProgressAnimation.value;

    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: GemWidget(
        gem: gem,
        isSelected: false,
        onTap: () => _onGemTapped(currentPos.row, currentPos.column),
      ),
    );
  }

  /// Build reset button
  Widget _buildResetButton() {
    return ElevatedButton.icon(
      onPressed: _isProcessingMove
          ? null
          : () {
              setState(() {
                _gameController.resetGame();
                _selectedPosition = null;
              });
            },
      icon: const Icon(Icons.refresh),
      label: const Text('Reset Game'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Compact mode: only render the board area for embedding in other screens
    if (widget.compact) {
      return _buildSquareBoardArea();
    }

    // Full UI mode: include score, reset, and instructions with SafeArea
    return SafeArea(
      child: Column(
        children: [
          // Score display at the top
          _buildScoreDisplay(),
          const SizedBox(height: 12),

          // Main game grid
          Expanded(child: _buildSquareBoardArea()),

          const SizedBox(height: 12),

          // Reset button at the bottom
          _buildResetButton(),

          const SizedBox(height: 8),

          // Instructions for the player
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'How to Play:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1. Tap a gem to select it\n'
                      '2. Tap an adjacent gem to swap\n'
                      '3. Match 3 or more gems in a row/column\n'
                      '4. Gems will fall and new ones spawn from top',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
