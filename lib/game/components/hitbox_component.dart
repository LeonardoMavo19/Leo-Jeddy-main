import 'package:flame/components.dart';
import 'package:flutter/material.dart';

abstract class HitboxComponent extends PositionComponent {
  HitboxComponent({
    required Vector2 footPosition,
    required Vector2 hitboxSize,
    required this.hitboxColor,
    int priorityOffset = 0,
  }) : super(
         position: footPosition,
         size: hitboxSize,
         anchor: Anchor.bottomCenter,
         priority: footPosition.y.round() + priorityOffset,
       );

  final Color hitboxColor;
  static const double hitboxStrokeWidth = 2;

  double get hitboxLeft => position.x - size.x / 2;
  double get hitboxRight => position.x + size.x / 2;
  double get hitboxTop => position.y - size.y;
  double get hitboxBottom => position.y;

  bool overlaps(HitboxComponent other) => overlapsAt(position, other);

  bool overlapsAt(Vector2 footPosition, HitboxComponent other) {
    final left = footPosition.x - size.x / 2;
    final right = footPosition.x + size.x / 2;
    final top = footPosition.y - size.y;
    return left < other.hitboxRight &&
        right > other.hitboxLeft &&
        top < other.hitboxBottom &&
        footPosition.y > other.hitboxTop;
  }

  @override
  void update(double dt) {
    super.update(dt);
    priority = position.y.round();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = hitboxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = hitboxStrokeWidth,
    );
    canvas.drawCircle(
      Offset(size.x / 2, size.y),
      3,
      Paint()..color = hitboxColor,
    );
  }
}
