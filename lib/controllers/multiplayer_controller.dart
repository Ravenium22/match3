import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/firebase_service.dart';
import '../models/multiplayer_models.dart';
import '../models/battle_system.dart';
import '../models/gem.dart';
import '../controllers/game_controller.dart';

/// Controller for managing multiplayer game logic and synchronization
class MultiplayerController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService.instance;

  // Room and player state
  MultiplayerRoom? _currentRoom;
  String? _currentUserId;
  MultiplayerPlayer? _localPlayer;
  MultiplayerPlayer? _opponent;

  // Game controllers
  GameController? _localGameController;
  GameController? _opponentGameController;
  BattleManager? _battleManager;

  // Synchronization state
  StreamSubscription? _roomSubscription;
  StreamSubscription? _gameUpdatesSubscription;
  StreamSubscription? _matchmakingSubscription;
  Timer? _heartbeatTimer;
  Timer? _matchmakingTimer;
  bool _isHost = false;
  bool _gameStarted = false;

  // Matchmaking state
  bool _isSearching = false;
  int _searchTime = 0;

  // Connection state
  bool _isConnected = true;
  bool _opponentDisconnected = false;
  String? _disconnectionReason;

  // Getters
  MultiplayerRoom? get currentRoom => _currentRoom;
  String? get currentUserId => _currentUserId;
  MultiplayerPlayer? get localPlayer => _localPlayer;
  MultiplayerPlayer? get opponent => _opponent;
  GameController? get localGameController => _localGameController;
  GameController? get opponentGameController => _opponentGameController;
  BattleManager? get battleManager => _battleManager;
  bool get isHost => _isHost;
  bool get gameStarted => _gameStarted;
  bool get isConnected => _isConnected;
  bool get opponentDisconnected => _opponentDisconnected;
  String? get disconnectionReason => _disconnectionReason;
  bool get isSearching => _isSearching;
  int get searchTime => _searchTime;

  /// Initialize Firebase and get user ID
  Future<void> initialize() async {
    await _firebaseService.initialize();
    _currentUserId = _firebaseService.currentUserId;
    notifyListeners();
  }

  /// Create a new room (private or quick match)
  Future<MultiplayerRoom> createRoom({bool isPrivate = false}) async {
    if (_currentUserId == null) throw Exception('Not authenticated');

    _currentRoom = await _firebaseService.createRoom(isPrivate: isPrivate);
    _localPlayer = _currentRoom!.players[_currentUserId!];
    _isHost = true;

    _startRoomListening();
    _startHeartbeat();

    notifyListeners();
    return _currentRoom!;
  }

  /// Join an existing room
  Future<bool> joinRoom({String? roomCode}) async {
    if (_currentUserId == null) return false;

    _currentRoom = await _firebaseService.joinRoom(roomCode: roomCode);

    if (_currentRoom == null) return false;

    _localPlayer = _currentRoom!.players[_currentUserId!];
    _opponent = _currentRoom!.getOpponent(_currentUserId!);
    _isHost = _localPlayer?.isHost ?? false;

    _startRoomListening();
    _startHeartbeat();

    notifyListeners();
    return true;
  }

  /// Start quick match search
  Future<void> startQuickMatch() async {
    if (_currentUserId == null) return;

    print('Starting quick match search...');
    _isSearching = true;
    _searchTime = 0;
    notifyListeners();

    try {
      // Add to matchmaking queue
      await _firebaseService.addToMatchmakingQueue();
      print('Added to matchmaking queue');

      // Start search timer
      _startSearchTimer();

      // Listen for matches
      _startMatchListening();

      // Periodically try to create matches
      _startMatchmaking();
    } catch (e) {
      print('Error in startQuickMatch: $e');
      _isSearching = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Cancel quick match search
  Future<void> cancelQuickMatch() async {
    await _firebaseService.removeFromMatchmakingQueue();
    _stopSearching();
  }

  /// Start search timer
  void _startSearchTimer() {
    _matchmakingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _searchTime++;
      notifyListeners();
    });
  }

  /// Start listening for matches
  void _startMatchListening() {
    _matchmakingSubscription =
        _firebaseService.listenForMatch().listen((roomId) {
      if (roomId != null) {
        _onMatchFound(roomId);
      }
    });
  }

  /// Start matchmaking attempts
  void _startMatchmaking() {
    // Only try to create matches after a delay to let others join the queue
    Timer(const Duration(seconds: 3), () {
      if (!_isSearching) return;

      Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!_isSearching) {
          timer.cancel();
          return;
        }
        _tryCreateMatch();
      });
    });
  }

  /// Try to create a match
  void _tryCreateMatch() async {
    print('Trying to create match...');
    try {
      final room = await _firebaseService.findAndCreateMatch();
      if (room != null) {
        print('Match found! Room ID: ${room.id}');
        _onMatchFound(room.id);
      } else {
        print('No match found, continuing search...');
      }
    } catch (e) {
      print('Error in match creation: $e');
      // Continue searching
    }
  }

  /// Handle when match is found
  void _onMatchFound(String roomId) async {
    _stopSearching();

    try {
      // Get room details
      final roomSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('rooms')
          .child(roomId)
          .get();
      if (roomSnapshot.exists) {
        final roomData =
            _castToStringDynamic(roomSnapshot.value as Map<Object?, Object?>);
        _currentRoom = MultiplayerRoom.fromJson(roomData);
        _localPlayer = _currentRoom!.players[_currentUserId!];
        _opponent = _currentRoom!.getOpponent(_currentUserId!);
        _isHost = _localPlayer?.isHost ?? false;

        _startRoomListening();
        _startHeartbeat();

        // Clean up matchmaking queue after successful match
        await _firebaseService.cleanupMatchmaking();

        notifyListeners();
      }
    } catch (e) {
      // Handle error
      print('Error in match found: $e');
      notifyListeners();
    }
  }

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

  /// Stop searching
  void _stopSearching() {
    print('Stopping search...');
    _isSearching = false;
    _searchTime = 0;
    _matchmakingTimer?.cancel();
    _matchmakingSubscription?.cancel();
    notifyListeners();
  }

  /// Set player ready status
  Future<void> setReady(bool ready) async {
    if (_currentRoom == null) return;

    await _firebaseService.setPlayerReady(_currentRoom!.id, ready);
  }

  /// Start the game (host only)
  Future<void> startGame() async {
    if (_currentRoom == null || !_isHost) return;

    // Initialize game controllers
    _localGameController = GameController();
    _opponentGameController = GameController();

    _localGameController!.initializeBoard();
    _opponentGameController!.initializeBoard();

    // Initialize battle manager
    _battleManager = BattleManager();
    _battleManager!.onStateChanged = () => notifyListeners();
    _battleManager!.onTimeChanged = () => notifyListeners();
    _battleManager!.onCountdownChanged = () => notifyListeners();
    _battleManager!.onBattleEnd = _onBattleEnd;

    await _firebaseService.startGame(_currentRoom!.id);

    _gameStarted = true;
    _startGameUpdatesListening();

    notifyListeners();
  }

  /// Make a move and sync with opponent
  Future<bool> makeMove(Position from, Position to) async {
    if (_currentRoom == null || _localGameController == null || !_gameStarted) {
      return false;
    }

    if (!_battleManager!.canMakeMove()) return false;

    // Process move locally first
    final score = await _localGameController!.processTurn(from, to);

    if (score > 0) {
      // Update local battle stats
      _battleManager!.recordMove(true, score, _calculateMatchSize(score));

      // Send update to Firebase
      final update = GameStateUpdate.move(
        playerId: _currentUserId!,
        from: from,
        to: to,
        score: score,
        stats: _battleManager!.player1Stats,
      );

      await _firebaseService.updateGameState(_currentRoom!.id, update);

      notifyListeners();
      return true;
    }

    return false;
  }

  /// Use an attack and sync with opponent
  Future<bool> useAttack(int slotIndex) async {
    if (_currentRoom == null || _localGameController == null || !_gameStarted) {
      return false;
    }

    if (!_battleManager!.canMakeMove()) return false;

    // Use attack locally
    final success =
        _localGameController!.useAttack(slotIndex, _opponentGameController!);

    if (success) {
      // Record attack in battle stats
      _battleManager!.recordAttackUsed(true);

      // Send attack update to Firebase
      final attackData =
          _localGameController!.attackInventory.attacks[slotIndex];

      final update = GameStateUpdate.attack(
        playerId: _currentUserId!,
        attackType: attackData?.type.name ?? '',
        attackData: {
          'slotIndex': slotIndex,
          'targetPlayerId': _opponent?.id ?? '',
        },
        stats: _battleManager!.player1Stats,
      );

      await _firebaseService.updateGameState(_currentRoom!.id, update);

      notifyListeners();
      return true;
    }

    return false;
  }

  /// Calculate match size from score (rough estimation)
  int _calculateMatchSize(int score) {
    if (score > 300) return 7;
    if (score > 200) return 6;
    if (score > 100) return 5;
    if (score > 50) return 4;
    return 3;
  }

  /// Start listening to room updates
  void _startRoomListening() {
    if (_currentRoom == null) return;

    _roomSubscription = _firebaseService.listenToRoom(_currentRoom!.id).listen(
      (room) {
        if (room == null) {
          // Room was deleted
          _handleRoomDeleted();
          return;
        }

        _currentRoom = room;
        _localPlayer = room.players[_currentUserId!];
        _opponent = room.getOpponent(_currentUserId!);

        // Check for disconnections
        _checkForDisconnections();

        // Start game if all players ready and we're host
        if (room.allPlayersReady &&
            _isHost &&
            !_gameStarted &&
            room.state == RoomState.waiting) {
          startGame();
        }

        // Handle game start
        if (room.state == RoomState.playing && !_gameStarted) {
          _handleGameStart();
        }

        // Handle game end
        if (room.state == RoomState.finished && _gameStarted) {
          _handleGameEnd();
        }

        notifyListeners();
      },
      onError: (error) {
        _handleConnectionError(error.toString());
      },
    );
  }

  /// Start listening to game updates
  void _startGameUpdatesListening() {
    if (_currentRoom == null) return;

    _gameUpdatesSubscription =
        _firebaseService.listenToGameUpdates(_currentRoom!.id).listen(
      (updates) {
        for (final update in updates) {
          if (update.playerId != _currentUserId) {
            _handleOpponentUpdate(update);
          }
        }
      },
      onError: (error) {
        _handleConnectionError(error.toString());
      },
    );
  }

  /// Handle opponent's game update
  void _handleOpponentUpdate(GameStateUpdate update) {
    if (_opponentGameController == null || _battleManager == null) return;

    switch (update.type) {
      case GameUpdateType.move:
        _handleOpponentMove(update);
        break;
      case GameUpdateType.attack:
        _handleOpponentAttack(update);
        break;
      case GameUpdateType.boardUpdate:
        _handleOpponentBoardUpdate(update);
        break;
      case GameUpdateType.timerSync:
        _handleTimerSync(update);
        break;
      case GameUpdateType.scoreUpdate:
        // Handle score updates if needed
        break;
    }

    // Update opponent stats
    if (update.playerStats != null) {
      _battleManager!.player2Stats.score = update.playerStats!.score;
      _battleManager!.player2Stats.totalMatches =
          update.playerStats!.totalMatches;
      _battleManager!.player2Stats.biggestCombo =
          update.playerStats!.biggestCombo;
      _battleManager!.player2Stats.attacksUsed =
          update.playerStats!.attacksUsed;
      _battleManager!.player2Stats.attacksEarned =
          update.playerStats!.attacksEarned;
    }

    notifyListeners();
  }

  /// Handle opponent's move
  void _handleOpponentMove(GameStateUpdate update) {
    if (_opponentGameController == null || _battleManager == null) return;

    final fromData = update.data['from'] as Map<String, dynamic>;
    final toData = update.data['to'] as Map<String, dynamic>;
    final score = update.data['score'] as int;

    final from = Position(fromData['row'] as int, fromData['column'] as int);
    final to = Position(toData['row'] as int, toData['column'] as int);

    // Apply move to opponent's controller
    _opponentGameController!.processTurn(from, to);

    // Update battle stats
    _battleManager!.recordMove(false, score, _calculateMatchSize(score));

    // Force UI update
    notifyListeners();
  }

  /// Handle opponent's attack
  void _handleOpponentAttack(GameStateUpdate update) {
    if (_opponentGameController == null ||
        _localGameController == null ||
        _battleManager == null) {
      return;
    }

    final attackData = update.data['attackData'] as Map<String, dynamic>;
    final slotIndex = attackData['slotIndex'] as int;

    // Apply attack to local controller (we are the target)
    _opponentGameController!.useAttack(slotIndex, _localGameController!);

    // Record attack in battle stats
    _battleManager!.recordAttackUsed(false);

    // Force UI update
    notifyListeners();
  }

  /// Handle opponent's board update
  void _handleOpponentBoardUpdate(GameStateUpdate update) {
    // This would be used for more complex board synchronization if needed
    // For now, moves and attacks handle most synchronization
  }

  /// Handle timer synchronization
  void _handleTimerSync(GameStateUpdate update) {
    final remainingSeconds = update.data['remainingSeconds'] as int;
    // Sync local timer with opponent's timer if there's a significant difference
    if (_battleManager != null &&
        (_battleManager!.remainingSeconds - remainingSeconds).abs() > 2) {
      // Adjust local timer to match
      // This would require extending BattleManager to allow timer adjustment
    }
  }

  /// Start heartbeat to detect disconnections
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentRoom != null) {
        _firebaseService.updatePlayerHeartbeat(_currentRoom!.id);
      }
    });
  }

  /// Check for player disconnections
  void _checkForDisconnections() {
    if (_opponent?.isDisconnected == true && !_opponentDisconnected) {
      _opponentDisconnected = true;
      _disconnectionReason = 'Opponent disconnected';
      _battleManager?.pauseBattle();
      notifyListeners();
    } else if (_opponent?.isDisconnected == false && _opponentDisconnected) {
      _opponentDisconnected = false;
      _disconnectionReason = null;
      _battleManager?.resumeBattle();
      notifyListeners();
    }
  }

  /// Handle game start
  void _handleGameStart() {
    if (_gameStarted) return;

    print('Handling game start for ${_isHost ? "host" : "client"}');

    // Initialize game controllers if not host or if controllers don't exist
    if (!_isHost || _localGameController == null) {
      _localGameController = GameController();
      _opponentGameController = GameController();

      _localGameController!.initializeBoard();
      _opponentGameController!.initializeBoard();

      _battleManager = BattleManager();
      _battleManager!.onStateChanged = () => notifyListeners();
      _battleManager!.onTimeChanged = () => notifyListeners();
      _battleManager!.onCountdownChanged = () => notifyListeners();
      _battleManager!.onBattleEnd = _onBattleEnd;

      print('Game controllers initialized for ${_isHost ? "host" : "client"}');
    }

    _gameStarted = true;
    _startGameUpdatesListening();

    // Start countdown
    _battleManager?.startCountdown();

    print('Game started successfully');
    notifyListeners();
  }

  /// Handle game end
  void _handleGameEnd() {
    _gameStarted = false;
    _battleManager?.dispose();
    notifyListeners();
  }

  /// Handle battle end
  void _onBattleEnd() {
    if (_currentRoom == null || _battleManager == null) return;

    final localScore = _battleManager!.player1Stats.score;
    final opponentScore = _battleManager!.player2Stats.score;

    String? winnerId;
    if (localScore > opponentScore) {
      winnerId = _currentUserId;
    } else if (opponentScore > localScore) {
      winnerId = _opponent?.id;
    }

    final finalStats = {
      'player1': _battleManager!.player1Stats.toJson(),
      'player2': _battleManager!.player2Stats.toJson(),
    };

    _firebaseService.endGame(_currentRoom!.id, winnerId, finalStats);
  }

  /// Handle room deletion
  void _handleRoomDeleted() {
    _disconnectionReason = 'Room was deleted';
    _cleanup();
  }

  /// Handle connection errors
  void _handleConnectionError(String error) {
    _isConnected = false;
    _disconnectionReason = 'Connection error: $error';
    notifyListeners();
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    if (_currentRoom != null) {
      await _firebaseService.leaveRoom(_currentRoom!.id);
    }
    _cleanup();
  }

  /// Clean up resources
  void _cleanup() {
    _roomSubscription?.cancel();
    _gameUpdatesSubscription?.cancel();
    _matchmakingSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _matchmakingTimer?.cancel();

    // Clean up matchmaking
    if (_isSearching) {
      _firebaseService.removeFromMatchmakingQueue();
      _stopSearching();
    }

    _currentRoom = null;
    _localPlayer = null;
    _opponent = null;
    _localGameController = null;
    _opponentGameController = null;
    _battleManager?.dispose();
    _battleManager = null;

    _isHost = false;
    _gameStarted = false;
    _isConnected = true;
    _opponentDisconnected = false;
    _disconnectionReason = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
