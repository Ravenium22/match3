import 'package:flutter/material.dart';
import '../models/attack_system.dart';
import '../controllers/game_controller.dart';
import '../utils/responsive.dart';

/// Widget that displays a player's attack inventory with 3 slots
class AttackInventoryWidget extends StatefulWidget {
  final GameController controller;
  final Function(int slotIndex)? onAttackSelected;
  final bool isEnabled;
  // Optional compact flag to shrink visuals further on small screens
  final bool compact;

  const AttackInventoryWidget({
    super.key,
    required this.controller,
    this.onAttackSelected,
    this.isEnabled = true,
    this.compact = false,
  });

  @override
  State<AttackInventoryWidget> createState() => _AttackInventoryWidgetState();
}

class _AttackInventoryWidgetState extends State<AttackInventoryWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _glowControllers;
  late List<Animation<double>> _glowAnimations;
  List<Attack?> _previousAttacks = [null, null, null];

  @override
  void initState() {
    super.initState();

    // Initialize glow animation controllers for each slot
    _glowControllers = List.generate(
        3,
        (index) => AnimationController(
              duration: const Duration(milliseconds: 600),
              vsync: this,
            ));

    _glowAnimations = _glowControllers
        .map((controller) =>
            Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
              parent: controller,
              curve: Curves.easeInOut,
            )))
        .toList();

    // Initialize previous attacks state
    _previousAttacks = List.from(widget.controller.attackInventory.attacks);
  }

  @override
  void dispose() {
    for (final controller in _glowControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(AttackInventoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check for newly earned attacks and trigger glow
    final currentAttacks = widget.controller.attackInventory.attacks;
    for (int i = 0; i < 3; i++) {
      if (_previousAttacks[i] == null && currentAttacks[i] != null) {
        // New attack earned in this slot
        _glowControllers[i].forward().then((_) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              _glowControllers[i].reverse();
            }
          });
        });
      }
    }

    _previousAttacks = List.from(currentAttacks);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'ATTACKS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          // Attack slots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedBuilder(
                  animation: _glowAnimations[index],
                  builder: (context, child) => _buildAttackSlot(context, index),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // Combo counter and timer
          _buildComboInfo(),
        ],
      ),
    );
  }

  /// Build a single attack slot
  Widget _buildAttackSlot(BuildContext context, int slotIndex) {
    final attack = slotIndex < widget.controller.attackInventory.attacks.length
        ? widget.controller.attackInventory.attacks[slotIndex]
        : null;

    final isEmpty = attack == null;
    final glowIntensity = _glowAnimations[slotIndex].value;

    // Size slots responsively; go smaller in compact mode or small screens
  final isMobile = ResponsiveHelper.isMobile(context);
  // Use larger base on mobile; compact still respects 48px min
  final baseSize = isMobile ? 56.0 : 44.0;
  final slotSize = (widget.compact ? baseSize * 0.9 : baseSize).clamp(48.0, 64.0);

    return GestureDetector(
      onTap: widget.isEnabled && !isEmpty
          ? () => widget.onAttackSelected?.call(slotIndex)
          : null,
      child: Container(
        width: slotSize,
        height: slotSize,
        decoration: BoxDecoration(
          color: isEmpty
              ? Colors.grey.shade800
              : attack.type.color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty ? Colors.grey.shade600 : attack.type.color,
            width: 2,
          ),
          boxShadow: isEmpty
              ? null
              : [
                  BoxShadow(
                    color: attack.type.color.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                  // Enhanced glow effect when attack is earned
                  if (glowIntensity > 0)
                    BoxShadow(
                      color: attack.type.color.withOpacity(glowIntensity * 0.8),
                      blurRadius: 15 * glowIntensity,
                      spreadRadius: 3 * glowIntensity,
                    ),
                ],
        ),
        child: isEmpty
            ? Icon(
                Icons.add,
                color: Colors.grey.shade500,
                size: (slotSize * 0.38).clamp(18.0, 24.0),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    attack.type.icon,
                    color: Colors.white,
                    size: (slotSize * 0.36).clamp(16.0, 22.0),
                  ),
                  SizedBox(height: widget.compact ? 1 : 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      _getAttackShortName(attack.type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Build combo counter and timer info
  Widget _buildComboInfo() {
    final comboCount = widget.controller.comboTracker.currentComboCount;
    final timeUntilExpiry = widget.controller.comboTracker.timeUntilExpiry;

    if (comboCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Combo counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${comboCount}x COMBO',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Timer
        if (timeUntilExpiry != null) ...[
          const SizedBox(height: 4),
          Text(
            '${timeUntilExpiry.inSeconds}s',
            style: TextStyle(
              color: timeUntilExpiry.inSeconds <= 5
                  ? Colors.red.shade400
                  : Colors.yellow.shade600,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  /// Get shortened name for attack type
  String _getAttackShortName(AttackType type) {
    switch (type) {
      case AttackType.blockBomb:
        return 'BB';
      case AttackType.rowBlocker:
        return 'RB';
      case AttackType.colorWipe:
        return 'CW';
    }
  }
}

/// Widget showing attack requirements and descriptions
class AttackInfoPanel extends StatelessWidget {
  const AttackInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ATTACK TYPES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          // Block Bomb
          _buildAttackInfo(
            AttackType.blockBomb,
            'Requirement: 5-match combo',
          ),
          const SizedBox(height: 6),

          // Row Blocker
          _buildAttackInfo(
            AttackType.rowBlocker,
            'Requirement: 6-match OR 2 combos in 10s',
          ),
          const SizedBox(height: 6),

          // Color Wipe
          _buildAttackInfo(
            AttackType.colorWipe,
            'Requirement: 7+ match OR 3 combos in 20s',
          ),
        ],
      ),
    );
  }

  Widget _buildAttackInfo(AttackType type, String requirement) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: type.color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            type.icon,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.name,
                style: TextStyle(
                  color: type.color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                type.description,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                ),
              ),
              Text(
                requirement,
                style: TextStyle(
                  color: Colors.yellow.shade600,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
