import 'dart:async';
import 'package:flutter/material.dart';

/// Represents the current state of a PvP battle
enum BattleState {
  waiting, // Waiting to start
  countdown, // 3-2-1 countdown
  active, // Battle in progress
  paused, // Battle paused
  finished, // Battle ended
}

/// Tracks statistics for a single player during a battle
class PlayerStats {
  int score = 0;
  int totalMatches = 0;
  int biggestCombo = 0;
  int attacksUsed = 0;
  int attacksEarned = 0;

  void reset() {
    score = 0;
    totalMatches = 0;
    biggestCombo = 0;
    attacksUsed = 0;
    attacksEarned = 0;
  }

  void recordMatch(int matchSize) {
    totalMatches++;
    if (matchSize > biggestCombo) {
      biggestCombo = matchSize;
    }
  }

  void recordAttackUsed() {
    attacksUsed++;
  }

  void recordAttackEarned() {
    attacksEarned++;
  }
}

/// Manages the overall battle timer and match state
class BattleManager {
  static const int battleDurationSeconds = 90;
  static const int countdownSeconds = 3;
  static const int urgencyThresholdSeconds = 10;

  // Battle state
  BattleState _state = BattleState.waiting;
  Timer? _battleTimer;
  Timer? _countdownTimer;

  // Time tracking
  int _remainingSeconds = battleDurationSeconds;
  int _countdownValue = countdownSeconds;
  DateTime? _battleStartTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  // Player stats
  final PlayerStats player1Stats = PlayerStats();
  final PlayerStats player2Stats = PlayerStats();

  // Callbacks
  VoidCallback? onStateChanged;
  VoidCallback? onTimeChanged;
  VoidCallback? onCountdownChanged;
  VoidCallback? onBattleEnd;

  // Getters
  BattleState get state => _state;
  int get remainingSeconds => _remainingSeconds;
  int get countdownValue => _countdownValue;
  bool get isUrgent => _remainingSeconds <= urgencyThresholdSeconds;
  bool get isActive => _state == BattleState.active;
  bool get isFinished => _state == BattleState.finished;

  /// Format remaining time as MM:SS
  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get the winner based on scores (null if tie)
  String? get winner {
    if (!isFinished) return null;

    if (player1Stats.score > player2Stats.score) {
      return 'Player 1';
    } else if (player2Stats.score > player1Stats.score) {
      return 'Player 2';
    } else {
      return null; // Tie
    }
  }

  /// Start the pre-battle countdown
  void startCountdown() {
    if (_state != BattleState.waiting) return;

    _setState(BattleState.countdown);
    _countdownValue = countdownSeconds;
    onCountdownChanged?.call();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownValue--;
      onCountdownChanged?.call();

      if (_countdownValue <= 0) {
        timer.cancel();
        _startBattle();
      }
    });
  }

  /// Start the actual battle after countdown
  void _startBattle() {
    _setState(BattleState.active);
    _battleStartTime = DateTime.now();
    _remainingSeconds = battleDurationSeconds;
    onTimeChanged?.call();

    _battleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == BattleState.paused) return; // Don't count down when paused

      _remainingSeconds--;
      onTimeChanged?.call();

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _endBattle();
      }
    });
  }

  /// End the battle and calculate results
  void _endBattle() {
    _setState(BattleState.finished);
    _battleTimer?.cancel();
    onBattleEnd?.call();
  }

  /// Pause the battle (for app lifecycle)
  void pauseBattle() {
    if (_state != BattleState.active) return;

    _setState(BattleState.paused);
    _pauseStartTime = DateTime.now();
  }

  /// Resume the battle
  void resumeBattle() {
    if (_state != BattleState.paused) return;

    _setState(BattleState.active);

    // Add paused duration to total
    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }
  }

  /// Reset for a new battle
  void reset() {
    _battleTimer?.cancel();
    _countdownTimer?.cancel();

    _setState(BattleState.waiting);
    _remainingSeconds = battleDurationSeconds;
    _countdownValue = countdownSeconds;
    _battleStartTime = null;
    _pausedDuration = Duration.zero;
    _pauseStartTime = null;

    player1Stats.reset();
    player2Stats.reset();
  }

  /// Record a move for statistics
  void recordMove(bool isPlayer1, int score, int matchSize) {
    if (!isActive) return;

    final stats = isPlayer1 ? player1Stats : player2Stats;
    stats.score += score;
    if (matchSize >= 3) {
      stats.recordMatch(matchSize);
    }
  }

  /// Record an attack used
  void recordAttackUsed(bool isPlayer1) {
    if (!isActive) return;

    final stats = isPlayer1 ? player1Stats : player2Stats;
    stats.recordAttackUsed();
  }

  /// Record an attack earned
  void recordAttackEarned(bool isPlayer1) {
    if (!isActive) return;

    final stats = isPlayer1 ? player1Stats : player2Stats;
    stats.recordAttackEarned();
  }

  /// Check if moves are allowed in current state
  bool canMakeMove() {
    return _state == BattleState.active;
  }

  /// Set new state and notify listeners
  void _setState(BattleState newState) {
    if (_state != newState) {
      _state = newState;
      onStateChanged?.call();
    }
  }

  /// Cleanup timers
  void dispose() {
    _battleTimer?.cancel();
    _countdownTimer?.cancel();
  }
}

/// Widget that displays the battle timer
class BattleTimerWidget extends StatelessWidget {
  final BattleManager battleManager;

  const BattleTimerWidget({
    super.key,
    required this.battleManager,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = battleManager.isUrgent;
    final isFinished = battleManager.isFinished;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isFinished
            ? Colors.grey.shade800
            : isUrgent
                ? Colors.red.shade600
                : Colors.blue.shade600,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUrgent ? Colors.red.shade400 : Colors.blue.shade400,
          width: 2,
        ),
        boxShadow: isUrgent
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFinished
                ? Icons.timer_off
                : isUrgent
                    ? Icons.warning
                    : Icons.timer,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isFinished ? 'TIME UP!' : battleManager.formattedTime,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that displays the pre-battle countdown
class CountdownOverlay extends StatelessWidget {
  final BattleManager battleManager;

  const CountdownOverlay({
    super.key,
    required this.battleManager,
  });

  @override
  Widget build(BuildContext context) {
    if (battleManager.state != BattleState.countdown) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'BATTLE STARTS IN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade600,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Text(
                  battleManager.countdownValue.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Get ready to battle!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
