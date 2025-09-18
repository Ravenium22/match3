import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/game_board.dart';
import 'widgets/pvp_game_screen.dart';
import 'widgets/multiplayer_lobby.dart';
import 'controllers/multiplayer_controller.dart';
import 'utils/responsive.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const Match3Game());
}

/// Main application widget - this is the entry point for our Flutter app
/// In Flutter, everything is a widget! StatelessWidget means this widget
/// doesn't change its state internally
class Match3Game extends StatelessWidget {
  const Match3Game({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp provides the basic structure for a Material Design app
    // It handles theming, navigation, and other app-level concerns
    return MaterialApp(
      title: 'Match 3 Game',
      theme: ThemeData(
        // Material 3 design system with a purple color scheme
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Remove the debug banner in the top-right corner
      debugShowCheckedModeBanner: false,
      // Set our menu screen as the home page
      home: const MenuScreen(),
    );
  }
}

/// Menu screen to choose between single player and PvP modes
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  /// Navigate to multiplayer lobby
  void _navigateToMultiplayer(BuildContext context) async {
    final controller = MultiplayerController();

    try {
      await controller.initialize();

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerLobby(controller: controller),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Match 3 Game'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = ResponsiveHelper.getPadding(context);
            final buttonHeight = ResponsiveHelper.getButtonHeight(context);
            final titleSize = ResponsiveHelper.getFontSize(context, 32);
            final subtitleSize = ResponsiveHelper.getFontSize(context, 16);
            final gap = ResponsiveHelper.isMobile(context) ? 12.0 : 16.0;
            final largeGap = ResponsiveHelper.isMobile(context) ? 24.0 : 32.0;

            return SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - padding.vertical,
                ),
                child: Center(
                  child: SizedBox(
                    width: ResponsiveHelper.getMaxContentWidth(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Game title
                        Text(
                          'MATCH 3 BATTLE',
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: gap),
                        Text(
                          'Create combos to attack your opponent!',
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: largeGap),

                        // Single Player button
                        SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const GameScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Single Player',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        SizedBox(height: gap),

                        // Practice vs AI button
                        SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const PvPGameScreen(
                                        isPracticeMode: true)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Practice vs AI',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        SizedBox(height: gap),

                        // Online Multiplayer button
                        SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            onPressed: () => _navigateToMultiplayer(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Online Multiplayer',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: gap),

                        // Local PvP Mode button
                        SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PvPGameScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Local PvP',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        SizedBox(height: largeGap),

                        // Game features
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'Battle Features:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '• Block Bomb (5-match): Sends 2-3 blocked tiles\n'
                                '• Row Blocker (6-match/2 combos): Blocks entire row\n'
                                '• Color Wipe (7+ match/3 combos): Removes color\n'
                                '• 90-second battle timer with real-time scoring\n'
                                '• Practice mode vs AI • Online multiplayer battles\n'
                                '• Private rooms with 6-digit codes • Quick match',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Main game screen - this is where our match-3 game will be displayed
/// StatefulWidget because the game state will change (score, board, etc.)
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// The actual implementation of our game screen
/// State<GameScreen> means this class manages the state for GameScreen
class _GameScreenState extends State<GameScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold provides the basic layout structure (app bar, body, etc.)
      appBar: AppBar(
        // AppBar is the top bar of our app
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Single Player'),
        centerTitle: true,
      ),
      body: const SafeArea(
        // SafeArea ensures our content doesn't overlap with system UI
        // like the status bar or home indicator on phones
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Score display will go here
              Text(
                'Score: 0',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20), // Adds vertical spacing
              // Game board will go here
              Expanded(
                // Expanded makes the GameBoard take up remaining space
                child: GameBoard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
