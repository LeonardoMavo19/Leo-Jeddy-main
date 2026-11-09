import 'dart:math';

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
         paint: Paint()..color = Colors.transparent,
       );

  static const double speed = 145;
  final Vector2 _velocity;
  final Player target;
  final VoidCallback onHit;
  double animTime = 0;

  @override
  void update(double dt) {
    super.update(dt);
    position.add(_velocity * dt);
    animTime += dt;

    final closestX = position.x.clamp(target.hitboxLeft, target.hitboxRight);
    final closestY = position.y.clamp(target.hitboxTop, target.hitboxBottom);
    if (position.distanceTo(Vector2(closestX, closestY)) <= radius) {
      onHit();
      removeFromParent();
      return;
    }

    final game = findGame();
    final gameSize = game != null ? game.size * 3 : Vector2.all(99999);
    if (position.x < 0 ||
        position.x > gameSize.x ||
        position.y < 0 ||
        position.y > gameSize.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(radius, radius);

    final r = radius;
    final t = animTime * 8;
    final speedMag = _velocity.length;
    final normDir = speedMag > 0 ? _velocity / speedMag : Vector2(1, 0);

    // Estela de miedo ondulante detrás del proyectil
    for (var i = 1; i <= 3; i++) {
      final offsetDist = i * (r * 0.75);
      final wave = sin(t + i * 1.5) * (r * 0.4);
      final perpX = -normDir.y * wave;
      final perpY = normDir.x * wave;
      final trailX = -normDir.x * offsetDist + perpX;
      final trailY = -normDir.y * offsetDist + perpY;
      final alpha = (0.45 - i * 0.12).clamp(0.05, 1.0);

      canvas.drawCircle(
        Offset(trailX, trailY),
        r * (0.85 - i * 0.2),
        Paint()..color = Color.fromRGBO(175, 75, 245, alpha),
      );
      canvas.drawCircle(
        Offset(trailX, trailY),
        r * (0.55 - i * 0.15),
        Paint()..color = Color.fromRGBO(90, 15, 155, alpha * 0.8),
      );
    }

    // Halo exterior de miedo pulsante
    final pulse = 1.0 + sin(t * 1.2) * 0.15;
    canvas.drawCircle(
      Offset.zero,
      r * 1.45 * pulse,
      Paint()..color = const Color(0x50DF80FF),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 1.15 * pulse,
      Paint()..color = const Color(0x99B335FF),
    );

    // Manto de energía espectral
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = const Color(0xFF7516B5),
    );

    // Núcleo abisal oscuro
    canvas.drawCircle(
      Offset.zero,
      r * 0.65,
      Paint()..color = const Color(0xFF200538),
    );

    // Ojos espectrales amenazantes
    final eyeOffX = normDir.x * (r * 0.25);
    final eyeOffY = normDir.y * (r * 0.25);
    final perpX = -normDir.y * (r * 0.35);
    final perpY = normDir.x * (r * 0.35);

    final eyeGlowPaint = Paint()..color = const Color(0xFFFF3355);
    final eyePupilPaint = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(eyeOffX + perpX, eyeOffY + perpY), 1.8, eyeGlowPaint);
    canvas.drawCircle(Offset(eyeOffX - perpX, eyeOffY - perpY), 1.8, eyeGlowPaint);
    canvas.drawCircle(
      Offset(eyeOffX + perpX + normDir.x * 0.5, eyeOffY + perpY + normDir.y * 0.5),
      0.8,
      eyePupilPaint,
    );
    canvas.drawCircle(
      Offset(eyeOffX - perpX + normDir.x * 0.5, eyeOffY - perpY + normDir.y * 0.5),
      0.8,
      eyePupilPaint,
    );

    canvas.restore();
  }
}
