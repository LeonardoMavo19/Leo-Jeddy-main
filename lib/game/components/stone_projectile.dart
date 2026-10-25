import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'enemy.dart';

class StoneProjectile extends CircleComponent {
  StoneProjectile({
    required Vector2 position,
    required Vector2 direction,
    required this.onHit,
  }) : _velocity = direction * speed,
       super(
         radius: 7,
         position: position,
         anchor: Anchor.center,
         priority: 4,
         paint: Paint()..color = const Color(0xFFB7A18A),
       );

  static const double speed = 390;
  final Vector2 _velocity;
  final ValueChanged<Enemy> onHit;

  @override
  void update(double dt) {
    super.update(dt);
    position.add(_velocity * dt);

    for (final enemy in findGame()!.world.children.whereType<Enemy>()) {
      final closestX = position.x.clamp(enemy.hitboxLeft, enemy.hitboxRight);
      final closestY = position.y.clamp(enemy.hitboxTop, enemy.hitboxBottom);
      if (position.distanceTo(Vector2(closestX, closestY)) <= radius) {
        onHit(enemy);
        removeFromParent();
        return;
      }
    }

    final gameSize = findGame()!.size * 3;
    if (position.x < 0 ||
        position.x > gameSize.x ||
        position.y < 0 ||
        position.y > gameSize.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      Offset(radius * 0.32, -radius * 0.3),
      radius * 0.28,
      Paint()..color = const Color(0xFFFFE2B9),
    );
  }
}
