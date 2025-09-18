import '../models/battle_system.dart';
import '../models/gem.dart';

/// Represents the state of a multiplayer room
enum RoomState {
  waiting, // Waiting for players to join
  ready, // All players ready, about to start
  playing, // Game in progress
  paused, // Game paused due to disconnection
  finished, // Game completed
}

/// Represents a player in a multiplayer room
class MultiplayerPlayer {
  final String id;
  final bool isHost;
  final bool isReady;
  final DateTime joinedAt;
  final DateTime? lastSeen;
  final String? displayName;

  const MultiplayerPlayer({
    required this.id,
    required this.isHost,
    required this.isReady,
    required this.joinedAt,
    this.lastSeen,
    this.displayName,
  });

  factory MultiplayerPlayer.fromJson(Map<String, dynamic> json) {
    return MultiplayerPlayer(
      id: json['id'] as String,
      isHost: json['isHost'] as bool? ?? false,
      isReady: json['isReady'] as bool? ?? false,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(json['joinedAt'] as int),
      lastSeen: json['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int)
          : null,
      displayName: json['displayName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isHost': isHost,
      'isReady': isReady,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      if (lastSeen != null) 'lastSeen': lastSeen!.millisecondsSinceEpoch,
      if (displayName != null) 'displayName': displayName,
    };
  }

  /// Check if player is considered disconnected (no heartbeat for 10 seconds)
  bool get isDisconnected {
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!).inSeconds > 10;
  }

  MultiplayerPlayer copyWith({
    String? id,
    bool? isHost,
    bool? isReady,
    DateTime? joinedAt,
    DateTime? lastSeen,
    String? displayName,
  }) {
    return MultiplayerPlayer(
      id: id ?? this.id,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      displayName: displayName ?? this.displayName,
    );
  }
}

/// Represents a multiplayer room
class MultiplayerRoom {
  final String id;
  final String code; // 6-digit code for private rooms
  final String hostId;
  final DateTime createdAt;
  final RoomState state;
  final bool isPrivate;
  final Map<String, MultiplayerPlayer> players;
  final DateTime? gameStartedAt;
  final DateTime? gameEndedAt;
  final String? winnerId;
  final Map<String, dynamic>? finalStats;

  const MultiplayerRoom({
    required this.id,
    required this.code,
    required this.hostId,
    required this.createdAt,
    required this.state,
    required this.isPrivate,
    required this.players,
    this.gameStartedAt,
    this.gameEndedAt,
    this.winnerId,
    this.finalStats,
  });

