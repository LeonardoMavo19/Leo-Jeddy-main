import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'enemy.dart';

class StoneProjectile extends CircleComponent {
  StoneProjectile({
    required Vector2 position,
    required Vector2 direction,
    required this.onHit,
    double radius = 7,
    double projectileSpeed = 390,
    this.pierce = 1,
    this.bounce = 0,
  }) : _speed = projectileSpeed,
       _velocity = direction * projectileSpeed,
       super(
         radius: radius,
         position: position,
         anchor: Anchor.center,
         priority: 4,
         paint: Paint()..color = Colors.transparent,
       );

  final double _speed;
  Vector2 _velocity;
  final ValueChanged<Enemy> onHit;
  double rotationAngle = 0;
  static const double spinRate = 14;
  int pierce;
  int bounce;
  final Set<Enemy> _hitEnemies = {};

  @override
  void update(double dt) {
    super.update(dt);
    position.add(_velocity * dt);
    rotationAngle += spinRate * dt;

    final game = findGame();
    if (game == null) return;

    for (final enemy in game.world.children.whereType<Enemy>()) {
      if (_hitEnemies.contains(enemy)) continue;
      final closestX = position.x.clamp(enemy.hitboxLeft, enemy.hitboxRight);
      final closestY = position.y.clamp(enemy.hitboxTop, enemy.hitboxBottom);
      if (position.distanceTo(Vector2(closestX, closestY)) <= radius) {
        _hitEnemies.add(enemy);
        onHit(enemy);
        pierce--;

        if (pierce <= 0) {
          if (bounce > 0) {
            bounce--;
            pierce = 1;
            // Buscar enemigo más cercano
            Enemy? nearest;
            double minDist = double.infinity;
            for (final other in game.world.children.whereType<Enemy>()) {
              if (other != enemy && !_hitEnemies.contains(other)) {
                final d = position.distanceTo(other.position);
                if (d < minDist) {
                  minDist = d;
                  nearest = other;
                }
              }
            }
            if (nearest != null) {
              final newDir = (nearest.position - position).normalized();
              _velocity = newDir * _speed;
            } else {
              removeFromParent();
              return;
            }
          } else {
            removeFromParent();
            return;
          }
        }
      }
    }

    final gameSize = game.size * 3;
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
    canvas.rotate(rotationAngle);

    final r = radius;

    // Vértices de piedra facetada irregular
    final p1 = Offset(-r * 0.85, -r * 0.55);
    final p2 = Offset(-r * 0.25, -r * 0.95);
    final p3 = Offset(r * 0.65, -r * 0.80);
    final p4 = Offset(r * 0.95, -r * 0.15);
    final p5 = Offset(r * 0.75, r * 0.70);
    final p6 = Offset(r * 0.10, r * 0.95);
    final p7 = Offset(-r * 0.70, r * 0.75);
    final p8 = Offset(-r * 0.95, r * 0.05);

    final rockPath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..lineTo(p5.dx, p5.dy)
      ..lineTo(p6.dx, p6.dy)
      ..lineTo(p7.dx, p7.dy)
      ..lineTo(p8.dx, p8.dy)
      ..close();

    // Cuerpo base rocoso (gris granito medio)
    canvas.drawPath(rockPath, Paint()..color = const Color(0xFF726F6C));

    // Faceta de sombra inferior
    final shadowFacet = Path()
      ..moveTo(0, 0)
      ..lineTo(p4.dx, p4.dy)
      ..lineTo(p5.dx, p5.dy)
      ..lineTo(p6.dx, p6.dy)
      ..lineTo(p7.dx, p7.dy)
      ..close();
    canvas.drawPath(shadowFacet, Paint()..color = const Color(0xFF454240));

    // Faceta de iluminación superior
    final lightFacet = Path()
      ..moveTo(0, 0)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(lightFacet, Paint()..color = const Color(0xFFAAA5A0));

    // Resaltado superior brillante
    final highlightFacet = Path()
      ..moveTo(0, 0)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx * 0.7, p3.dy * 0.7)
      ..close();
    canvas.drawPath(highlightFacet, Paint()..color = const Color(0xFFC8C3BD));

    // Grietas minerales oscuras
    final crackPaint = Paint()
      ..color = const Color(0xFF302E2C)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(p1.dx * 0.7, p1.dy * 0.7), crackPaint);
    canvas.drawLine(Offset.zero, Offset(p5.dx * 0.75, p5.dy * 0.75), crackPaint);
    canvas.drawLine(
      Offset(p2.dx * 0.5, p2.dy * 0.5),
      Offset(p8.dx * 0.5, p8.dy * 0.5),
      crackPaint,
    );

    // Motas minerales
    canvas.drawCircle(Offset(r * 0.25, -r * 0.2), 0.7, Paint()..color = const Color(0xFFE5E2DC));
    canvas.drawCircle(Offset(-r * 0.1, -r * 0.4), 0.6, Paint()..color = const Color(0xFF262422));

    // Contorno rocoso fino
    canvas.drawPath(
      rockPath,
      Paint()
        ..color = const Color(0xFF383533)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.restore();
  }
}
