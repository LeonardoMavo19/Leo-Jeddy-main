import 'package:flutter/material.dart';

import '../survivors_game.dart';

class VirtualJoystickOverlay extends StatefulWidget {
  const VirtualJoystickOverlay({
    required this.game,
    this.isAiming = false,
    super.key,
  });

  final SurvivorsGame game;
  final bool isAiming;

  @override
  State<VirtualJoystickOverlay> createState() => _VirtualJoystickOverlayState();
}

class _VirtualJoystickOverlayState extends State<VirtualJoystickOverlay> {
  static const double _size = 140;
  static const double _travel = 45;
  Offset _knobOffset = Offset.zero;

  void _updateJoystick(Offset localPosition) {
    final delta = localPosition - const Offset(_size / 2, _size / 2);
    final distance = delta.distance;
    final offset = distance > _travel ? delta * (_travel / distance) : delta;

    setState(() => _knobOffset = offset);
    final x = offset.dx / _travel;
    final y = offset.dy / _travel;
    if (widget.isAiming) {
      widget.game.setAimInput(x, y);
    } else {
      widget.game.setMovementInput(x, y);
    }
  }

  void _releaseJoystick() {
    setState(() => _knobOffset = Offset.zero);
    if (widget.isAiming) {
      widget.game.setAimInput(0, 0);
    } else {
      widget.game.setMovementInput(0, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.game.isGameOver) return const SizedBox.shrink();

    final baseColor = widget.isAiming
        ? const Color(0x66566B52)
        : const Color(0x665A7180);
    final knobColor = widget.isAiming
        ? const Color(0xFFD5A663)
        : const Color(0xFFEAF4F4);

    return SafeArea(
      child: Align(
        alignment: widget.isAiming
            ? Alignment.bottomRight
            : Alignment.bottomLeft,
        child: Padding(
          padding: widget.isAiming
              ? const EdgeInsets.only(right: 24, bottom: 24)
              : const EdgeInsets.only(left: 24, bottom: 24),
          child: GestureDetector(
            key: ValueKey(
              widget.isAiming ? 'aiming-joystick' : 'virtual-joystick',
            ),
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _updateJoystick(details.localPosition),
            onPanUpdate: (details) => _updateJoystick(details.localPosition),
            onPanEnd: (_) => _releaseJoystick(),
            onPanCancel: _releaseJoystick,
            child: SizedBox.square(
              dimension: _size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor,
                      border: const Border.fromBorderSide(
                        BorderSide(color: Colors.white24),
                      ),
                    ),
                    child: const SizedBox.square(dimension: _size),
                  ),
                  Transform.translate(
                    offset: _knobOffset,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: knobColor,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const SizedBox.square(dimension: 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
