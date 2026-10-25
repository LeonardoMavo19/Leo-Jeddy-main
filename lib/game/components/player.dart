import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'hitbox_component.dart';
import 'tree.dart';

class Player extends HitboxComponent {
  Player({required this.movementInput, required Vector2 position})
    : super(
        footPosition: position,
        hitboxSize: Vector2(28, 48),
        hitboxColor: const Color(0xFF7BE495),
      );

  final Vector2 movementInput;
  static const double speed = 220;

  @override
  void update(double dt) {
    super.update(dt);
    final nextPosition = position + movementInput * speed * dt;

    final worldSize = findGame()!.size * 3;
    nextPosition.x = nextPosition.x
        .clamp(size.x / 2, worldSize.x - size.x / 2)
        .toDouble();
    nextPosition.y = nextPosition.y.clamp(size.y, worldSize.y).toDouble();

    final trees = findGame()!.world.children.whereType<Tree>();
    final horizontalPosition = Vector2(nextPosition.x, position.y);
    if (!_overlapsTreeAt(horizontalPosition, trees)) {
      position.x = horizontalPosition.x;
    }
    final verticalPosition = Vector2(position.x, nextPosition.y);
    if (!_overlapsTreeAt(verticalPosition, trees)) {
      position.y = verticalPosition.y;
    }
    priority = hitboxBottom.round();
  }

  bool _overlapsTreeAt(Vector2 footPosition, Iterable<Tree> trees) {
    return trees.any((tree) => tree.blocksPlayerAt(footPosition, size));
  }
}
