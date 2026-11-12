import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../survivors_game.dart';
import 'hitbox_component.dart';
import 'tree.dart';

class Player extends HitboxComponent {
  Player({required this.movementInput, required Vector2 position})
    : super(
        footPosition: position,
        hitboxSize: Vector2(20, 35),
        hitboxColor: Colors.transparent,
      );

  final Vector2 movementInput;
  static const double speed = 160;
  double facingX = 0;
  double facingY = 1;
  double walkTimer = 0;
  bool isMoving = false;

  // Atributos de mejoras (Upgrades)
  int projectileCount = 1;
  double fireCooldown = 0.38;
  double speedMultiplier = 1.0;
  double stoneRadius = 7.0;
  int stonePierce = 1;
  int stoneBounce = 0;
  double stoneSpeed = 390.0;
  double fearResistance = 1.0;

  void resetUpgrades() {
    projectileCount = 1;
    fireCooldown = 0.38;
    speedMultiplier = 1.0;
    stoneRadius = 7.0;
    stonePierce = 1;
    stoneBounce = 0;
    stoneSpeed = 390.0;
    fearResistance = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (movementInput.length2 > 0.001) {
      facingX = movementInput.x;
      facingY = movementInput.y;
      isMoving = true;
      walkTimer += dt * 14;
    } else {
      isMoving = false;
    }

    final effectiveSpeed = speed * speedMultiplier;
    final nextPosition = position + movementInput * effectiveSpeed * dt;

    final game = findGame()! as SurvivorsGame;
    final worldSize = game.worldSize;
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

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    const s = 0.72;
    canvas.scale(s, s);

    // Animación de caminata (zancadas y bamboleo)
    final legSwing = isMoving ? sin(walkTimer) * 3.5 : 0.0;
    final bodyBob = isMoving ? sin(walkTimer).abs() * 1.5 : 0.0;

    // Está de espaldas cuando camina hacia arriba o diagonales superiores
    final isFacingUp = facingY < -0.25;

    // Sombra suave en el suelo
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -1), width: 32, height: 10),
      Paint()..color = const Color(0x730D2214),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -1), width: 40, height: 13),
      Paint()..color = const Color(0x4D0A1A0F),
    );

    // Botas y Piernas animadas con balanceo alternado
    final leftLegY = -legSwing;
    final rightLegY = legSwing;

    final shoeDark = Paint()..color = const Color(0xFF38261A);
    final shoeLeather = Paint()..color = const Color(0xFF613D29);
    final shoeSole = Paint()..color = const Color(0xFFC7BDAC);
    final shoeLaces = Paint()..color = const Color(0xFFEBE0CD)..strokeWidth = 1;
    final denimDark = Paint()..color = const Color(0xFF24334D);
    final denimBase = Paint()..color = const Color(0xFF334D70);

    // Bota izq
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-10, -20 + leftLegY * 0.6, 8, 12), const Radius.circular(2)), denimDark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-9, -20 + leftLegY * 0.6, 7, 10), const Radius.circular(2)), denimBase);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-12, -12 + leftLegY, 9, 8), const Radius.circular(3)), shoeLeather);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-12, -4 + leftLegY, 9, 4), const Radius.circular(1)), shoeSole);
    canvas.drawLine(Offset(-10, -9 + leftLegY), Offset(-6, -7 + leftLegY), shoeLaces);

    // Bota der
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(2, -20 + rightLegY * 0.6, 8, 12), const Radius.circular(2)), denimDark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(2, -20 + rightLegY * 0.6, 7, 10), const Radius.circular(2)), denimBase);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(3, -12 + rightLegY, 9, 8), const Radius.circular(3)), shoeLeather);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(3, -4 + rightLegY, 9, 4), const Radius.circular(1)), shoeSole);
    canvas.drawLine(Offset(5, -9 + rightLegY), Offset(9, -7 + rightLegY), shoeLaces);

    // Trasladar torso y cabeza con el bamboleo de paso
    canvas.save();
    canvas.translate(0, -bodyBob);

    final jacketDark = Paint()..color = const Color(0xFF2E6642);
    final jacketBase = Paint()..color = const Color(0xFF479461);

    if (isFacingUp) {
      // ==========================================
      // VISTA DE ESPALDA (caminando hacia arriba)
      // ==========================================
      // Torso trasero
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -37, 22, 17), const Radius.circular(5)), jacketDark);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -37, 18, 16), const Radius.circular(4)), jacketBase);

      // Brazos
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -36, 6, 17), const Radius.circular(3)), jacketDark);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, -36, 6, 17), const Radius.circular(3)), jacketDark);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -35, 5, 14), const Radius.circular(2)), jacketBase);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, -35, 5, 14), const Radius.circular(2)), jacketBase);

      // Mochila aventurera en primer plano en la espalda
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -38, 22, 20), const Radius.circular(5)),
        Paint()..color = const Color(0xFF6B381F),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -36, 18, 16), const Radius.circular(4)),
        Paint()..color = const Color(0xFF8C4C29),
      );
      // Bolsillo de la mochila
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -29, 14, 8), const Radius.circular(3)),
        Paint()..color = const Color(0xFF5E331A),
      );
      canvas.drawLine(const Offset(-7, -25), const Offset(7, -25), Paint()..color = const Color(0xFFBFB8A6)..strokeWidth = 1.0);

      // Capucha doblada
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, -39), width: 20, height: 8), Paint()..color = const Color(0xFF29593A));

      // Nuca con cabello
      final hairDark = Paint()..color = const Color(0xFF382417);
      final hairBase = Paint()..color = const Color(0xFF5C3321);
      canvas.drawCircle(const Offset(0, -45), 11, hairDark);
      canvas.drawCircle(const Offset(0, -46), 10.5, hairBase);

      Path tuft(List<Offset> pts) {
        final p = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (var i = 1; i < pts.length; i++) p.lineTo(pts[i].dx, pts[i].dy);
        return p..close();
      }

      canvas.drawPath(tuft(const [Offset(-10, -45), Offset(-5, -40), Offset(-1, -45)]), hairBase);
      canvas.drawPath(tuft(const [Offset(0, -45), Offset(5, -40), Offset(10, -45)]), hairBase);
      canvas.drawPath(tuft(const [Offset(-8, -52), Offset(-2, -56), Offset(3, -52)]), hairBase);
      canvas.drawPath(tuft(const [Offset(2, -52), Offset(7, -56), Offset(11, -49)]), hairBase);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, -50), width: 14, height: 6), Paint()..color = const Color(0x99855233));

    } else {
      // =========================================================
      // VISTA DE FRENTE / 3/4 (abajo, diagonales inferiores o lados)
      // =========================================================
      // 1. Cabello trasero (detrás de la cabeza)
      final hairDark = Paint()..color = const Color(0xFF382417);
      final hairBase = Paint()..color = const Color(0xFF5C3321);
      canvas.drawCircle(const Offset(0, -45), 11, hairDark);
      canvas.drawCircle(const Offset(0, -46), 10.5, hairBase);

      // Mochila discretamente detrás
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -37, 22, 16), const Radius.circular(4)),
        Paint()..color = const Color(0xFF6B381F),
      );

      // Brazos y Chaqueta
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -36, 6, 17), const Radius.circular(3)), jacketDark);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, -36, 6, 17), const Radius.circular(3)), jacketDark);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -35, 5, 14), const Radius.circular(2)), jacketBase);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, -35, 5, 14), const Radius.circular(2)), jacketBase);

      // Manos
      final skinPaint = Paint()..color = const Color(0xFFE0A675);
      canvas.drawCircle(const Offset(-11, -18), 3, skinPaint);
      canvas.drawCircle(const Offset(11, -18), 3, skinPaint);

      // Torso frontal chaqueta
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -37, 22, 17), const Radius.circular(5)), jacketDark);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -37, 18, 16), const Radius.circular(4)), jacketBase);

      // Tirantes mochila
      final strapPaint = Paint()..color = const Color(0xFF6B3D1F);
      canvas.drawRect(const Rect.fromLTWH(-8, -37, 3, 16), strapPaint);
      canvas.drawRect(const Rect.fromLTWH(5, -37, 3, 16), strapPaint);
      canvas.drawRect(const Rect.fromLTWH(-8.5, -30, 4, 3), Paint()..color = const Color(0xFFB3ADA6));
      canvas.drawRect(const Rect.fromLTWH(4.5, -30, 4, 3), Paint()..color = const Color(0xFFB3ADA6));

      // Cremallera y bolsillos
      canvas.drawLine(const Offset(0, -36), const Offset(0, -22), Paint()..color = const Color(0xFFBFBFB8)..strokeWidth = 1.0);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -27, 5, 4), const Radius.circular(1)), Paint()..color = const Color(0xFF33704D));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(2, -27, 5, 4), const Radius.circular(1)), Paint()..color = const Color(0xFF33704D));

      // Pañuelo rojo
      final scarfPath = Path()
        ..moveTo(-6, -37)
        ..lineTo(6, -37)
        ..lineTo(0, -33)
        ..close();
      canvas.drawPath(scarfPath, Paint()..color = const Color(0xFFCC3833));
      canvas.drawCircle(const Offset(0, -36), 2.5, Paint()..color = const Color(0xFFF2594D));

      // Cuello
      canvas.drawRect(const Rect.fromLTWH(-3, -40, 6, 4), Paint()..color = const Color(0xFFC78A61));

      // 2. Rostro (Cara despejada y piel cálida)
      canvas.drawCircle(const Offset(0, -43), 9.8, Paint()..color = const Color(0xFFEBAE7A));

      // Orejas
      canvas.drawCircle(const Offset(-9.5, -43), 2.8, Paint()..color = const Color(0xFFE09E70));
      canvas.drawCircle(const Offset(9.5, -43), 2.8, Paint()..color = const Color(0xFFE09E70));
      canvas.drawCircle(const Offset(-9.5, -43), 1.3, Paint()..color = const Color(0xFFBF7A59));
      canvas.drawCircle(const Offset(9.5, -43), 1.3, Paint()..color = const Color(0xFFBF7A59));

      // Mejillas sonrosadas
      canvas.drawOval(Rect.fromCenter(center: const Offset(-5.5, -41), width: 5, height: 3), Paint()..color = const Color(0x66F27373));
      canvas.drawOval(Rect.fromCenter(center: const Offset(5.5, -41), width: 5, height: 3), Paint()..color = const Color(0x66F27373));

      // Mirada hacia donde camina
      final lookX = (facingX * 2.2).clamp(-2.4, 2.4);
      final lookY = (facingY * 1.5).clamp(-0.6, 1.6);

      // 3. Ojos grandes expresivos en primer plano
      // Blanco
      canvas.drawOval(Rect.fromCenter(center: Offset(-4 + lookX * 0.4, -43.5 + lookY * 0.3), width: 6.4, height: 7.6), Paint()..color = Colors.white);
      canvas.drawOval(Rect.fromCenter(center: Offset(4 + lookX * 0.4, -43.5 + lookY * 0.3), width: 6.4, height: 7.6), Paint()..color = Colors.white);
      // Iris castaño
      canvas.drawCircle(Offset(-4 + lookX, -43.5 + lookY), 2.2, Paint()..color = const Color(0xFF5C3824));
      canvas.drawCircle(Offset(4 + lookX, -43.5 + lookY), 2.2, Paint()..color = const Color(0xFF5C3824));
      // Pupila
      canvas.drawCircle(Offset(-4 + lookX, -43.5 + lookY), 1.3, Paint()..color = const Color(0xFF140F0F));
      canvas.drawCircle(Offset(4 + lookX, -43.5 + lookY), 1.3, Paint()..color = const Color(0xFF140F0F));
      // Brillo blanco
      canvas.drawCircle(Offset(-4.8 + lookX, -44.2 + lookY * 0.5), 0.8, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(3.2 + lookX, -44.2 + lookY * 0.5), 0.8, Paint()..color = Colors.white);

      // Cejas
      final browPaint = Paint()..color = const Color(0xFF4D2E1F)..strokeWidth = 1.2;
      canvas.drawLine(Offset(-6.5 + lookX * 0.3, -47 + lookY * 0.2), Offset(-2 + lookX * 0.3, -47.5 + lookY * 0.2), browPaint);
      canvas.drawLine(Offset(2 + lookX * 0.3, -47.5 + lookY * 0.2), Offset(6.5 + lookX * 0.3, -47 + lookY * 0.2), browPaint);

      // Nariz y boca orientadas
      canvas.drawCircle(Offset(lookX * 0.4, -41 + lookY * 0.3), 1, Paint()..color = const Color(0xFFB87352));
      canvas.drawArc(
        Rect.fromCenter(center: Offset(lookX * 0.4, -38.5 + lookY * 0.3), width: 4.4, height: 3),
        0.2,
        pi - 0.4,
        false,
        Paint()..color = const Color(0xFF8C3D33)..style = PaintingStyle.stroke..strokeWidth = 1.0,
      );

      // 4. Flequillo y coronilla superior (SOLO ARRIBA DE LA FRENTE, SIN TAPAR LOS OJOS)
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, -46), width: 20.4, height: 20.4),
        pi,
        pi,
        true,
        hairBase,
      );
      canvas.drawCircle(const Offset(0, -50), 7.5, hairBase);

      Path tuft(List<Offset> pts) {
        final p = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (var i = 1; i < pts.length; i++) p.lineTo(pts[i].dx, pts[i].dy);
        return p..close();
      }

      // Mechones peinados hacia los lados arriba de las cejas
      canvas.drawPath(tuft([const Offset(-9, -47), Offset(-4 + lookX * 0.4, -46), const Offset(-1, -49)]), hairBase);
      canvas.drawPath(tuft([const Offset(-3, -49), Offset(2 + lookX * 0.4, -46), const Offset(6, -48)]), hairBase);
      canvas.drawPath(tuft([const Offset(4, -48), Offset(8 + lookX * 0.4, -46), const Offset(10, -47)]), hairBase);
      canvas.drawPath(tuft([const Offset(-10, -47), const Offset(-8, -44), const Offset(-9, -50)]), hairBase);
      canvas.drawPath(tuft([const Offset(10, -47), const Offset(8, -44), const Offset(9, -50)]), hairBase);
      canvas.drawOval(Rect.fromCenter(center: Offset(-2 + lookX * 0.4, -51), width: 11, height: 4.5), Paint()..color = const Color(0xCC8C5938));
    }

    canvas.restore(); // fin de bodyBob
    canvas.restore(); // fin de render
  }
}
