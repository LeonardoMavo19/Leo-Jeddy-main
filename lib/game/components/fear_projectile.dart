import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'player.dart';

class FearProjectile extends CircleComponent {
  FearProjectile({
    required Vector2 position,
    required Vector2 direction,
    required this.target,
    required this.onHit,
  }) : _velocity = direction * speed,
       super(
         radius: 10,
         position: position,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFCF70FF),
       );

  static const double speed = 145;
  final Vector2 _velocity;
  final Player target;
  final VoidCallback onHit;

  @override
  void update(double dt) {
    super.update(dt);
    position.add(_velocity * dt);

    final closestX = position.x.clamp(target.hitboxLeft, target.hitboxRight);
    final closestY = position.y.clamp(target.hitboxTop, target.hitboxBottom);
    if (position.distanceTo(Vector2(closestX, closestY)) <= radius) {
      onHit();
      removeFromParent();
      return;
    }

    final gameSize = findGame()!.size * 3;
    if (position.x < 0 ||
        position.x > gameSize.x ||
        position.y < 0 ||
        position.y > gameSize.y) {
      removeFromParent();
    }
  }
}
