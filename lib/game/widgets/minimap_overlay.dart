import 'package:flutter/material.dart';

import '../components/enemy.dart';
import '../components/tree.dart';
import '../survivors_game.dart';

class MinimapOverlay extends StatefulWidget {
  const MinimapOverlay({required this.game, super.key});

  final SurvivorsGame game;

  @override
  State<MinimapOverlay> createState() => _MinimapOverlayState();
}

class _MinimapOverlayState extends State<MinimapOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.game.isGameOver) return const SizedBox.shrink();

    const minimapWidth = 108.0;
    final worldSize = widget.game.worldSize;
    final aspectRatio = worldSize.x > 0 && worldSize.y > 0
        ? worldSize.x / worldSize.y
        : 1.6;
    final minimapHeight = (minimapWidth / aspectRatio).clamp(58.0, 78.0);

    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 16),
          child: IgnorePointer(
            child: Container(
              width: minimapWidth,
              height: minimapHeight,
              decoration: BoxDecoration(
                color: const Color(0x73081216),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0x5950A0B8),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _MinimapPainter(game: widget.game),
                      size: Size(minimapWidth, minimapHeight),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({required this.game});

  final SurvivorsGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final worldSize = game.worldSize;
    if (worldSize.x <= 0 || worldSize.y <= 0) return;

    final scaleX = size.width / worldSize.x;
    final scaleY = size.height / worldSize.y;

    // Dibujar árboles
    final treePaint = Paint()
      ..color = const Color(0x55386641)
      ..style = PaintingStyle.fill;
    for (final tree in game.world.children.whereType<Tree>()) {
      final tx = tree.position.x * scaleX;
      final ty = tree.position.y * scaleY;
      canvas.drawCircle(Offset(tx, ty), 1.8, treePaint);
    }

    // Dibujar el campo de visión de la cámara (viewport)
    final camPos = game.camera.viewfinder.position;
    final viewW = game.size.x * scaleX;
    final viewH = game.size.y * scaleY;
    final viewLeft = (camPos.x - game.size.x / 2) * scaleX;
    final viewTop = (camPos.y - game.size.y / 2) * scaleY;
    final camRect = Rect.fromLTWH(viewLeft, viewTop, viewW, viewH);
    final camPaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..style = PaintingStyle.fill;
    final camBorderPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRect(camRect, camPaint);
    canvas.drawRect(camRect, camBorderPaint);

    // Dibujar NPCs (enemigos)
    final enemyGlow = Paint()
      ..color = const Color(0x44FF5252)
      ..style = PaintingStyle.fill;
    final enemyPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.fill;
    for (final enemy in game.world.children.whereType<Enemy>()) {
      final ex = enemy.position.x * scaleX;
      final ey = enemy.position.y * scaleY;
      canvas.drawCircle(Offset(ex, ey), 4.0, enemyGlow);
      canvas.drawCircle(Offset(ex, ey), 2.5, enemyPaint);
    }

    // Dibujar personaje (jugador)
    final player = game.player;
    final px = player.position.x * scaleX;
    final py = player.position.y * scaleY;

    final playerGlow = Paint()
      ..color = const Color(0x557BE495)
      ..style = PaintingStyle.fill;
    final playerPaint = Paint()
      ..color = const Color(0xFF7BE495)
      ..style = PaintingStyle.fill;
    final playerCenterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(px, py), 5.0, playerGlow);
    canvas.drawCircle(Offset(px, py), 3.2, playerPaint);
    canvas.drawCircle(Offset(px, py), 1.2, playerCenterPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}

