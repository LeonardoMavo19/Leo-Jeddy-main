import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ForestBackground extends PositionComponent {
  ForestBackground({required Vector2 size})
      : super(size: size, priority: -10) {
    _generateGroundMarks();
  }

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

  final List<_GroundMark> _marks = [];

  void _generateGroundMarks() {
    final rng = Random(42);
    for (var i = 0; i < 350; i++) {
      _marks.add(
        _GroundMark(
          x: rng.nextDouble() * size.x,
          y: rng.nextDouble() * size.y,
          kind: rng.nextInt(4),
          shade: rng.nextDouble(),
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    // Fondo nocturno profundo (verde abeto / medianoche)
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF0B1412));

    final mossPaint = Paint()..color = const Color(0x66081A12);
    final grassPaint = Paint()
      ..color = const Color(0x661E332B)
      ..strokeWidth = 1.0;
    final soilPaint = Paint()..color = const Color(0x8C050A08);
    final pebblePaint = Paint()..color = const Color(0x592E3D42);

    for (final mark in _marks) {
      switch (mark.kind) {
        case 0:
          // Mancha de musgo nocturno
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(mark.x, mark.y),
              width: 26,
              height: 10,
            ),
            mossPaint,
          );
          break;
        case 1:
          // Briznas de hierba iluminadas tenue por la luna
          canvas.drawLine(
            Offset(mark.x - 3, mark.y + 3),
            Offset(mark.x, mark.y - 3),
            grassPaint,
          );
          canvas.drawLine(
            Offset(mark.x, mark.y - 3),
            Offset(mark.x + 4, mark.y + 2),
            grassPaint,
          );
          break;
        case 2:
          // Suelo y sombras de tierra oscura húmeda
          canvas.drawCircle(
            Offset(mark.x, mark.y),
            3 + mark.shade * 4,
            soilPaint,
          );
          break;
        default:
          // Guijarros y motas minerales que reflejan la luz lunar
          canvas.drawCircle(Offset(mark.x, mark.y), 1.5, pebblePaint);
      }
    }
  }
}

class _GroundMark {
  final double x;
  final double y;
  final int kind;
  final double shade;

  const _GroundMark({
    required this.x,
    required this.y,
    required this.kind,
    required this.shade,
  });
}
