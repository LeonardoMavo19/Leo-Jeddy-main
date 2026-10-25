import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'hitbox_component.dart';

class Tree extends HitboxComponent {
  static const double trunkWidth = 16;
  static const double trunkHeight = 12;

  Tree({required super.footPosition, double scale = 1})
    : super(
        hitboxSize: Vector2(30 * scale, 68 * scale),
        hitboxColor: const Color(0xFFB5E48C),
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
}
