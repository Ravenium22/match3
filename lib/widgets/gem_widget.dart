import 'package:flutter/material.dart';
import '../models/gem.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';

/// Widget that displays a single gem on the game board
/// This is a StatefulWidget because we might want to animate individual gems
class GemWidget extends StatefulWidget {
  final Gem gem;
  final bool isSelected; // Whether this gem is currently selected by the player
  final VoidCallback? onTap; // Callback function when gem is tapped
  final bool shouldGlow; // Whether this gem should show glow effect

  const GemWidget({
    super.key,
    required this.gem,
    this.isSelected = false,
    this.onTap,
    this.shouldGlow = false,
  });

  @override
  State<GemWidget> createState() => _GemWidgetState();
}

class _GemWidgetState extends State<GemWidget> with TickerProviderStateMixin {
  // Animation controllers for various gem animations
  late AnimationController _animationController;
  late AnimationController _dropAnimationController;
  late AnimationController _glowAnimationController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _dropAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize scale animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Scale animation for tap feedback
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Initialize drop animation controller for falling gems
    _dropAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _dropAnimation = Tween<double>(
      begin: -100.0, // Start above screen
      end: 0.0, // End at normal position
    ).animate(CurvedAnimation(
      parent: _dropAnimationController,
      curve: Curves.bounceOut,
    ));

    // Initialize glow animation for special effects
    _glowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start drop animation when gem is first created
    _dropAnimationController.forward();
  }

  @override
  void dispose() {
    // IMPORTANT: Always dispose animation controllers to prevent memory leaks
    _animationController.dispose();
    _dropAnimationController.dispose();
    _glowAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If selection state changed, trigger animation
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }

    // If glow state changed, trigger glow animation
    if (widget.shouldGlow != oldWidget.shouldGlow) {
      if (widget.shouldGlow) {
        _glowAnimationController.repeat(reverse: true);
      } else {
        _glowAnimationController.stop();
        _glowAnimationController.reset();
      }
    }

    // If gem position changed, trigger drop animation (for falling gems)
    if (widget.gem.row != oldWidget.gem.row &&
        widget.gem.row > oldWidget.gem.row) {
      _dropAnimationController.reset();
      _dropAnimationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // GestureDetector wraps our gem to detect taps
      onTap: widget.onTap,
      onTapDown: (_) {
        // Scale down slightly when pressed for tactile feedback
        _animationController.forward();
      },
      onTapUp: (_) {
        // Scale back up when released
        _animationController.reverse();
      },
      onTapCancel: () {
        // Scale back up if tap is cancelled
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _animationController,
          _dropAnimationController,
          _glowAnimationController
        ]),
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // Take the minimum of available width/height to keep square
              final gemSize =
                  constraints.hasBoundedWidth && constraints.hasBoundedHeight
                      ? (constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight)
                      : ResponsiveHelper.getGemSize(context);
              return Transform.translate(
                offset: Offset(0, _dropAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      // Use the gem's color from our GemType extension
                      color: widget.gem.type.color,
                      borderRadius:
                          BorderRadius.circular(GameConstants.borderRadius),
                      // Add border if gem is selected
                      border: widget.isSelected
                          ? Border.all(
                              color: Colors.white,
                              width: 3.0,
                            )
                          : null,
                      // Add shadow for depth with enhanced glow effect
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                        // Glow effect for special gems
                        if (_glowAnimation.value > 0)
                          BoxShadow(
                            color: widget.gem.type.color
                                .withOpacity(_glowAnimation.value * 0.8),
                            blurRadius: 20 * _glowAnimation.value,
                            spreadRadius: 2 * _glowAnimation.value,
                          ),
                      ],
                    ),
                    // Center the gem icon/symbol
                    child: Center(
                      child: _buildGemIcon(gemSize),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Builds the visual representation inside each gem
  /// For now, we'll use simple shapes, but you could use icons or images
  Widget _buildGemIcon(double gemSize) {
    final iconSize = gemSize * 0.6;

    // Different shapes for each gem type to make them more distinguishable
    switch (widget.gem.type) {
      case GemType.red:
        return Icon(
          Icons.favorite,
          color: Colors.white,
          size: iconSize,
        );
      case GemType.blue:
        return Icon(
          Icons.water_drop,
          color: Colors.white,
          size: iconSize,
        );
      case GemType.green:
        return Icon(
          Icons.eco,
          color: Colors.white,
          size: iconSize,
        );
      case GemType.yellow:
        return Icon(
          Icons.star,
          color: Colors.white,
          size: iconSize,
        );
      case GemType.purple:
        return Icon(
          Icons.diamond,
          color: Colors.white,
          size: iconSize,
        );
      case GemType.orange:
        return Icon(
          Icons.local_fire_department,
          color: Colors.white,
          size: iconSize,
        );
      case GemType.blocked:
        return Icon(
          Icons.block,
          color: Colors.white,
          size: iconSize,
        );
    }
  }
}
