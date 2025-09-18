import 'package:flutter/material.dart';
import '../models/battle_system.dart';

/// Victory screen that displays battle results and statistics
class VictoryScreen extends StatelessWidget {
  final BattleManager battleManager;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToMenu;

  const VictoryScreen({
    super.key,
    required this.battleManager,
    required this.onPlayAgain,
    required this.onBackToMenu,
  });

  @override
  Widget build(BuildContext context) {
    final winner = battleManager.winner;
    final player1Stats = battleManager.player1Stats;
    final player2Stats = battleManager.player2Stats;

    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Victory announcement
              _buildVictoryAnnouncement(winner),

              const SizedBox(height: 32),

              // Final scores
              _buildScoreDisplay(player1Stats, player2Stats),

              const SizedBox(height: 32),

              // Battle statistics
              _buildStatistics(player1Stats, player2Stats),

              const SizedBox(height: 32),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the main victory announcement
  Widget _buildVictoryAnnouncement(String? winner) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: winner == null
                  ? [Colors.orange.shade600, Colors.yellow.shade600]
                  : winner == 'Player 1'
                      ? [Colors.blue.shade600, Colors.blue.shade400]
                      : [Colors.red.shade600, Colors.red.shade400],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (winner == null
                        ? Colors.orange
                        : winner == 'Player 1'
                            ? Colors.blue
                            : Colors.red)
                    .withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                winner == null ? 'TIE GAME!' : 'VICTORY!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              if (winner != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$winner Wins!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Victory message
        Text(
          winner == null
              ? 'An epic battle with no clear victor!'
              : 'Congratulations on your strategic victory!',
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build the final score display
  Widget _buildScoreDisplay(PlayerStats player1, PlayerStats player2) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: Column(
        children: [
          Text(
            'FINAL SCORES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPlayerScore(
                    'Player 1', player1.score, player1.score >= player2.score),
              ),
              Container(
                width: 4,
                height: 60,
                color: Colors.grey.shade600,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildPlayerScore(
                    'Player 2', player2.score, player2.score >= player1.score),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual player score
  Widget _buildPlayerScore(String playerName, int score, bool isWinner) {
    return Column(
      children: [
        Text(
          playerName,
          style: TextStyle(
            color: isWinner ? Colors.yellow.shade400 : Colors.grey.shade400,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          score.toString(),
          style: TextStyle(
            color: isWinner ? Colors.yellow.shade400 : Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isWinner)
          Icon(
            Icons.star,
            color: Colors.yellow.shade400,
            size: 20,
          ),
      ],
    );
  }

  /// Build battle statistics section
  Widget _buildStatistics(PlayerStats player1, PlayerStats player2) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        children: [
          Text(
            'BATTLE STATISTICS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Statistics rows
          _buildStatRow(
              'Total Matches', player1.totalMatches, player2.totalMatches),
          _buildStatRow(
              'Biggest Combo', player1.biggestCombo, player2.biggestCombo),
          _buildStatRow(
              'Attacks Used', player1.attacksUsed, player2.attacksUsed),
          _buildStatRow(
              'Attacks Earned', player1.attacksEarned, player2.attacksEarned),
        ],
      ),
    );
  }

  /// Build a single statistics row
  Widget _buildStatRow(String label, int player1Value, int player2Value) {
    final p1Better = player1Value > player2Value;
    final p2Better = player2Value > player1Value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              player1Value.toString(),
              style: TextStyle(
                color: p1Better ? Colors.green.shade400 : Colors.grey.shade400,
                fontSize: 14,
                fontWeight: p1Better ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player2Value.toString(),
              style: TextStyle(
                color: p2Better ? Colors.green.shade400 : Colors.grey.shade400,
                fontSize: 14,
                fontWeight: p2Better ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Play Again button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onPlayAgain,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'PLAY AGAIN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Back to Menu button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onBackToMenu,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'BACK TO MENU',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
