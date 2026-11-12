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
    this.isBoss = false,
    this.bossId = '',
    this.name = 'Monstruo Sombrío',
    this.subtitle = 'Criatura de la oscuridad',
    this.lore = '',
    this.color = const Color(0xFFFF5C6A),
    this.shotType = 'fear',
    this.hp = 1,
    this.maxHp = 1,
  }) : super(
         footPosition: position,
         hitboxSize: isBoss ? Vector2(36, 46) : Vector2(19, 25),
         hitboxColor: Colors.transparent,
       );

  final Player target;
  final void Function(Enemy enemy) onShoot;
  final bool isBoss;
  final String bossId;
  final String name;
  final String subtitle;
  final String lore;
  final Color color;
  final String shotType;
  int hp;
  int maxHp;
  double hitFlash = 0;

  double get speed => isBoss ? 46 : 55;
  double get fireRate => isBoss ? 1.8 : 2.4;
  double _shootTimer = 1.2;
  double animTime = 0;
  double walkTimer = 0;
  double facingX = 0;

  bool takeDamage(int amount) {
    hp -= amount;
    hitFlash = 0.16;
    return hp <= 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    animTime += dt;
    _shootTimer -= dt;
    if (hitFlash > 0) {
      hitFlash = max(0, hitFlash - dt);
    }
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

  Path _poly(List<Offset> pts) {
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    return p..close();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y);

    if (isBoss) {
      _renderVenezuelanBoss(canvas);
      canvas.restore();
      return;
    }

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

    // Garras / patas inferiores animadas con zancada alterna
    final clawPaint = Paint()..color = const Color(0xFF260A14);
    canvas.drawPath(_poly([Offset(-10, -6 - clawSwing), Offset(-13, -1 - clawSwing), Offset(-7, -4 - clawSwing)]), clawPaint);
    canvas.drawPath(_poly([Offset(-4, -4 - clawSwing * 0.5), Offset(-5, -clawSwing * 0.5), Offset(-2, -3 - clawSwing * 0.5)]), clawPaint);
    canvas.drawPath(_poly([Offset(10, -6 + clawSwing), Offset(13, -1 + clawSwing), Offset(7, -4 + clawSwing)]), clawPaint);
    canvas.drawPath(_poly([Offset(4, -4 + clawSwing * 0.5), Offset(5, clawSwing * 0.5), Offset(2, -3 + clawSwing * 0.5)]), clawPaint);

    // Cuerpo con monsterBob
    canvas.save();
    canvas.translate(0, -monsterBob);

    // Espinas en hombros y espalda
    final spikePaint = Paint()..color = const Color(0xFF2E0F1A);
    canvas.drawPath(_poly(const [Offset(-13, -22), Offset(-18, -26), Offset(-11, -16)]), spikePaint);
    canvas.drawPath(_poly(const [Offset(13, -22), Offset(18, -26), Offset(11, -16)]), spikePaint);
    canvas.drawPath(_poly(const [Offset(-12, -14), Offset(-17, -17), Offset(-10, -9)]), spikePaint);
    canvas.drawPath(_poly(const [Offset(12, -14), Offset(17, -17), Offset(10, -9)]), spikePaint);

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
    canvas.drawPath(_poly([Offset(-8 + mLookX * 0.3, -27), Offset(-14 + mLookX * 0.5, -36), Offset(-3 + mLookX * 0.3, -29)]), hornPaint);
    canvas.drawPath(_poly([Offset(8 + mLookX * 0.3, -27), Offset(14 + mLookX * 0.5, -36), Offset(3 + mLookX * 0.3, -29)]), hornPaint);

    final hornLinePaint = Paint()..color = const Color(0xFFB3334D)..strokeWidth = 1.0;
    canvas.drawLine(Offset(-8 + mLookX * 0.3, -27), Offset(-14 + mLookX * 0.5, -36), hornLinePaint);
    canvas.drawLine(Offset(8 + mLookX * 0.3, -27), Offset(14 + mLookX * 0.5, -36), hornLinePaint);

    // Boca cavernosa
    final mouthPath = Path()
      ..moveTo(-7 + mLookX * 0.4, -17)
      ..lineTo(7 + mLookX * 0.4, -17)
      ..lineTo(5 + mLookX * 0.4, -12)
      ..lineTo(-5 + mLookX * 0.4, -12)
      ..close();
    canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF14050A));

    // Colmillos
    final fangPaint = Paint()..color = const Color(0xFFF5F0E1);
    canvas.drawPath(_poly([Offset(-6 + mLookX * 0.4, -17), Offset(-4 + mLookX * 0.4, -17), Offset(-5 + mLookX * 0.4, -14)]), fangPaint);
    canvas.drawPath(_poly([Offset(-2 + mLookX * 0.4, -17), Offset(0 + mLookX * 0.4, -17), Offset(-1 + mLookX * 0.4, -13.5)]), fangPaint);
    canvas.drawPath(_poly([Offset(2 + mLookX * 0.4, -17), Offset(4 + mLookX * 0.4, -17), Offset(3 + mLookX * 0.4, -14)]), fangPaint);
    canvas.drawPath(_poly([Offset(5 + mLookX * 0.4, -17), Offset(7 + mLookX * 0.4, -17), Offset(6 + mLookX * 0.4, -13)]), fangPaint);

    // Ojos
    canvas.drawCircle(Offset(-4.5 + mLookX, -24), 4, Paint()..color = const Color(0x73FFA61A));
    canvas.drawCircle(Offset(4.5 + mLookX, -24), 4, Paint()..color = const Color(0x73FFA61A));
    canvas.drawOval(Rect.fromCenter(center: Offset(-4.5 + mLookX, -24), width: 5, height: 6), Paint()..color = const Color(0xFFFFD926));
    canvas.drawOval(Rect.fromCenter(center: Offset(4.5 + mLookX, -24), width: 5, height: 6), Paint()..color = const Color(0xFFFFD926));
    canvas.drawOval(Rect.fromCenter(center: Offset(-4.5 + mLookX, -24), width: 1.8, height: 5), Paint()..color = const Color(0xFF990D0D));
    canvas.drawOval(Rect.fromCenter(center: Offset(4.5 + mLookX, -24), width: 1.8, height: 5), Paint()..color = const Color(0xFF990D0D));

    // Flash blanco al recibir impacto
    if (hitFlash > 0) {
      canvas.drawCircle(const Offset(0, -18), 16, Paint()..color = const Color(0xA6FFFFFF));
    }

    canvas.restore(); // fin de monsterBob
    canvas.restore(); // fin de render
  }

  void _renderVenezuelanBoss(Canvas canvas) {
    final s = (bossId == 'el_cabron') ? 1.85 : 1.75;
    canvas.scale(s, s);

    final lookDir = facingX < -0.15 ? -1.0 : 1.0;
    canvas.save();
    canvas.scale(lookDir, 1.0);

    final t = animTime * 5.0;
    final swing = sin(walkTimer) * 3.8;
    final bob = sin(walkTimer).abs() * 1.6;

    if (bossId == 'el_silbon') {
      // 1. EL SILBÓN
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 48, height: 14), Paint()..color = const Color(0xA6040805));
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 64, height: 20), Paint()..color = const Color(0x59030503));

      // Piernas campesinas enjutas
      canvas.drawPath(_poly([const Offset(-7, -22), const Offset(-3, -22), Offset(-5 + swing * 0.9, -4), Offset(-9 + swing * 0.9, -4)]), Paint()..color = const Color(0xFF292E38));
      canvas.drawPath(_poly([const Offset(3, -22), const Offset(7, -22), Offset(9 - swing * 0.9, -4), Offset(5 - swing * 0.9, -4)]), Paint()..color = const Color(0xFF333842));

      // Pantorrillas y pies descalzos tostados
      final skinPaint = Paint()..color = const Color(0xFFAD7552);
      canvas.drawRect(Rect.fromLTWH(-8 + swing * 0.9, -4, 4, 4), skinPaint);
      canvas.drawRect(Rect.fromLTWH(5 - swing * 0.9, -4, 4, 4), skinPaint);
      canvas.drawPath(_poly([Offset(-9 + swing * 0.9, 0), Offset(-3 + swing * 0.9, 0), Offset(-4 + swing * 0.9, -3), Offset(-8 + swing * 0.9, -3)]), Paint()..color = const Color(0xFFB8805C));
      canvas.drawPath(_poly([Offset(4 - swing * 0.9, 0), Offset(10 - swing * 0.9, 0), Offset(9 - swing * 0.9, -3), Offset(5 - swing * 0.9, -3)]), Paint()..color = const Color(0xFFB8805C));

      canvas.save();
      canvas.translate(0, -bob);

      // Pantalón remangado con parches
      final pantsPaint = Paint()..color = const Color(0xFF383D47);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -24, 8, 16), const Radius.circular(2)), pantsPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(1, -24, 8, 16), const Radius.circular(2)), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(-8, -16, 4, 4), Paint()..color = const Color(0xFF525966));

      // Faja campesina
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -25, 20, 3.5), const Radius.circular(1)), Paint()..color = const Color(0xFF613D24));

      // Camisa campesina andrajosa
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -42, 20, 20), const Radius.circular(3)), Paint()..color = const Color(0xFFD1C7B2));
      final foldPaint = Paint()..color = const Color(0xFFB3A68F)..strokeWidth = 1.0;
      canvas.drawLine(const Offset(-4, -40), const Offset(-4, -26), foldPaint);
      canvas.drawLine(const Offset(-7, -35), const Offset(-2, -37), foldPaint);
      canvas.drawLine(const Offset(2, -37), const Offset(7, -35), foldPaint);
      // Picos rotos de la camisa
      canvas.drawPath(_poly(const [Offset(-10, -22), Offset(-7, -19), Offset(-4, -22), Offset(-1, -19), Offset(2, -22), Offset(5, -19), Offset(8, -22), Offset(10, -24), Offset(-10, -24)]), Paint()..color = const Color(0xFFC2B8A3));

      // Gran saco de huesos macabro
      canvas.drawOval(Rect.fromCenter(center: const Offset(-15, -34), width: 30, height: 40), Paint()..color = const Color(0xFF664024));
      canvas.drawOval(Rect.fromCenter(center: const Offset(-14, -35), width: 24, height: 34), Paint()..color = const Color(0xFF8C5C33));
      // Cuerda atada
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -46, 10, 3.5), const Radius.circular(1)), Paint()..color = const Color(0xFFD1C28C));

      // Huesos saliendo: fémur y cráneo
      final bonePaint = Paint()..color = const Color(0xFFF5F0E1);
      canvas.drawLine(const Offset(-16, -46), const Offset(-11, -56), Paint()..color = const Color(0xFFF5F0E1)..strokeWidth = 3);
      canvas.drawCircle(const Offset(-13, -56), 3, bonePaint);
      canvas.drawCircle(const Offset(-9, -55), 3, bonePaint);
      // Cráneo asomando
      canvas.drawCircle(const Offset(-18, -42), 5, bonePaint);
      canvas.drawCircle(const Offset(-19, -42), 1.2, Paint()..color = const Color(0xFF1F1A1A));
      canvas.drawCircle(const Offset(-16, -42), 1.2, Paint()..color = const Color(0xFF1F1A1A));

      // Rostro cadavérico demacrado
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3.5, -46, 7, 6), const Radius.circular(1)), skinPaint);
      canvas.drawPath(_poly(const [Offset(-7, -54), Offset(7, -54), Offset(5, -45), Offset(-5, -45)]), skinPaint);
      canvas.drawCircle(const Offset(0, -51), 7.5, skinPaint);

      // Cuencas oscuras y brillo en ojos
      canvas.drawOval(Rect.fromCenter(center: const Offset(-3.5, -52), width: 4.8, height: 4), Paint()..color = const Color(0xFF2E1A14));
      canvas.drawOval(Rect.fromCenter(center: const Offset(3.5, -52), width: 4.8, height: 4), Paint()..color = const Color(0xFF2E1A14));
      canvas.drawCircle(const Offset(-2.8, -52), 1, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(4.2, -52), 1, Paint()..color = Colors.white);

      // Boca silbando
      canvas.drawCircle(const Offset(0, -47), 1.6, Paint()..color = const Color(0xFF73422E));

      // Mano huesuda silbando
      canvas.drawLine(const Offset(-7, -38), const Offset(-3, -47), skinPaint..strokeWidth = 2);
      canvas.drawCircle(const Offset(0, -47), 2, skinPaint);

      // Sombrero de paja de cogollo llanero
      final strawPaint = Paint()..color = const Color(0xFFC29E57);
      canvas.drawPath(_poly(const [Offset(-10, -56), Offset(-8, -68), Offset(-2, -66), Offset(0, -68), Offset(2, -66), Offset(8, -68), Offset(10, -56)]), strawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, -56), width: 52, height: 12), strawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, -57), width: 48, height: 9), Paint()..color = const Color(0xFFE0C270));
      // Cinta de cuero con hebilla
      canvas.drawRect(const Rect.fromLTWH(-9.5, -58, 19, 3), Paint()..color = const Color(0xFF592E1A));

      // Notas musicales flotantes
      for (var ni = 1; ni <= 3; ni++) {
        final noteCycle = (t * 2.5 + ni * 2) % 6;
        final noteX = 8 + sin(t * 3 + ni * 1.5) * 8;
        final noteY = -48 - noteCycle * 7;
        final noteAlpha = (1.0 - noteCycle / 5.5).clamp(0.0, 1.0);
        final nPaint = Paint()..color = Color.fromRGBO(255, 224, 77, noteAlpha * 0.9);
        canvas.drawCircle(Offset(noteX, noteY), 2.2, nPaint);
        canvas.drawLine(Offset(noteX + 1.8, noteY), Offset(noteX + 1.8, noteY - 6), nPaint..strokeWidth = 1.2);
        canvas.drawLine(Offset(noteX + 1.8, noteY - 6), Offset(noteX + 5, noteY - 4), nPaint..strokeWidth = 1.2);
      }

      canvas.restore();
    } else if (bossId == 'la_llorona') {
      // 2. LA LLORONA
      final floatY = sin(t * 1.6) * 5 - 8;
      final ripple = (t * 2) % 3;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 32 + ripple * 28, height: 10 + ripple * 8),
        Paint()
          ..color = Color.fromRGBO(64, 178, 242, 0.35 * (1.0 - ripple / 3))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      canvas.save();
      canvas.translate(0, floatY);

      // Gran aura gélida pulsante
      final auraPulse = 1.0 + sin(t * 2.8) * 0.12;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -24), width: 60 * auraPulse, height: 76 * auraPulse),
        Paint()..color = const Color(0x2E4DCCFF),
      );

      // Vestido nupcial ondeando
      canvas.drawPath(_poly([const Offset(-12, -32), const Offset(12, -32), Offset(18 + sin(t * 2.2) * 4, 4), Offset(-18 + cos(t * 2.2) * 4, 4)]), Paint()..color = const Color(0xD99EC2E0));
      canvas.drawPath(_poly([const Offset(-10, -32), const Offset(10, -32), Offset(14 + sin(t * 2.0) * 3, 2), Offset(-14 + cos(t * 2.0) * 3, 2)]), Paint()..color = const Color(0xEBE0F0FF));

      // Cabellera azabache
      final hairPaint = Paint()..color = const Color(0xFF0F141F);
      canvas.drawPath(_poly([const Offset(-10, -42), Offset(-15, -16 + sin(t * 2) * 2), const Offset(-7, -18)]), hairPaint);
      canvas.drawPath(_poly([const Offset(10, -42), Offset(15, -16 - sin(t * 2) * 2), const Offset(7, -18)]), hairPaint);
      canvas.drawCircle(const Offset(0, -40), 10, hairPaint);

      // Cabeza pálida y manos cubriéndose el rostro en llanto
      final palePaint = Paint()..color = const Color(0xFFD9EBF5);
      canvas.drawCircle(const Offset(0, -42), 8.5, palePaint);
      canvas.drawCircle(const Offset(-3.5, -38), 3.5, palePaint);
      canvas.drawCircle(const Offset(3.5, -38), 3.5, palePaint);

      // Velo nupcial translúcido
      canvas.drawPath(_poly([const Offset(-8, -48), const Offset(8, -48), Offset(16 + sin(t * 1.8) * 3, -12), Offset(-16 + cos(t * 1.8) * 3, -12)]), Paint()..color = const Color(0xA6E0F2FF));

      // Lágrimas cian brotando
      for (var di = 1; di <= 4; di++) {
        final dropCycle = (t * 4 + di * 2) % 8;
        final dropX = (di % 2 == 0) ? (3.5 + sin(di) * 1.5) : (-3.5 - sin(di) * 1.5);
        final dropY = -36 + dropCycle * 4.5;
        final dropAlpha = (0.95 - dropCycle / 7.5).clamp(0.0, 1.0);
        canvas.drawCircle(Offset(dropX, dropY), 1.8, Paint()..color = Color.fromRGBO(102, 230, 255, dropAlpha));
      }

      canvas.restore();
    } else if (bossId == 'el_cabron') {
      // 3. EL CABRÓN LEYENDARIO
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 52, height: 16), Paint()..color = const Color(0xB3140508));

      // Patas de macho cabrío con pezuñas hendidas
      canvas.drawPath(_poly([const Offset(-13, -18), Offset(-16 + swing, 0), Offset(-9 + swing, 0), const Offset(-7, -18)]), Paint()..color = const Color(0xFF2E1F1A));
      canvas.drawPath(_poly([const Offset(7, -18), Offset(9 - swing, 0), Offset(16 - swing, 0), const Offset(13, -18)]), Paint()..color = const Color(0xFF3D291F));
      canvas.drawRect(Rect.fromLTWH(-16 + swing, -3.5, 7, 3.5), Paint()..color = const Color(0xFF0F0A0A));
      canvas.drawRect(Rect.fromLTWH(9 - swing, -3.5, 7, 3.5), Paint()..color = const Color(0xFF0F0A0A));

      canvas.save();
      canvas.translate(0, -bob);

      // Torso fornido con pelaje espeso
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-15, -40, 30, 26), const Radius.circular(7)), Paint()..color = const Color(0xFF33241C));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -38, 26, 22), const Radius.circular(5)), Paint()..color = const Color(0xFF4D3326));

      // Zurrón de cuero cruzado con hebilla de latón
      canvas.drawLine(const Offset(-14, -38), const Offset(12, -22), Paint()..color = const Color(0xFF7A4724)..strokeWidth = 3);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, -26, 10, 10), const Radius.circular(2)), Paint()..color = const Color(0xFF7A4724));
      canvas.drawRect(const Rect.fromLTWH(11, -23, 4, 4), Paint()..color = const Color(0xFFD9B34D)..style = PaintingStyle.stroke..strokeWidth = 1);

      // Brazo y Gran Machete plateado
      canvas.drawLine(const Offset(14, -36), const Offset(20, -24), Paint()..color = const Color(0xFF3D291F)..strokeWidth = 4);
      // Machete
      canvas.drawPath(_poly(const [Offset(22, -27), Offset(36, -42), Offset(40, -38), Offset(24, -23)]), Paint()..color = const Color(0xFFD9E0F0));
      canvas.drawLine(const Offset(22, -27), const Offset(36, -42), Paint()..color = Colors.white..strokeWidth = 1.2);

      // Cabeza y cuernos retorcidos
      canvas.drawCircle(const Offset(0, -46), 11, Paint()..color = const Color(0xFF2E1F1A));
      canvas.drawPath(_poly(const [Offset(-3, -33), Offset(3, -33), Offset(0, -26)]), Paint()..color = const Color(0xFF472E24)); // Barba

      // Cuernos gigantescos anillados
      final hornPaint = Paint()..color = const Color(0xFF47382E);
      canvas.drawPath(_poly(const [Offset(-8, -52), Offset(-22, -68), Offset(-14, -71), Offset(-3, -53)]), hornPaint);
      canvas.drawPath(_poly(const [Offset(8, -52), Offset(22, -68), Offset(14, -71), Offset(3, -53)]), hornPaint);

      // Ojos incandescentes demoníacos
      canvas.drawCircle(const Offset(-4.5, -47), 3, Paint()..color = const Color(0xFFFF2626));
      canvas.drawCircle(const Offset(4.5, -47), 3, Paint()..color = const Color(0xFFFF2626));
      canvas.drawCircle(const Offset(-4.5, -47), 1.2, Paint()..color = const Color(0xFFFFD933));
      canvas.drawCircle(const Offset(4.5, -47), 1.2, Paint()..color = const Color(0xFFFFD933));

      canvas.restore();
    } else if (bossId == 'duendes') {
      // 4. LOS DUENDES
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 40, height: 12), Paint()..color = const Color(0x9908140A));
      // Amanita muscaria
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-19, -10, 5, 10), const Radius.circular(1)), Paint()..color = const Color(0xFFEBE6D9));
      canvas.drawArc(const Rect.fromLTWH(-26.5, -20, 20, 20), pi, pi, true, Paint()..color = const Color(0xFFF2382E));
      canvas.drawCircle(const Offset(-20, -14), 1.8, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(-14, -15), 2.0, Paint()..color = Colors.white);

      final duendeHop = sin(t * 3.6).abs() * 4;
      canvas.save();
      canvas.translate(0, -duendeHop);

      // Piernas y botitas de punta curvada
      canvas.drawRect(const Rect.fromLTWH(-7, -12, 5, 8), Paint()..color = const Color(0xFF59A64D));
      canvas.drawRect(const Rect.fromLTWH(2, -12, 5, 8), Paint()..color = const Color(0xFF59A64D));
      canvas.drawPath(_poly(const [Offset(-10, -5), Offset(-2, -5), Offset(-1, -2), Offset(-11, -2)]), Paint()..color = const Color(0xFF7A4729));
      canvas.drawPath(_poly(const [Offset(1, -5), Offset(9, -5), Offset(10, -2), Offset(0, -2)]), Paint()..color = const Color(0xFF7A4729));

      // Cuerpo y chaleco con faja roja
      canvas.drawCircle(const Offset(0, -20), 10.5, Paint()..color = const Color(0xFF61B352));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -25, 16, 12), const Radius.circular(3)), Paint()..color = const Color(0xFF7A4D2E));
      canvas.drawRect(const Rect.fromLTWH(-8, -16, 16, 3), Paint()..color = const Color(0xFFD93333));

      // Pepita de oro puro con destellos en cruz
      canvas.drawCircle(const Offset(0, -19), 6.5, Paint()..color = const Color(0xFFFFD92E));
      canvas.drawCircle(const Offset(-2, -21), 2.8, Paint()..color = const Color(0xFFFFFFA6));
      final shinePaint = Paint()..color = Colors.white..strokeWidth = 1.0;
      canvas.drawLine(const Offset(-4, -19), const Offset(4, -19), shinePaint);
      canvas.drawLine(const Offset(0, -23), const Offset(0, -15), shinePaint);

      // Cabeza y orejas de duende con pendiente
      canvas.drawCircle(const Offset(0, -31), 8.5, Paint()..color = const Color(0xFF66BD57));
      canvas.drawPath(_poly(const [Offset(-8, -32), Offset(-18, -37), Offset(-7, -29)]), Paint()..color = const Color(0xFF66BD57));
      canvas.drawPath(_poly(const [Offset(8, -32), Offset(18, -37), Offset(7, -29)]), Paint()..color = const Color(0xFF66BD57));
      canvas.drawCircle(const Offset(-16, -35), 1.5, Paint()..color = const Color(0xFFFFD933));

      // Gorro marrón con cascabel dorado
      canvas.drawPath(_poly(const [Offset(-9, -35), Offset(9, -35), Offset(16, -50), Offset(4, -38)]), Paint()..color = const Color(0xFF8C5933));
      canvas.drawCircle(const Offset(16, -50), 2.5, Paint()..color = const Color(0xFFFFD933));

      canvas.restore();
    } else if (bossId == 'las_animas') {
      // 5. LAS ÁNIMAS
      final animFloat = sin(t * 1.8) * 3 - 6;
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 48, height: 14), Paint()..color = const Color(0x73141F29));

      canvas.save();
      canvas.translate(0, animFloat);

      // Ánimas acompañantes fantasmales menores
      final ghostPaint = Paint()..color = const Color(0x59D9E6F5);
      canvas.drawPath(_poly(const [Offset(-24, -34), Offset(-14, -34), Offset(-12, 0), Offset(-26, 0)]), ghostPaint);
      canvas.drawCircle(const Offset(-19, -40), 6, ghostPaint);
      canvas.drawPath(_poly(const [Offset(14, -34), Offset(24, -34), Offset(26, 0), Offset(12, 0)]), ghostPaint);
      canvas.drawCircle(const Offset(19, -40), 6, ghostPaint);

      // Ánima Guía con túnica de lino blanco
      canvas.drawPath(_poly(const [Offset(-12, -36), Offset(12, -36), Offset(16, 4), Offset(-16, 4)]), Paint()..color = const Color(0xD9B8CCD9));
      canvas.drawPath(_poly(const [Offset(-10, -36), Offset(10, -36), Offset(13, 2), Offset(-13, 2)]), Paint()..color = const Color(0xF2E0F0FF));

      // Capucha blanca y rostro en penumbra abisal
      canvas.drawCircle(const Offset(0, -42), 10, Paint()..color = const Color(0xFFE0F0FF));
      canvas.drawPath(_poly(const [Offset(-9, -42), Offset(9, -42), Offset(0, -55)]), Paint()..color = const Color(0xFFE0F0FF));
      canvas.drawCircle(const Offset(0, -40), 7, Paint()..color = const Color(0xFA1A242E));

      // Ojos de ánima azul cian
      canvas.drawCircle(const Offset(-3, -40), 1.6, Paint()..color = const Color(0xF266E0FF));
      canvas.drawCircle(const Offset(3, -40), 1.6, Paint()..color = const Color(0xF266E0FF));

      // Gran cirio de cera con llama viva y halo cálido
      canvas.drawRect(const Rect.fromLTWH(4.5, -33, 5, 18), Paint()..color = const Color(0xFFF0EBD9));
      final flameFlicker = sin(t * 9) * 1.2;
      canvas.drawCircle(const Offset(7, -38), 16, Paint()..color = const Color(0x42FFD940));
      canvas.drawPath(_poly([const Offset(4.5, -33), const Offset(9.5, -33), Offset(7 + flameFlicker, -44)]), Paint()..color = const Color(0xFFFFE04D));
      canvas.drawCircle(const Offset(7, -35), 2.5, Paint()..color = const Color(0xFFFFFAB3));

      canvas.restore();
    } else {
      // 6. LAS BRUJAS (o default)
      final witchFloat = sin(t * 2.2) * 5 - 12;
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 48, height: 14), Paint()..color = const Color(0x730F0814));

      canvas.save();
      canvas.translate(0, witchFloat);

      // Escoba mágica
      canvas.drawLine(const Offset(-28, -14), const Offset(26, -18), Paint()..color = const Color(0xFF7A4D29)..strokeWidth = 3.5);
      canvas.drawPath(_poly(const [Offset(-24, -18), Offset(-36, -24), Offset(-38, -8), Offset(-24, -10)]), Paint()..color = const Color(0xFFD1AD4D));

      // Traje gótico morado
      canvas.drawPath(_poly([const Offset(-8, -34), const Offset(8, -34), const Offset(14, -14), Offset(-18 + sin(t * 3) * 4, -14)]), Paint()..color = const Color(0xFF2E1442));
      canvas.drawPath(_poly(const [Offset(-6, -34), Offset(6, -34), Offset(10, -14), Offset(-12, -14)]), Paint()..color = const Color(0xFF522470));

      // Rostro de bruja con nariz aguileña y ojos amarillos
      canvas.drawCircle(const Offset(3, -38), 7.5, Paint()..color = const Color(0xFFC2B39E));
      canvas.drawPath(_poly(const [Offset(8, -39), Offset(14, -37), Offset(9, -35)]), Paint()..color = const Color(0xFFC2B39E));
      canvas.drawCircle(const Offset(6, -39), 1.8, Paint()..color = const Color(0xFFFFE033));

      // Sombrero negro de bruja con lazo morado y hebilla dorada
      canvas.drawOval(Rect.fromCenter(center: const Offset(3, -44), width: 36, height: 9), Paint()..color = const Color(0xFF1F1429));
      canvas.drawPath(_poly(const [Offset(-6, -44), Offset(11, -44), Offset(16, -62), Offset(5, -44)]), Paint()..color = const Color(0xFF1F1429));
      canvas.drawRect(const Rect.fromLTWH(-3, -47, 13, 3), Paint()..color = const Color(0xFFB340E6));

      // Orbe de energía arcana
      canvas.drawCircle(const Offset(16, -26), 6, Paint()..color = const Color(0x59D959FF));
      canvas.drawCircle(const Offset(16, -26), 3, Paint()..color = const Color(0xF2F299FF));

      // Estrellitas mágicas en órbita
      for (var si = 1; si <= 3; si++) {
        final sAngle = t * 3 + si * 2.1;
        final sx = cos(sAngle) * 18;
        final sy = -28 + sin(sAngle) * 12;
        canvas.drawPath(_poly([Offset(sx, sy - 4), Offset(sx + 1.2, sy - 1), Offset(sx + 4, sy), Offset(sx + 1.2, sy + 1), Offset(sx, sy + 4), Offset(sx - 1.2, sy + 1), Offset(sx - 4, sy), Offset(sx - 1.2, sy - 1)]), Paint()..color = const Color(0xD9EB99FF));
      }

      canvas.restore();
    }

    // Flash blanco al ser impactado
    if (hitFlash > 0) {
      canvas.drawCircle(const Offset(0, -26), 26, Paint()..color = const Color(0xBFFFFFFF));
    }

    canvas.restore(); // fin de lookDir

    // Mini barra de vida superior sobre el boss
    if (maxHp > 1) {
      final hpPct = (hp / maxHp).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -66, 48, 6), const Radius.circular(2)),
        Paint()..color = const Color(0xE010141A),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-23, -65, 46 * hpPct, 4), const Radius.circular(1)),
        Paint()..color = color,
      );
    }
  }
}
