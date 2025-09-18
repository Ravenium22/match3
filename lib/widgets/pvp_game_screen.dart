import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../controllers/game_controller.dart';
import '../models/battle_system.dart';
import '../models/ai_opponent.dart';
import '../utils/responsive.dart';
import 'game_board.dart';
import 'victory_screen.dart';
import 'responsive_layout.dart';
import 'attack_inventory.dart';

/// PvP game screen with complete battle system
class PvPGameScreen extends StatefulWidget {
  final bool isPracticeMode;

  const PvPGameScreen({
    super.key,
    this.isPracticeMode = false,
  });

  @override
  State<PvPGameScreen> createState() => _PvPGameScreenState();
}

class _PvPGameScreenState extends State<PvPGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameController player1Controller;
  late GameController player2Controller;
  late BattleManager battleManager;
  AIOpponent? aiOpponent;

  // Animation controllers for visual effects
  late AnimationController _shakeController;
  late AnimationController _flashController;
  late AnimationController _urgencyController;
  late Animation<double> _shakeAnimation;
  late Animation<Color?> _flashAnimation;
  late Animation<double> _urgencyAnimation;

  String _lastAttackMessage = '';
  bool _showVictoryScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize game controllers
    player1Controller = GameController();
    player2Controller = GameController();

    // Initialize both boards
    player1Controller.initializeBoard();
    player2Controller.initializeBoard();

    // Initialize battle manager
    battleManager = BattleManager();
    battleManager.onStateChanged = () => setState(() {});
    battleManager.onTimeChanged = () => setState(() {});
    battleManager.onCountdownChanged = () => setState(() {});
    battleManager.onBattleEnd = _onBattleEnd;

    // Initialize AI if in practice mode
    if (widget.isPracticeMode) {
      aiOpponent = AIOpponent(player2Controller);
    }

    // Setup animations for visual effects
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _urgencyController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _flashAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red.withValues(alpha: 0.3),
    ).animate(CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeInOut,
    ));

    _urgencyAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _urgencyController,
      curve: Curves.easeInOut,
    ));

    // Start the battle countdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      battleManager.startCountdown();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    battleManager.dispose();
    aiOpponent?.dispose();
    _shakeController.dispose();
    _flashController.dispose();
    _urgencyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        battleManager.pauseBattle();
        aiOpponent?.pause();
        break;
      case AppLifecycleState.resumed:
        battleManager.resumeBattle();
        aiOpponent?.resume();
        break;
      default:
        break;
    }
  }

  /// Handle battle end
  void _onBattleEnd() {
    setState(() {
      _showVictoryScreen = true;
    });
    aiOpponent?.stop();
  }

  /// Handle attack from one player to another
  void _handleAttack(GameController attacker, GameController defender,
      String attackerName, int slotIndex) {
    if (!battleManager.canMakeMove()) return;

    final success = attacker.useAttack(slotIndex, defender);

    if (success) {
      // Record attack statistics
      battleManager.recordAttackUsed(attackerName == 'Player 1');

      // Visual effects
      _triggerAttackEffects();

      // Update message
      setState(() {
        _lastAttackMessage = '$attackerName launched an attack!';
      });

      // Clear message after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _lastAttackMessage = '';
          });
        }
      });
    }
  }

  /// Handle move completion with statistics tracking
  void _onMoveComplete(bool isPlayer1, int score) {
    if (!battleManager.canMakeMove()) return;

    final controller = isPlayer1 ? player1Controller : player2Controller;
    controller.addScore(score);

    // Track largest match for statistics
    int largestMatch = 3; // Default minimum
    if (score > 300) {
      largestMatch = 7; // Rough estimation
    } else if (score > 200) {
      largestMatch = 6;
    } else if (score > 100) {
      largestMatch = 5;
    } else if (score > 50) {
      largestMatch = 4;
    }

    battleManager.recordMove(isPlayer1, score, largestMatch);

    // Start AI on first move if in practice mode
    if (widget.isPracticeMode && aiOpponent != null && battleManager.isActive) {
      aiOpponent!.start();
    }

    setState(() {});
  }

  /// Trigger visual effects for attacks
  void _triggerAttackEffects() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });

    _flashController.forward().then((_) {
      _flashController.reverse();
    });
  }

  /// Reset both games
  void _resetBattle() {
    setState(() {
      player1Controller.resetGame();
      player2Controller.resetGame();
      battleManager.reset();
      aiOpponent?.stop();
      _lastAttackMessage = '';
      _showVictoryScreen = false;
    });

    // Start new countdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      battleManager.startCountdown();
    });
  }

  /// Go back to main menu
  void _backToMenu() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_showVictoryScreen) {
      return Scaffold(
        body: VictoryScreen(
          battleManager: battleManager,
          onPlayAgain: _resetBattle,
          onBackToMenu: _backToMenu,
        ),
      );
    }

    return ResponsiveLayout(
      includeAppBar: true,
      title: widget.isPracticeMode ? 'Practice vs AI' : 'PvP Battle',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _resetBattle,
          tooltip: 'Reset Battle',
        ),
      ],
      child: Stack(
        children: [
          // Main game area with effects
          AnimatedBuilder(
            animation:
                battleManager.isUrgent ? _urgencyAnimation : _shakeAnimation,
            builder: (context, child) {
              final urgencyScale =
                  battleManager.isUrgent ? _urgencyAnimation.value : 1.0;
              final shakeOffset = battleManager.isUrgent
                  ? 0.0
                  : math.sin(
                      _shakeAnimation.value * (1 - 2 * _shakeController.value));

              return Transform.scale(
                scale: urgencyScale,
                child: Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: AnimatedBuilder(
                    animation: _flashAnimation,
                    builder: (context, child) {
                      return Container(
                        color: battleManager.isUrgent
                            ? Colors.red.withValues(
                                alpha: 0.1 * _urgencyAnimation.value,
                              )
                            : _flashAnimation.value,
                        child: Column(
                          children: [
                            // Battle timer
                            BattleTimerWidget(battleManager: battleManager),
                            SizedBox(
                                height: ResponsiveHelper.getSpacing(context)),

                            // Main game layout using responsive layout
                            Expanded(
                              child: ResponsiveGameLayout(
                                playerBoard: _buildPlayerBoard(
                                    player1Controller, 'Player 1', true),
                                opponentBoard: _buildPlayerBoard(
                                    player2Controller, 'Player 2', false),
                                gameUI: _buildGameUI(),
                                sidePanel: _buildAttackPanel(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // Countdown overlay
          CountdownOverlay(battleManager: battleManager),

          // Pause overlay
          if (battleManager.state == BattleState.paused)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pause_circle_filled,
                      color: Colors.white,
                      size: 80,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'GAME PAUSED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Return to the app to continue',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build responsive player board
  Widget _buildPlayerBoard(
      GameController controller, String playerName, bool isPlayer1) {
    final stats =
        isPlayer1 ? battleManager.player1Stats : battleManager.player2Stats;
    final isWinning = isPlayer1
        ? stats.score >= battleManager.player2Stats.score
        : stats.score >= battleManager.player1Stats.score;

    final borderColor =
        isWinning ? Colors.green.shade400 : Colors.blue.shade400;
    final backgroundColor = isWinning
        ? Colors.green.withValues(alpha: 0.1)
        : Colors.blue.withValues(alpha: 0.1);

    return ResponsiveCard(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: backgroundColor,
        ),
        child: Column(
          children: [
            // Player header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getSpacing(context),
                vertical: ResponsiveHelper.getSpacing(context) * 0.5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    playerName,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                    ),
                  ),
                  Text(
                    'Score: ${stats.score}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, 14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Game board (compact) with portrait height cap
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final isPortrait = ResponsiveHelper.isPortrait(context);
                final maxExtent = isPortrait
                    ? ResponsiveHelper.getPortraitMaxBoardExtent(context)
                    : double.infinity;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxExtent),
                  child: GameBoard(
                    controller: controller,
                    onTurnComplete: isPlayer1
                        ? (score) => _onMoveComplete(true, score)
                        : null,
                    compact: true,
                  ),
                );
              }),
            ),

            // Stats row
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getSpacing(context),
                vertical: ResponsiveHelper.getSpacing(context) * 0.5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip('Matches', stats.totalMatches.toString()),
                  _buildStatChip('Combo', stats.biggestCombo.toString()),
                  _buildStatChip(
                      'Attacks', '${stats.attacksUsed}/${stats.attacksEarned}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build game UI (timer, controls, etc.)
  Widget _buildGameUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Attack message
        if (_lastAttackMessage.isNotEmpty)
          ResponsiveCard(
            child: Container(
              padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context)),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastAttackMessage,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.getFontSize(context, 12),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        if (_lastAttackMessage.isNotEmpty)
          SizedBox(height: ResponsiveHelper.getSpacing(context)),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _resetBattle,
              icon: Icon(Icons.refresh,
                  size: ResponsiveHelper.getIconSize(context)),
              label: Text('Reset',
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, 12))),
            ),
            ElevatedButton.icon(
              onPressed: battleManager.state == BattleState.paused
                  ? battleManager.resumeBattle
                  : battleManager.pauseBattle,
              icon: Icon(
                battleManager.state == BattleState.paused
                    ? Icons.play_arrow
                    : Icons.pause,
                size: ResponsiveHelper.getIconSize(context),
              ),
              label: Text(
                battleManager.state == BattleState.paused ? 'Resume' : 'Pause',
                style: TextStyle(
                    fontSize: ResponsiveHelper.getFontSize(context, 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build attack panel
  Widget _buildAttackPanel() {
    return ResponsiveCard(
      child: Column(
        children: [
          Text(
            'Attacks',
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(context, 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getSpacing(context)),
          // Avoid Expanded inside scrollable/constrained parents to prevent
          // unbounded height errors on portrait mobile layouts.
          if (widget.isPracticeMode)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: AttackInventoryWidget(
                  controller: player1Controller,
                  onAttackSelected: (slotIndex) {
                    // Handle attack selection for practice mode
                    _handleAttack(player1Controller, player2Controller,
                        'Player 1', slotIndex);
                  },
                  isEnabled: battleManager.canMakeMove(),
                  compact: true,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Multiplayer attacks coming soon!',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context, 12),
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// Build a stat chip
  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.getSpacing(context),
        vertical: ResponsiveHelper.getSpacing(context) / 2,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(context, 12),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(context, 10),
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
