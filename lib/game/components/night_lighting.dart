import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../survivors_game.dart';

class NightLighting extends Component with HasGameReference<SurvivorsGame> {
  NightLighting({required this.worldSize}) : super(priority: 20000) {
    _initFireflies();
  }

  final Vector2 worldSize;
  double _elapsed = 0;
  final List<_Firefly> _fireflies = [];

  void _initFireflies() {
    final rng = Random(123);
    for (var i = 0; i < 35; i++) {
      _fireflies.add(
        _Firefly(
          baseX: rng.nextDouble() * worldSize.x,
          baseY: rng.nextDouble() * worldSize.y,
          speed: 1.0 + rng.nextDouble() * 1.8,
          seed: rng.nextDouble() * 50,
          size: 1.2 + rng.nextDouble() * 1.2,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Luciérnagas nocturnas flotantes
    for (final ff in _fireflies) {
      final fx = (ff.baseX + sin(_elapsed * ff.speed + ff.seed) * 22) % worldSize.x;
      final fy = (ff.baseY + cos(_elapsed * ff.speed * 0.7 + ff.seed) * 18) % worldSize.y;
      final glow = 0.5 + 0.5 * sin(_elapsed * 3.2 + ff.seed);

      final haloPaint = Paint()
        ..color = Color.fromRGBO(204, 242, 89, 0.22 * glow)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(fx, fy), 6 * glow + 2, haloPaint);

      final corePaint = Paint()
        ..color = Color.fromRGBO(255, 255, 165, 0.85 * glow);
      canvas.drawCircle(Offset(fx, fy), ff.size, corePaint);
    }
  }
}

class _Firefly {
  final double baseX;
  final double baseY;
  final double speed;
  final double seed;
  final double size;

  const _Firefly({
    required this.baseX,
    required this.baseY,
    required this.speed,
    required this.seed,
    required this.size,
  });
}

