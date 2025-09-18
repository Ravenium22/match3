import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/multiplayer_models.dart';

/// Firebase service for managing authentication and real-time database operations
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseDatabase get _database => FirebaseDatabase.instance;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  /// Helper method to safely cast Firebase data
  Map<String, dynamic> _castToStringDynamic(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _castToStringDynamic(value));
        } else if (value is List) {
          return MapEntry(
              key.toString(),
              value
                  .map(
                      (item) => item is Map ? _castToStringDynamic(item) : item)
                  .toList());
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }

  /// Initialize Firebase and authenticate anonymously
  Future<void> initialize() async {
    await Firebase.initializeApp();
    await _signInAnonymously();
  }

  /// Sign in anonymously to get a unique user ID
  Future<void> _signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      _currentUserId = userCredential.user?.uid;
    } catch (e) {
      throw Exception('Failed to authenticate: $e');
    }
  }

  /// Generate a 6-digit room code
  String generateRoomCode() {
    final random = math.Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Create a new multiplayer room
  Future<MultiplayerRoom> createRoom({bool isPrivate = false}) async {
    if (_currentUserId == null) throw Exception('Not authenticated');

    final roomCode = isPrivate ? generateRoomCode() : '';
    final roomId =
        isPrivate ? roomCode : _database.ref().child('rooms').push().key!;

    final room = MultiplayerRoom(
      id: roomId,
      code: roomCode,
      hostId: _currentUserId!,
      createdAt: DateTime.now(),
      state: RoomState.waiting,
      isPrivate: isPrivate,
      players: {
        _currentUserId!: MultiplayerPlayer(
          id: _currentUserId!,
          isHost: true,
          isReady: false,
          joinedAt: DateTime.now(),
        ),
      },
    );

    await _database.ref().child('rooms').child(roomId).set(room.toJson());

    // Add to quick match list if not private
    if (!isPrivate) {
      await _database.ref().child('quickMatch').child(roomId).set({
        'createdAt': ServerValue.timestamp,
        'hostId': _currentUserId,
      });
    }

    return room;
  }

  /// Join an existing room by code or find a quick match room
  Future<MultiplayerRoom?> joinRoom({String? roomCode}) async {
    if (_currentUserId == null) throw Exception('Not authenticated');

    if (roomCode != null) {
      return await _joinRoomByCode(roomCode);
    } else {
      // Legacy quick match - return null to indicate no room found
      // New matchmaking system should be used instead
      return null;
    }
  }

  /// Join a specific room by code
  Future<MultiplayerRoom?> _joinRoomByCode(String roomCode) async {
    final snapshot = await _database.ref().child('rooms').child(roomCode).get();

    if (!snapshot.exists) return null;

    print('Firebase snapshot.value type: ${snapshot.value.runtimeType}');
    print('Firebase snapshot.value: ${snapshot.value}');

    final roomData = _castToStringDynamic(snapshot.value);
    print('Converted roomData type: ${roomData.runtimeType}');
    print('Converted roomData: $roomData');

    final room = MultiplayerRoom.fromJson(roomData);

    if (room.players.length >= 2) return null; // Room full

    // Add player to room
    room.players[_currentUserId!] = MultiplayerPlayer(
      id: _currentUserId!,
      isHost: false,
      isReady: false,
      joinedAt: DateTime.now(),
    );

    await _database
        .ref()
        .child('rooms')
        .child(roomCode)
        .child('players')
        .child(_currentUserId!)
        .set(room.players[_currentUserId!]!.toJson());

    return room;
  }

  /// Add player to matchmaking queue
  Future<void> addToMatchmakingQueue() async {
    if (_currentUserId == null) throw Exception('Not authenticated');

    await _database.ref().child('matchmakingQueue').child(_currentUserId!).set({
      'userId': _currentUserId,
      'joinedAt': ServerValue.timestamp,
      'status': 'searching',
    });
  }

  /// Remove player from matchmaking queue
  Future<void> removeFromMatchmakingQueue() async {
    if (_currentUserId == null) return;
    await _database
        .ref()
        .child('matchmakingQueue')
        .child(_currentUserId!)
        .remove();
  }

  /// Listen for matchmaking updates
  Stream<String?> listenForMatch() {
    if (_currentUserId == null) return Stream.value(null);

    return _database
        .ref()
        .child('matchmakingQueue')
        .child(_currentUserId!)
        .child('matchedRoomId')
        .onValue
        .map((event) => event.snapshot.value as String?);
  }

  /// Check for available opponents and create match
  Future<MultiplayerRoom?> findAndCreateMatch() async {
    if (_currentUserId == null) throw Exception('Not authenticated');

    // Look for someone else in the queue (excluding ourselves)
    final snapshot = await _database
        .ref()
        .child('matchmakingQueue')
        .orderByChild('status')
        .equalTo('searching')
        .get();

    if (!snapshot.exists) return null;

    final queueData = _castToStringDynamic(snapshot.value);
    final queueEntries = queueData.entries.toList();

    // Find an opponent (not ourselves and status is searching)
    String? opponentId;
    for (final entry in queueEntries) {
      final entryData = _castToStringDynamic(entry.value);
      if (entry.key != _currentUserId && entryData['status'] == 'searching') {
        opponentId = entry.key;
        break;
      }
    }

    if (opponentId == null) return null;

    // Create room for both players
    final roomId = _database.ref().child('rooms').push().key!;

    final room = MultiplayerRoom(
      id: roomId,
      code: '', // Quick match rooms don't need codes
      hostId: _currentUserId!,
      createdAt: DateTime.now(),
      state: RoomState.waiting,
      isPrivate: false,
      players: {
        _currentUserId!: MultiplayerPlayer(
          id: _currentUserId!,
          isHost: true,
          isReady: true, // Auto-ready for quick match
          joinedAt: DateTime.now(),
        ),
        opponentId: MultiplayerPlayer(
          id: opponentId,
          isHost: false,
          isReady: true, // Auto-ready for quick match
          joinedAt: DateTime.now(),
        ),
      },
    );

    // Create the room
    await _database.ref().child('rooms').child(roomId).set(room.toJson());

    // Update both players' queue entries with room ID
    await _database
        .ref()
        .child('matchmakingQueue')
        .child(_currentUserId!)
        .update({
      'status': 'matched',
      'matchedRoomId': roomId,
    });

    await _database.ref().child('matchmakingQueue').child(opponentId).update({
      'status': 'matched',
      'matchedRoomId': roomId,
    });

    return room;
  }

  /// Clean up matchmaking queue entry
  Future<void> cleanupMatchmaking() async {
    await removeFromMatchmakingQueue();
  }

  /// Listen to room updates
  Stream<MultiplayerRoom?> listenToRoom(String roomId) {
    return _database.ref().child('rooms').child(roomId).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = _castToStringDynamic(event.snapshot.value);
      return MultiplayerRoom.fromJson(data);
    });
  }

  /// Update player ready status
  Future<void> setPlayerReady(String roomId, bool ready) async {
    if (_currentUserId == null) return;

    await _database
        .ref()
        .child('rooms')
        .child(roomId)
        .child('players')
        .child(_currentUserId!)
        .child('isReady')
        .set(ready);
  }

  /// Start the game (host only)
  Future<void> startGame(String roomId) async {
    await _database.ref().child('rooms').child(roomId).update({
      'state': RoomState.playing.name,
      'gameStartedAt': ServerValue.timestamp,
    });
  }

  /// Update game state during gameplay
  Future<void> updateGameState(String roomId, GameStateUpdate update) async {
    if (_currentUserId == null) return;

    final updateData = update.toJson();
    updateData['timestamp'] = ServerValue.timestamp;
    updateData['playerId'] = _currentUserId;

    await _database
        .ref()
        .child('rooms')
        .child(roomId)
        .child('gameState')
        .child('updates')
        .push()
        .set(updateData);

    // Update player stats
    await _database
        .ref()
        .child('rooms')
        .child(roomId)
        .child('gameState')
        .child('players')
        .child(_currentUserId!)
        .set(update.playerStats?.toJson() ?? {});
  }

  /// Listen to game state updates
  Stream<List<GameStateUpdate>> listenToGameUpdates(String roomId) {
    return _database
        .ref()
        .child('rooms')
        .child(roomId)
        .child('gameState')
        .child('updates')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <GameStateUpdate>[];

      final updatesData = _castToStringDynamic(event.snapshot.value);
      return updatesData.values
          .map((data) => GameStateUpdate.fromJson(_castToStringDynamic(data)))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }

  /// Update player's last seen timestamp for disconnection detection
  Future<void> updatePlayerHeartbeat(String roomId) async {
    if (_currentUserId == null) return;

    await _database
        .ref()
        .child('rooms')
        .child(roomId)
        .child('players')
        .child(_currentUserId!)
        .child('lastSeen')
        .set(ServerValue.timestamp);
  }

  /// Leave room and clean up
  Future<void> leaveRoom(String roomId) async {
    if (_currentUserId == null) return;

    // Remove player from room
    await _database
        .ref()
        .child('rooms')
        .child(roomId)
        .child('players')
        .child(_currentUserId!)
        .remove();

    // If room is empty, clean it up
    final snapshot = await _database
        .ref()
        .child('rooms')
        .child(roomId)
        .child('players')
        .get();
    if (!snapshot.exists || _castToStringDynamic(snapshot.value).isEmpty) {
      await _database.ref().child('rooms').child(roomId).remove();
      await _database.ref().child('quickMatch').child(roomId).remove();
    }
  }

  /// End game with final results
  Future<void> endGame(
      String roomId, String? winnerId, Map<String, dynamic> finalStats) async {
    await _database.ref().child('rooms').child(roomId).update({
      'state': RoomState.finished.name,
      'winnerId': winnerId,
      'finalStats': finalStats,
      'gameEndedAt': ServerValue.timestamp,
    });
  }
}
