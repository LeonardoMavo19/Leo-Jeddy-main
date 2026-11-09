import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'hitbox_component.dart';
import 'player.dart';

import 'dart:math';

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
         hitboxSize: Vector2(19, 25),
         hitboxColor: Colors.transparent,
       );

  final Player target;
  final void Function(Enemy enemy) onShoot;
  static const double speed = 55;
  static const double fireRate = 2.4;
  double _shootTimer = 1.2;
  double animTime = 0;
  double walkTimer = 0;
  double facingX = 0;

  @override
  void update(double dt) {
    super.update(dt);
    animTime += dt;
    _shootTimer -= dt;
    final offset = target.position - position;

    if (offset.length2 > 0) {
      final dir = offset.normalized();
      facingX = dir.x;
      walkTimer += dt * 11;
      position.add(dir * speed * dt);
    }
    priority = hitboxBottom.round();

    if (_shootTimer <= 0) {
      onShoot(this);
      _shootTimer = fireRate;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    const s = 0.72;
    canvas.scale(s, s);

    final t = animTime * 6;
    final clawSwing = sin(walkTimer) * 3.5;
    final monsterBob = sin(walkTimer).abs() * 1.3;

    // Sombra / aura oscura pulsante
    final pulse = 1.0 + sin(t) * 0.08;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -1), width: 32 * pulse, height: 12 * pulse),
      Paint()..color = const Color(0x801F0510),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -1), width: 44 * pulse, height: 16 * pulse),
      Paint()..color = const Color(0x40590D1F),
    );

    Path spike(List<Offset> pts) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      return p..close();
    }

    // Garras / patas inferiores animadas con zancada alterna
    final clawPaint = Paint()..color = const Color(0xFF260A14);
    // Pata izq
    canvas.drawPath(spike([const Offset(-10, -6) + Offset(0, -clawSwing), const Offset(-13, -1) + Offset(0, -clawSwing), const Offset(-7, -4) + Offset(0, -clawSwing)]), clawPaint);
    canvas.drawPath(spike([const Offset(-4, -4) + Offset(0, -clawSwing * 0.5), const Offset(-5, 0) + Offset(0, -clawSwing * 0.5), const Offset(-2, -3) + Offset(0, -clawSwing * 0.5)]), clawPaint);
    // Pata der
    canvas.drawPath(spike([const Offset(10, -6) + Offset(0, clawSwing), const Offset(13, -1) + Offset(0, clawSwing), const Offset(7, -4) + Offset(0, clawSwing)]), clawPaint);
    canvas.drawPath(spike([const Offset(4, -4) + Offset(0, clawSwing * 0.5), const Offset(5, 0) + Offset(0, clawSwing * 0.5), const Offset(2, -3) + Offset(0, clawSwing * 0.5)]), clawPaint);

    // Trasladar cuerpo y cabeza con monsterBob
    canvas.save();
    canvas.translate(0, -monsterBob);

    // Espinas en hombros y espalda
    final spikePaint = Paint()..color = const Color(0xFF2E0F1A);
    canvas.drawPath(spike(const [Offset(-13, -22), Offset(-18, -26), Offset(-11, -16)]), spikePaint);
    canvas.drawPath(spike(const [Offset(13, -22), Offset(18, -26), Offset(11, -16)]), spikePaint);
    canvas.drawPath(spike(const [Offset(-12, -14), Offset(-17, -17), Offset(-10, -9)]), spikePaint);
    canvas.drawPath(spike(const [Offset(12, -14), Offset(17, -17), Offset(10, -9)]), spikePaint);

    // Cuerpo de pesadilla con textura
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -16), width: 30, height: 36),
      Paint()..color = const Color(0xFF421A26),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -16), width: 26, height: 32),
      Paint()..color = const Color(0xFF7A2938),
    );

    // Vientre / grietas de energía oscura pulsante
    final crackAlpha = (0.65 + sin(t * 1.5) * 0.25).clamp(0.2, 1.0);
    final energyPaint = Paint()
      ..color = Color.fromRGBO(204, 38, 71, crackAlpha)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-4, -18), const Offset(0, -14), energyPaint);
    canvas.drawLine(const Offset(0, -14), const Offset(3, -19), energyPaint);
    canvas.drawLine(const Offset(-2, -12), const Offset(1, -9), energyPaint);
    canvas.drawLine(const Offset(1, -9), const Offset(4, -13), energyPaint);
    canvas.drawCircle(const Offset(0, -14), 2, Paint()..color = Color.fromRGBO(255, 60, 95, crackAlpha));

    // Mirada orientada al jugador
    final mLookX = facingX < -0.15 ? -1.8 : (facingX > 0.15 ? 1.8 : 0.0);

    // Cabeza monstruosa
    canvas.drawCircle(Offset(mLookX * 0.3, -23), 12, Paint()..color = const Color(0xFF521A29));
    canvas.drawCircle(Offset(mLookX * 0.3, -23), 10.5, Paint()..color = const Color(0xFF8C2E3D));

    // Cuernos curvados orientados
    final hornPaint = Paint()..color = const Color(0xFF240A14);
    canvas.drawPath(spike([Offset(-8 + mLookX * 0.3, -27), Offset(-14 + mLookX * 0.5, -36), Offset(-3 + mLookX * 0.3, -29)]), hornPaint);
    canvas.drawPath(spike([Offset(8 + mLookX * 0.3, -27), Offset(14 + mLookX * 0.5, -36), Offset(3 + mLookX * 0.3, -29)]), hornPaint);

    final hornLinePaint = Paint()..color = const Color(0xFFB3334D)..strokeWidth = 1.0;
    canvas.drawLine(Offset(-8 + mLookX * 0.3, -27), Offset(-14 + mLookX * 0.5, -36), hornLinePaint);
    canvas.drawLine(Offset(8 + mLookX * 0.3, -27), Offset(14 + mLookX * 0.5, -36), hornLinePaint);

    // Boca cavernosa oscura orientada
    final mouthPath = Path()
      ..moveTo(-7 + mLookX * 0.4, -17)
      ..lineTo(7 + mLookX * 0.4, -17)
      ..lineTo(5 + mLookX * 0.4, -12)
      ..lineTo(-5 + mLookX * 0.4, -12)
      ..close();
    canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF14050A));

    // Colmillos blancos afilados
    final fangPaint = Paint()..color = const Color(0xFFF5F0E1);
    // Superiores
    canvas.drawPath(spike([Offset(-6 + mLookX * 0.4, -17), Offset(-4 + mLookX * 0.4, -17), Offset(-5 + mLookX * 0.4, -14)]), fangPaint);
    canvas.drawPath(spike([Offset(-2 + mLookX * 0.4, -17), Offset(0 + mLookX * 0.4, -17), Offset(-1 + mLookX * 0.4, -13.5)]), fangPaint);
    canvas.drawPath(spike([Offset(2 + mLookX * 0.4, -17), Offset(4 + mLookX * 0.4, -17), Offset(3 + mLookX * 0.4, -14)]), fangPaint);
    canvas.drawPath(spike([Offset(5 + mLookX * 0.4, -17), Offset(7 + mLookX * 0.4, -17), Offset(6 + mLookX * 0.4, -13)]), fangPaint);
    // Inferiores
    canvas.drawPath(spike([Offset(-4 + mLookX * 0.4, -12), Offset(-2 + mLookX * 0.4, -12), Offset(-3 + mLookX * 0.4, -15)]), fangPaint);
    canvas.drawPath(spike([Offset(1 + mLookX * 0.4, -12), Offset(3 + mLookX * 0.4, -12), Offset(2 + mLookX * 0.4, -15)]), fangPaint);

    // Ojos incandescentes de fuego orientados
    canvas.drawCircle(Offset(-4.5 + mLookX, -24), 4, Paint()..color = const Color(0x73FFA61A));
    canvas.drawCircle(Offset(4.5 + mLookX, -24), 4, Paint()..color = const Color(0x73FFA61A));
    canvas.drawOval(Rect.fromCenter(center: Offset(-4.5 + mLookX, -24), width: 5, height: 6), Paint()..color = const Color(0xFFFFD926));
    canvas.drawOval(Rect.fromCenter(center: Offset(4.5 + mLookX, -24), width: 5, height: 6), Paint()..color = const Color(0xFFFFD926));
    canvas.drawOval(Rect.fromCenter(center: Offset(-4.5 + mLookX, -24), width: 1.8, height: 5), Paint()..color = const Color(0xFF990D0D));
    canvas.drawOval(Rect.fromCenter(center: Offset(4.5 + mLookX, -24), width: 1.8, height: 5), Paint()..color = const Color(0xFF990D0D));
    canvas.drawCircle(Offset(-5 + mLookX, -25), 0.7, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(4 + mLookX, -25), 0.7, Paint()..color = Colors.white);

    canvas.restore(); // fin de monsterBob
    canvas.restore(); // fin de render
  }
}
