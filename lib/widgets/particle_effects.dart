import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget that displays particle effects for combo chains
class ComboParticleEffect extends StatefulWidget {
  final int comboSize;
  final VoidCallback? onComplete;

  const ComboParticleEffect({
    super.key,
    required this.comboSize,
    this.onComplete,
  });

  @override
  State<ComboParticleEffect> createState() => _ComboParticleEffectState();
}

class _ComboParticleEffectState extends State<ComboParticleEffect>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late List<Particle> _particles;
  final int _particleCount = 30;

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _initializeParticles();

    _particleController.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  void _initializeParticles() {
    final random = math.Random();
    final baseColor = _getComboColor();

    _particles = List.generate(_particleCount, (index) {
      final angle = (index / _particleCount) * 2 * math.pi;
      final speed = 50 + random.nextDouble() * 100;
      final size = 2 + random.nextDouble() * 4;

      return Particle(
        startX: 0,
        startY: 0,
        velocityX: math.cos(angle) * speed,
        velocityY: math.sin(angle) * speed,
        size: size,
        color: baseColor.withOpacity(0.7 + random.nextDouble() * 0.3),
        lifespan: 1.0 + random.nextDouble() * 1.0,
      );
    });
  }

  Color _getComboColor() {
    if (widget.comboSize >= 7) return Colors.purple;
    if (widget.comboSize >= 6) return Colors.orange;
    return Colors.yellow;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: ParticlePainter(
            particles: _particles,
            progress: _particleController.value,
          ),
        );
      },
    );
  }
}

/// Represents a single particle in the effect
class Particle {
  final double startX;
  final double startY;
  final double velocityX;
  final double velocityY;
  final double size;
  final Color color;
  final double lifespan;

  Particle({
    required this.startX,
    required this.startY,
    required this.velocityX,
    required this.velocityY,
    required this.size,
    required this.color,
    required this.lifespan,
  });

  double get currentX => startX + velocityX * lifespan;
  double get currentY => startY + velocityY * lifespan;
}

/// Custom painter for particle effects
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (final particle in particles) {
      final particleProgress = (progress * 2).clamp(0.0, 1.0);
      final opacity = 1.0 - particleProgress;

      if (opacity <= 0) continue;

      paint.color = particle.color.withOpacity(opacity);

      final x = centerX + particle.velocityX * particleProgress;
      final y = centerY + particle.velocityY * particleProgress;

      canvas.drawCircle(
        Offset(x, y),
        particle.size * (1.0 - particleProgress * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

/// Overlay widget to display particle effects on top of the game
class ParticleEffectOverlay extends StatefulWidget {
  final Widget child;
  final bool showParticles;
  final int comboSize;
  final VoidCallback? onParticleComplete;

  const ParticleEffectOverlay({
    super.key,
    required this.child,
    required this.showParticles,
    required this.comboSize,
    this.onParticleComplete,
  });

  @override
  State<ParticleEffectOverlay> createState() => _ParticleEffectOverlayState();
}

class _ParticleEffectOverlayState extends State<ParticleEffectOverlay> {
  bool _showingParticles = false;

  @override
  void didUpdateWidget(ParticleEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showParticles && !_showingParticles) {
      _showingParticles = true;
      _triggerParticleEffect();
    }
  }

  void _triggerParticleEffect() {
    setState(() {});
  }

  void _onParticleComplete() {
    setState(() {
      _showingParticles = false;
    });
    widget.onParticleComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showingParticles)
          Positioned.fill(
            child: Center(
              child: ComboParticleEffect(
                comboSize: widget.comboSize,
                onComplete: _onParticleComplete,
              ),
            ),
          ),
      ],
    );
  }
}
