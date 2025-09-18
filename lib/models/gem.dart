import 'package:flutter/material.dart';
import 'dart:math';

/// Enum defines the different types of gems in our game
/// An enum is a special type that represents a fixed set of values
/// This includes our 6 gem colors plus blocked tiles for PvP attacks
enum GemType {
  red,
  blue,
  green,
  yellow,
  purple,
  orange,
  blocked, // Special tile that can't be moved until cleared
}

/// Extension on GemType to add useful methods
/// Extensions let us add functionality to existing types
extension GemTypeExtension on GemType {
  /// Returns the color associated with each gem type
  /// This method can be called on any GemType value like: GemType.red.color
  Color get color {
    switch (this) {
      case GemType.red:
        return Colors.red.shade600;
      case GemType.blue:
        return Colors.blue.shade600;
      case GemType.green:
        return Colors.green.shade600;
      case GemType.yellow:
        return Colors.yellow.shade700;
      case GemType.purple:
        return Colors.purple.shade600;
      case GemType.orange:
        return Colors.orange.shade600;
      case GemType.blocked:
        return Colors.grey.shade800; // Dark grey for blocked tiles
    }
  }

  /// Returns a display name for each gem type
  String get displayName {
    switch (this) {
      case GemType.red:
        return 'Red';
      case GemType.blue:
        return 'Blue';
      case GemType.green:
        return 'Green';
      case GemType.yellow:
        return 'Yellow';
      case GemType.purple:
        return 'Purple';
      case GemType.orange:
        return 'Orange';
      case GemType.blocked:
        return 'Blocked';
    }
  }

  /// Static method to get a random gem type (excluding blocked tiles)
  /// Static means we can call this without creating an instance
  /// Usage: GemTypeExtension.getRandomType()
  static GemType getRandomType() {
    final random = Random();
    // Only include playable gem types, not blocked tiles
    final playableTypes = [
      GemType.red,
      GemType.blue,
      GemType.green,
      GemType.yellow,
      GemType.purple,
      GemType.orange,
    ];
    return playableTypes[random.nextInt(playableTypes.length)];
  }

  /// Check if this gem type is a normal playable gem (not blocked)
  bool get isPlayable => this != GemType.blocked;
}

/// Represents a single gem on the game board
/// This is a simple data class that holds information about each gem
class Gem {
  final GemType type;
  final int row;
  final int column;

  /// Constructor - creates a new gem
  /// Required parameters are marked with 'required' keyword
  const Gem({
    required this.type,
    required this.row,
    required this.column,
  });

  /// Creates a copy of this gem with some properties changed
  /// This is useful when we need to move a gem to a new position
  /// The ?? operator means "use the provided value, or keep the original if null"
  Gem copyWith({
    GemType? type,
    int? row,
    int? column,
  }) {
    return Gem(
      type: type ?? this.type,
      row: row ?? this.row,
      column: column ?? this.column,
    );
  }

  /// Override equality operator - two gems are equal if they have the same properties
  /// This is useful for comparing gems and finding matches
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Gem &&
        other.type == type &&
        other.row == row &&
        other.column == column;
  }

  /// Override hashCode for proper equality comparison
  /// Required when overriding == operator
  @override
  int get hashCode => type.hashCode ^ row.hashCode ^ column.hashCode;

  /// Override toString for debugging - shows gem info when printed
  @override
  String toString() {
    return 'Gem(type: $type, row: $row, column: $column)';
  }
}

/// Represents a position on the game board
/// Simple class to hold row and column coordinates
class Position {
  final int row;
  final int column;

  const Position(this.row, this.column);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position && other.row == row && other.column == column;
  }

  @override
  int get hashCode => row.hashCode ^ column.hashCode;

  @override
  String toString() => 'Position($row, $column)';
}
