import 'package:flutter/material.dart';
import 'dart:math';
import 'gem.dart';

/// Represents the different types of strategic attacks available
enum AttackType {
  blockBomb, // Sends 2-3 blocked tiles to random spots
  rowBlocker, // Blocks an entire random row
  colorWipe, // Removes one random color entirely
}

/// Extension to add properties to AttackType enum
extension AttackTypeExtension on AttackType {
  /// Display name for the attack
  String get name {
    switch (this) {
      case AttackType.blockBomb:
        return 'Block Bomb';
      case AttackType.rowBlocker:
        return 'Row Blocker';
      case AttackType.colorWipe:
        return 'Color Wipe';
    }
  }

  /// Icon representation for the attack
  IconData get icon {
    switch (this) {
      case AttackType.blockBomb:
        return Icons.scatter_plot;
      case AttackType.rowBlocker:
        return Icons.horizontal_rule;
      case AttackType.colorWipe:
        return Icons.palette;
    }
  }

  /// Color theme for the attack
  Color get color {
    switch (this) {
      case AttackType.blockBomb:
        return Colors.orange.shade600;
      case AttackType.rowBlocker:
        return Colors.red.shade600;
      case AttackType.colorWipe:
        return Colors.purple.shade600;
    }
  }

  /// Description of what the attack does
  String get description {
    switch (this) {
      case AttackType.blockBomb:
        return 'Sends 1-2 blocked tiles to random spots';
      case AttackType.rowBlocker:
        return 'Blocks 4-5 random tiles in a row';
      case AttackType.colorWipe:
        return 'Removes one random color for 8 seconds';
    }
  }
}

/// Represents a single attack instance that can be stored in inventory
class Attack {
  final AttackType type;
  final DateTime createdAt;

  Attack({
    required this.type,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Execute this attack on the target game board
  void execute(List<List<Gem?>> targetBoard, int boardSize,
      {Function(GemType, List<Position>)? onColorWipe}) {
    final random = Random();

    switch (type) {
      case AttackType.blockBomb:
        _executeBlockBomb(targetBoard, boardSize, random);
        break;
      case AttackType.rowBlocker:
        _executeRowBlocker(targetBoard, boardSize, random);
        break;
      case AttackType.colorWipe:
        _executeColorWipe(targetBoard, boardSize, random, onColorWipe);
        break;
    }
  }

  /// Execute block bomb attack - place 1-2 blocked tiles randomly
  void _executeBlockBomb(List<List<Gem?>> board, int boardSize, Random random) {
    final blocksToPlace = 1 + random.nextInt(2); // 1-2 blocks
    final emptyPositions = <Position>[];

    // Find all non-blocked positions
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        final gem = board[row][col];
        if (gem == null || gem.type != GemType.blocked) {
          emptyPositions.add(Position(row, col));
        }
      }
    }

    // Place blocks randomly
    emptyPositions.shuffle(random);
    for (int i = 0; i < blocksToPlace && i < emptyPositions.length; i++) {
      final pos = emptyPositions[i];
      board[pos.row][pos.column] = Gem(
        type: GemType.blocked,
        row: pos.row,
        column: pos.column,
      );
    }
  }

  /// Execute row blocker attack - block 4-5 random tiles in a row
  void _executeRowBlocker(
      List<List<Gem?>> board, int boardSize, Random random) {
    final targetRow = random.nextInt(boardSize);
    final tilesToBlock = 4 + random.nextInt(2); // 4-5 tiles

    // Create list of all column positions in the row
    final availableColumns = List.generate(boardSize, (i) => i);
    availableColumns.shuffle(random);

    // Block random tiles in the row
    for (int i = 0; i < tilesToBlock && i < availableColumns.length; i++) {
      final col = availableColumns[i];
      board[targetRow][col] = Gem(
        type: GemType.blocked,
        row: targetRow,
        column: col,
      );
    }
  }