  factory MultiplayerRoom.fromJson(Map<String, dynamic> json) {
    final playersData = json['players'] as Map<String, dynamic>? ?? {};
    final players = <String, MultiplayerPlayer>{};

    for (final entry in playersData.entries) {
      players[entry.key] = MultiplayerPlayer.fromJson(
          Map<String, dynamic>.from(entry.value as Map<Object?, Object?>));
    }

    return MultiplayerRoom(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      hostId: json['hostId'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      state: RoomState.values.firstWhere(
        (e) => e.name == (json['state'] as String? ?? 'waiting'),
        orElse: () => RoomState.waiting,
      ),
      isPrivate: json['isPrivate'] as bool? ?? false,
      players: players,
      gameStartedAt: json['gameStartedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['gameStartedAt'] as int)
          : null,
      gameEndedAt: json['gameEndedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['gameEndedAt'] as int)
          : null,
      winnerId: json['winnerId'] as String?,
      finalStats: json['finalStats'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'hostId': hostId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'state': state.name,
      'isPrivate': isPrivate,
      'players': players.map((key, value) => MapEntry(key, value.toJson())),
      if (gameStartedAt != null)
        'gameStartedAt': gameStartedAt!.millisecondsSinceEpoch,
      if (gameEndedAt != null)
        'gameEndedAt': gameEndedAt!.millisecondsSinceEpoch,
      if (winnerId != null) 'winnerId': winnerId,
      if (finalStats != null) 'finalStats': finalStats,
    };
  }

  /// Check if room is full (2 players)
  bool get isFull => players.length >= 2;

  /// Check if all players are ready
  bool get allPlayersReady =>
      players.values.every((p) => p.isReady) && players.length == 2;

  /// Get the other player (not the current user)
  MultiplayerPlayer? getOpponent(String currentUserId) {
    return players.values.firstWhere(
      (p) => p.id != currentUserId,
      orElse: () => players.values.first,
    );
  }

  /// Check if any player is disconnected
  bool get hasDisconnectedPlayer => players.values.any((p) => p.isDisconnected);
}

/// Represents different types of game state updates
enum GameUpdateType {
  move, // Player made a move (swap)
  attack, // Player used an attack
  scoreUpdate, // Score changed
  boardUpdate, // Board state changed
  timerSync, // Timer synchronization
}

/// Represents a game state update to sync between players
class GameStateUpdate {
  final GameUpdateType type;
  final String playerId;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final PlayerStats? playerStats;

  const GameStateUpdate({
    required this.type,
    required this.playerId,
    required this.timestamp,
    required this.data,
    this.playerStats,
  });

  factory GameStateUpdate.fromJson(Map<String, dynamic> json) {
    return GameStateUpdate(
      type: GameUpdateType.values.firstWhere(
        (e) => e.name == (json['type'] as String),
        orElse: () => GameUpdateType.move,
      ),
      playerId: json['playerId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      data: Map<String, dynamic>.from(json['data'] as Map<Object?, Object?>),
      playerStats: json['playerStats'] != null
          ? PlayerStatsJson.fromJson(Map<String, dynamic>.from(
              json['playerStats'] as Map<Object?, Object?>))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'playerId': playerId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'data': data,
      if (playerStats != null) 'playerStats': playerStats!.toJson(),
    };
  }

  /// Create a move update
  static GameStateUpdate move({
    required String playerId,
    required Position from,
    required Position to,
    required int score,
    required PlayerStats stats,
  }) {
    return GameStateUpdate(
      type: GameUpdateType.move,
      playerId: playerId,
      timestamp: DateTime.now(),
      data: {
        'from': {'row': from.row, 'column': from.column},
        'to': {'row': to.row, 'column': to.column},
        'score': score,
      },
      playerStats: stats,
    );
  }

  /// Create an attack update
  static GameStateUpdate attack({
    required String playerId,
    required String attackType,
    required Map<String, dynamic> attackData,
    required PlayerStats stats,
  }) {
    return GameStateUpdate(
      type: GameUpdateType.attack,
      playerId: playerId,
      timestamp: DateTime.now(),
      data: {
        'attackType': attackType,
        'attackData': attackData,
      },
      playerStats: stats,
    );
  }

  /// Create a board update
  static GameStateUpdate boardUpdate({
    required String playerId,
    required List<List<Map<String, dynamic>>> boardState,
    required PlayerStats stats,
  }) {
    return GameStateUpdate(
      type: GameUpdateType.boardUpdate,
      playerId: playerId,
      timestamp: DateTime.now(),
      data: {
        'boardState': boardState,
      },
      playerStats: stats,
    );
  }

  /// Create a timer sync update
  static GameStateUpdate timerSync({
    required String playerId,
    required int remainingSeconds,
  }) {
    return GameStateUpdate(
      type: GameUpdateType.timerSync,
      playerId: playerId,
      timestamp: DateTime.now(),
      data: {
        'remainingSeconds': remainingSeconds,
      },
    );
  }
}

/// Extension to add JSON serialization to PlayerStats
extension PlayerStatsJson on PlayerStats {
  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'totalMatches': totalMatches,
      'biggestCombo': biggestCombo,
      'attacksUsed': attacksUsed,
      'attacksEarned': attacksEarned,
    };
  }

  static PlayerStats fromJson(Map<String, dynamic> json) {
    final stats = PlayerStats();
    stats.score = json['score'] as int? ?? 0;
    stats.totalMatches = json['totalMatches'] as int? ?? 0;
    stats.biggestCombo = json['biggestCombo'] as int? ?? 0;
    stats.attacksUsed = json['attacksUsed'] as int? ?? 0;
    stats.attacksEarned = json['attacksEarned'] as int? ?? 0;
    return stats;
  }
}
