import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ForestBackground extends PositionComponent {
  ForestBackground({required Vector2 size}) : super(size: size, priority: -10);

  static const trees = <(double, double, double)>[
    (0.08, 0.12, 1.0),
    (0.28, 0.08, 0.72),
    (0.53, 0.15, 0.86),
    (0.78, 0.09, 1.12),
    (0.94, 0.23, 0.76),
    (0.13, 0.41, 0.72),
    (0.9, 0.52, 1.0),
    (0.06, 0.73, 1.08),
    (0.31, 0.88, 0.9),
    (0.59, 0.82, 1.12),
    (0.83, 0.91, 0.86),
  ];

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF294B35));
  }
}
