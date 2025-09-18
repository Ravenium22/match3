import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/multiplayer_controller.dart';
import '../models/multiplayer_models.dart';
import '../utils/responsive.dart';
import 'multiplayer_game_screen.dart';

/// Lobby screen for multiplayer room management
class MultiplayerLobby extends StatefulWidget {
  final MultiplayerController controller;

  const MultiplayerLobby({
    super.key,
    required this.controller,
  });

  @override
  State<MultiplayerLobby> createState() => _MultiplayerLobbyState();
}

class _MultiplayerLobbyState extends State<MultiplayerLobby> {
  final TextEditingController _roomCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _roomCodeController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});

      // Navigate to game screen if game started
      if (widget.controller.gameStarted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MultiplayerGameScreen(
              controller: widget.controller,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.controller.currentRoom;
    final localPlayer = widget.controller.localPlayer;

    // Show matchmaking screen if searching
    if (widget.controller.isSearching) {
      return _buildMatchmakingScreen();
    }

    if (room == null || localPlayer == null) {
      return _buildMainLobby();
    }

    return _buildRoomLobby(room, localPlayer);
  }

  /// Build the main lobby with room options
  Widget _buildMainLobby() {
    final padding = ResponsiveHelper.getPadding(context);
    final buttonHeight = ResponsiveHelper.getButtonHeight(context);
    final maxContentWidth = ResponsiveHelper.getMaxContentWidth(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: maxContentWidth,
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ONLINE MULTIPLAYER',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Battle players from around the world!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Quick Match button
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: _quickMatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Quick Match',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Create Private Room button
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createPrivateRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create Private Room',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Join Room section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Join Private Room',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _roomCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Room Code',
                            hintText: 'Enter 6-digit code',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _joinRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Join Room'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the room lobby when in a room
  Widget _buildRoomLobby(MultiplayerRoom room, MultiplayerPlayer localPlayer) {
    final opponent = widget.controller.opponent;
    final isReady = localPlayer.isReady;

    return Scaffold(
      appBar: AppBar(
        title: Text(room.isPrivate ? 'Private Room' : 'Quick Match'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveRoom,
            tooltip: 'Leave Room',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Room code display (if private)
              if (room.isPrivate) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Share this code with your friend:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            room.code,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyRoomCode(room.code),
                            tooltip: 'Copy Code',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Players section
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'PLAYERS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Local player
                    _buildPlayerCard(
                      player: localPlayer,
                      isLocal: true,
                      isReady: isReady,
                    ),

                    const SizedBox(height: 16),

                    // Opponent slot
                    opponent != null
                        ? _buildPlayerCard(
                            player: opponent,
                            isLocal: false,
                            isReady: opponent.isReady,
                          )
                        : _buildWaitingSlot(),

                    const Spacer(),

                    // Ready button and game start
                    if (opponent != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _toggleReady,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isReady
                                ? Colors.orange.shade600
                                : Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isReady ? 'Not Ready' : 'Ready to Battle!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (room.allPlayersReady)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade600),
                              const SizedBox(width: 8),
                              Text(
                                widget.controller.isHost
                                    ? 'Starting game...'
                                    : 'Waiting for host to start...',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a player card
  Widget _buildPlayerCard({
    required MultiplayerPlayer player,
    required bool isLocal,
    required bool isReady,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLocal ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocal ? Colors.blue.shade200 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLocal ? Icons.person : Icons.person_outline,
            size: 32,
            color: isLocal ? Colors.blue.shade600 : Colors.grey.shade600,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocal ? 'You' : 'Opponent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isLocal ? Colors.blue.shade600 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  player.displayName ?? 'Player ${player.id.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (player.isHost)
                  Text(
                    'Host',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isReady ? Colors.green.shade600 : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isReady ? 'Ready' : 'Not Ready',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build waiting slot for second player
  Widget _buildWaitingSlot() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_add,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for player...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                  ),
                ),
                Text(
                  'Share the room code to invite a friend',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  /// Quick match - start matchmaking
  Future<void> _quickMatch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.controller.startQuickMatch();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start matchmaking: $e';
        _isLoading = false;
      });
    }
  }

  /// Cancel quick match
  Future<void> _cancelQuickMatch() async {
    try {
      await widget.controller.cancelQuickMatch();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to cancel search: $e';
      });
    }
  }

  /// Create a private room
  Future<void> _createPrivateRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.controller.createRoom(isPrivate: true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create room: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Join a room by code
  Future<void> _joinRoom() async {
    final code = _roomCodeController.text.trim();

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit room code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final joined = await widget.controller.joinRoom(roomCode: code);

      if (!joined) {
        setState(() {
          _errorMessage = 'Room not found or full';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to join room: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Copy room code to clipboard
  void _copyRoomCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room code copied to clipboard!')),
    );
  }

  /// Toggle ready status
  Future<void> _toggleReady() async {
    final localPlayer = widget.controller.localPlayer;
    if (localPlayer != null) {
      await widget.controller.setReady(!localPlayer.isReady);
    }
  }

  /// Leave the current room
  Future<void> _leaveRoom() async {
    await widget.controller.leaveRoom();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Build matchmaking screen
  Widget _buildMatchmakingScreen() {
    final searchTime = widget.controller.searchTime;
    final minutes = searchTime ~/ 60;
    final seconds = searchTime % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated searching indicator
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade600,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'SEARCHING FOR OPPONENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'Finding a worthy opponent...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Search timer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeString,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 64),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _cancelQuickMatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel Search',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
