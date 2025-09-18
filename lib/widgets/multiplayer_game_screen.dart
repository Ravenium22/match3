import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../controllers/multiplayer_controller.dart';
import '../models/battle_system.dart';
import 'game_board.dart';
import 'attack_inventory.dart';
import 'victory_screen.dart';
import '../utils/responsive.dart';

/// Multiplayer game screen with real-time synchronization
class MultiplayerGameScreen extends StatefulWidget {
  final MultiplayerController controller;

  const MultiplayerGameScreen({
    super.key,
    required this.controller,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
    widget.controller.addListener(_onControllerUpdate);

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
      end: 15.0, // Increased intensity
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut, // Changed curve for better effect
    ));

    _flashAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red.withValues(alpha: 0.5), // Increased intensity
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerUpdate);
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
        widget.controller.battleManager?.pauseBattle();
        break;
      case AppLifecycleState.resumed:
        widget.controller.battleManager?.resumeBattle();
        break;
      default:
        break;
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});

      // Check for battle end
      if (widget.controller.battleManager?.isFinished == true &&
          !_showVictoryScreen) {
        setState(() {
          _showVictoryScreen = true;
        });
      }

      // Handle urgency effects for final 10 seconds
      final battleManager = widget.controller.battleManager;
      if (battleManager != null && battleManager.isUrgent) {
        if (!_urgencyController.isAnimating) {
          _urgencyController.repeat(reverse: true);
        }
      } else {
        if (_urgencyController.isAnimating) {
          _urgencyController.stop();
          _urgencyController.reset();
        }
      }

      // Handle disconnection
      if (widget.controller.opponentDisconnected) {
        _showDisconnectionDialog();
      }
    }
  }

  /// Show disconnection dialog
  void _showDisconnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connection Lost'),
        content: Text(
            widget.controller.disconnectionReason ?? 'Opponent disconnected'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _backToMenu();
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  /// Handle attack from local player
  Future<void> _handleAttack(int slotIndex) async {
    final success = await widget.controller.useAttack(slotIndex);

    if (success) {
      // Visual effects
      _triggerAttackEffects();

      // Update message
      setState(() {
        _lastAttackMessage = 'You launched an attack!';
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

  /// Handle move completion with synchronization
  Future<void> _onMoveComplete(int score) async {
    final controller = widget.controller.localGameController;
    if (controller == null) return;

    // The move is already processed by the MultiplayerController
    setState(() {});
  }

  /// Trigger visual effects for attacks
  void _triggerAttackEffects() {
    // Enhanced shake effect with multiple bounces
    _shakeController.forward().then((_) {
      _shakeController.reverse().then((_) {
        // Second smaller shake for extra impact
        _shakeController.forward(from: 0.0).then((_) {
          _shakeController.reverse();
        });
      });
    });

    // Enhanced flash effect with double flash
    _flashController.forward().then((_) {
      _flashController.reverse().then((_) {
        // Quick second flash
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _flashController.forward().then((_) {
              _flashController.reverse();
            });
          }
        });
      });
    });
  }

  /// Reset game and return to lobby
  void _resetBattle() {
    // For multiplayer, we go back to lobby instead of resetting
    _backToLobby();
  }

  /// Go back to lobby
  void _backToLobby() {
    Navigator.of(context).pop();
  }

  /// Go back to main menu
  void _backToMenu() {
    widget.controller.leaveRoom();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final battleManager = widget.controller.battleManager;
    final localController = widget.controller.localGameController;
    final opponentController = widget.controller.opponentGameController;
    final room = widget.controller.currentRoom;
    final opponent = widget.controller.opponent;

    if (_showVictoryScreen && battleManager != null) {
      return Scaffold(
        body: VictoryScreen(
          battleManager: battleManager,
          onPlayAgain: _resetBattle,
          onBackToMenu: _backToMenu,
        ),
      );
    }

    if (battleManager == null ||
        localController == null ||
        opponentController == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Game...'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title:
            Text(room?.isPrivate == true ? 'Private Battle' : 'Online Battle'),
        centerTitle: true,
        actions: [
          // Help button to show attack info without taking persistent space
          IconButton(
            tooltip: 'Attack Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Attack Types'),
                    content: const SingleChildScrollView(child: AttackInfoPanel()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          // Connection indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.controller.isConnected ? Icons.wifi : Icons.wifi_off,
                  color:
                      widget.controller.isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                if (opponent != null)
                  Icon(
                    opponent.isDisconnected ? Icons.person_off : Icons.person,
                    color: opponent.isDisconnected ? Colors.red : Colors.green,
                    size: 20,
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
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
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                // Battle timer
                                BattleTimerWidget(battleManager: battleManager),
                                const SizedBox(height: 8),

                                // Main game layout
                                Expanded(
                                  child: isLandscape
                                      ? _buildLandscapeLayout(localController,
                                          opponentController, battleManager)
                                      : _buildPortraitLayout(localController,
                                          opponentController, battleManager),
                                ),
                              ],
                            ),
                          ),
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
                      'Waiting for connection...',
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

  /// Build layout for landscape orientation
  Widget _buildLandscapeLayout(
      localController, opponentController, battleManager) {
    return Row(
      children: [
        // Local player side
        Expanded(
          child: _buildPlayerSide(
            controller: localController,
            playerName: 'You',
            isLocal: true,
            battleManager: battleManager,
          ),
        ),

        // Center divider with attack message
        Container(
          width: 4,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade400,
                Colors.purple.shade400,
                Colors.red.shade400,
              ],
            ),
          ),
          child: _lastAttackMessage.isNotEmpty
              ? RotatedBox(
                  quarterTurns: 1,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      _lastAttackMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : null,
        ),

        // Opponent side
        Expanded(
          child: _buildPlayerSide(
            controller: opponentController,
            playerName: _getOpponentName(),
            isLocal: false,
            battleManager: battleManager,
          ),
        ),
      ],
    );
  }

  /// Build layout for portrait orientation
  Widget _buildPortraitLayout(
      localController, opponentController, battleManager) {
    return Column(
      children: [
        // Attack message
        if (_lastAttackMessage.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _lastAttackMessage,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Local player side
        Expanded(
          child: _buildPlayerSide(
            controller: localController,
            playerName: 'You',
            isLocal: true,
            battleManager: battleManager,
          ),
        ),

        // Center divider
        Container(
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade400,
                Colors.purple.shade400,
                Colors.red.shade400,
              ],
            ),
          ),
        ),

        // Opponent side
        Expanded(
          child: _buildPlayerSide(
            controller: opponentController,
            playerName: _getOpponentName(),
            isLocal: false,
            battleManager: battleManager,
          ),
        ),

        // Removed persistent bottom AttackInfoPanel to prioritize board size
      ],
    );
  }

  /// Get opponent display name
  String _getOpponentName() {
    final opponent = widget.controller.opponent;
    if (opponent?.displayName != null) {
      return opponent!.displayName!;
    }
    return 'Opponent';
  }

  /// Build one player's side of the screen
  Widget _buildPlayerSide({
    required controller,
    required String playerName,
    required bool isLocal,
    required BattleManager battleManager,
  }) {
    final stats =
        isLocal ? battleManager.player1Stats : battleManager.player2Stats;
    final opponentStats =
        isLocal ? battleManager.player2Stats : battleManager.player1Stats;
    final isWinning = stats.score >= opponentStats.score;

    final borderColor =
        isWinning ? Colors.green.shade400 : Colors.blue.shade400;
    final backgroundColor = isWinning
        ? Colors.green.withValues(alpha: 0.1)
        : Colors.blue.withValues(alpha: 0.1);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: backgroundColor,
      ),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          // Player name and score with battle stats
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    playerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                    ),
                  ),
                  if (isWinning)
                    Icon(Icons.star, color: Colors.yellow.shade600, size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Score: ${stats.score}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                    ),
                  ),
                  Text(
                    'Combos: ${stats.biggestCombo}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Attack inventory (local only) - flexible and scrollable to avoid overflow
          isLocal
              ? Flexible(
                  fit: FlexFit.loose,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: AttackInventoryWidget(
                        controller: controller,
                        onAttackSelected: _handleAttack,
                        isEnabled: battleManager.canMakeMove(),
                        compact: true,
                      ),
                    ),
                  ),
                )
              : Flexible(
                  fit: FlexFit.loose,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 60),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Online Player',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),

          const SizedBox(height: 8),

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
                  onTurnComplete:
                      isLocal ? (score) => _onMoveComplete(score) : null,
                  onSwap: isLocal
                      ? (pos1, pos2) async {
                          if (!battleManager.canMakeMove()) return 0;
                          return await widget.controller.makeMove(pos1, pos2)
                              ? 100
                              : 0; // Return dummy score
                        }
                      : null,
                  compact: true,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
