import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'hitbox_component.dart';
import 'player.dart';

class Enemy extends HitboxComponent {
  Enemy({
    required this.target,
    required this.onShoot,
    required Vector2 position,
  }) : super(
         footPosition: position,
         hitboxSize: Vector2(26, 34),
         hitboxColor: const Color(0xFFFF8A80),
       );

  final Player target;
  final void Function(Enemy enemy) onShoot;
  static const double speed = 76;
  static const double fireRate = 2.4;
  double _shootTimer = 1.2;

  @override
  void update(double dt) {
    super.update(dt);
    _shootTimer -= dt;
    final offset = target.position - position;

    if (offset.length2 > 0) {
      position.add(offset.normalized() * speed * dt);
    }
    priority = hitboxBottom.round();

    if (_shootTimer <= 0) {
      onShoot(this);
      _shootTimer = fireRate;
    }
  }
}