  /// Execute color wipe attack - temporarily remove one random color for 8 seconds
  void _executeColorWipe(List<List<Gem?>> board, int boardSize, Random random,
      Function(GemType, List<Position>)? onColorWipe) {
    // Find all colors currently on the board
    final availableColors = <GemType>{};
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        final gem = board[row][col];
        if (gem != null && gem.type.isPlayable) {
          availableColors.add(gem.type);
        }
      }
    }

    if (availableColors.isEmpty) return;

    // Pick a random color to wipe
    final colorsList = availableColors.toList();
    final targetColor = colorsList[random.nextInt(colorsList.length)];

    // Store positions of removed gems for restoration
    final removedPositions = <Position>[];

    // Remove all instances of that color
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        final gem = board[row][col];
        if (gem?.type == targetColor) {
          board[row][col] = null;
          removedPositions.add(Position(row, col));
        }
      }
    }

    // Notify about the color wipe so it can be restored after 8 seconds
    if (onColorWipe != null && removedPositions.isNotEmpty) {
      onColorWipe(targetColor, removedPositions);
    }
  }
}

/// Tracks combo sequences and timing for attack earning
class ComboTracker {
  final List<DateTime> _comboTimestamps = [];
  int _lastMatchSize = 0;

  /// Record a new combo
  void recordCombo(int matchSize) {
    final now = DateTime.now();
    _comboTimestamps.add(now);
    _lastMatchSize = matchSize;

    // Clean up old timestamps (older than 20 seconds)
    _comboTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp).inSeconds > 20,
    );
  }

  /// Get combos within the last N seconds
  int getCombosInLastSeconds(int seconds) {
    final cutoff = DateTime.now().subtract(Duration(seconds: seconds));
    return _comboTimestamps
        .where((timestamp) => timestamp.isAfter(cutoff))
        .length;
  }

  /// Check what attack (if any) should be earned based on current state
  AttackType? checkForEarnedAttack() {
    // Priority order: Color Wipe > Row Blocker > Block Bomb

    // Color Wipe: 7+ match OR 3 combos within 20 seconds
    if (_lastMatchSize >= 7 || getCombosInLastSeconds(20) >= 3) {
      return AttackType.colorWipe;
    }

    // Row Blocker: 6-match OR 2 combos within 10 seconds
    if (_lastMatchSize >= 6 || getCombosInLastSeconds(10) >= 2) {
      return AttackType.rowBlocker;
    }

    // Block Bomb: 5-match
    if (_lastMatchSize >= 5) {
      return AttackType.blockBomb;
    }

    return null;
  }

  /// Reset combo tracking (called when attack is earned)
  void reset() {
    _comboTimestamps.clear();
    _lastMatchSize = 0;
  }

  /// Get current combo count for display
  int get currentComboCount => _comboTimestamps.length;

  /// Get time until oldest combo expires (for UI countdown)
  Duration? get timeUntilExpiry {
    if (_comboTimestamps.isEmpty) return null;

    final oldest = _comboTimestamps.first;
    final expiry = oldest.add(const Duration(seconds: 20));
    final now = DateTime.now();

    if (expiry.isAfter(now)) {
      return expiry.difference(now);
    }
    return null;
  }

  /// Check if board recovery should trigger (6+ matches within 20 seconds)
  bool checkForBoardRecovery() {
    return getCombosInLastSeconds(20) >= 6;
  }
}

/// Manages a player's attack inventory
class AttackInventory {
  final List<Attack?> _slots = [null, null, null]; // 3 inventory slots
  int _nextSlotIndex = 0; // Round-robin replacement when full

  /// Get all attacks in inventory
  List<Attack?> get attacks => List.unmodifiable(_slots);

  /// Add an attack to inventory
  void addAttack(Attack attack) {
    // Find first empty slot
    for (int i = 0; i < _slots.length; i++) {
      if (_slots[i] == null) {
        _slots[i] = attack;
        return;
      }
    }

    // If no empty slots, replace oldest (round-robin)
    _slots[_nextSlotIndex] = attack;
    _nextSlotIndex = (_nextSlotIndex + 1) % _slots.length;
  }

  /// Use an attack from specific slot
  Attack? useAttack(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= _slots.length) return null;

    final attack = _slots[slotIndex];
    _slots[slotIndex] = null;
    return attack;
  }

  /// Check if inventory has any attacks
  bool get hasAttacks => _slots.any((attack) => attack != null);

  /// Get number of attacks in inventory
  int get attackCount => _slots.where((attack) => attack != null).length;

  /// Clear all attacks
  void clear() {
    for (int i = 0; i < _slots.length; i++) {
      _slots[i] = null;
    }
    _nextSlotIndex = 0;
  }
}
