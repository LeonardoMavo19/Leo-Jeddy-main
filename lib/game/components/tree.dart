import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'hitbox_component.dart';

class Tree extends HitboxComponent {
  static const double trunkWidth = 12;
  static const double trunkHeight = 9;
  final double scale;

  Tree({required super.footPosition, this.scale = 1})
    : super(
        hitboxSize: Vector2(22 * scale, 50 * scale),
        hitboxColor: Colors.transparent,
      );

  double get trunkLeft => position.x - trunkWidth / 2;
  double get trunkRight => position.x + trunkWidth / 2;
  double get trunkTop => position.y - trunkHeight;

  bool blocksPlayerAt(Vector2 footPosition, Vector2 playerSize) {
    final playerLeft = footPosition.x - playerSize.x / 2;
    final playerRight = footPosition.x + playerSize.x / 2;
    const playerFootHeight = 6.0;
    final playerTop = footPosition.y - playerFootHeight;
    return playerLeft < trunkRight &&
        playerRight > trunkLeft &&
        playerTop < position.y &&
        footPosition.y > trunkTop;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    final s = scale * 0.75;

    // Sombra del árbol en el suelo (noche profunda)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -2 * s), width: 52 * s, height: 15 * s),
      Paint()..color = const Color(0x99050A08),
    );

    // Tronco de corteza oscura nocturna
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-7 * s, -25 * s, 14 * s, 25 * s),
        Radius.circular(4 * s),
      ),
      Paint()..color = const Color(0xFF1E1712),
    );
    // Veta de corteza
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-3 * s, -23 * s, 3 * s, 20 * s),
        Radius.circular(1 * s),
      ),
      Paint()..color = const Color(0xFF2E241A),
    );

    // Follaje nocturno en capas (pino de medianoche)
    final darkLeaves = Paint()..color = const Color(0xFF09140F);
    canvas.drawCircle(Offset(0, -48 * s), 23 * s, darkLeaves);
    canvas.drawCircle(Offset(-14 * s, -43 * s), 16 * s, darkLeaves);
    canvas.drawCircle(Offset(14 * s, -43 * s), 16 * s, darkLeaves);

    final midLeaves = Paint()..color = const Color(0xFF0F2018);
    canvas.drawCircle(Offset(-3 * s, -51 * s), 18 * s, midLeaves);
    canvas.drawCircle(Offset(12 * s, -48 * s), 12 * s, midLeaves);

    // Brillo plateado de luz de luna en la copa superior
    canvas.drawCircle(
      Offset(-9 * s, -58 * s),
      7 * s,
      Paint()..color = const Color(0xB2244238),
    );

    canvas.restore();
  }
}
