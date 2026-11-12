import 'dart:math';

import 'package:flutter/material.dart';

import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final List<_MenuFirefly> _fireflies = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    final rng = Random(42);
    for (var i = 0; i < 28; i++) {
      _fireflies.add(
        _MenuFirefly(
          baseX: rng.nextDouble(),
          baseY: rng.nextDouble(),
          speed: 0.8 + rng.nextDouble() * 1.5,
          seed: rng.nextDouble() * 40,
          size: 1.2 + rng.nextDouble() * 1.4,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF060B0E),
      body: Stack(
        children: [
          // 1. Fondo degradado noche profunda
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF040810),
                    Color(0xFF071217),
                    Color(0xFF0A1C16),
                  ],
                  stops: [0.0, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // 2. Luna, cielo nocturno, silueta del niño contemplativo y luciérnagas
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _MenuNightPainter(
                    progress: _animController.value,
                    fireflies: _fireflies,
                  ),
                );
              },
            ),
          ),

          // 3. Contenido Principal del Menú
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Emblema superior
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x33102D1E),
                        border: Border.all(
                          color: const Color(0x6644B36E),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4044B36E),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_moon_rounded,
                        size: 50,
                        color: Color(0xFF7BE495),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Título Principal
                    const Text(
                      'SURVIVORS ARENA',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                        color: Color(0xFF7BE495),
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 3),
                            blurRadius: 8,
                          ),
                          Shadow(
                            color: Color(0x8044B36E),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Cápsula de subtítulo temático
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x66081412),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0x4044B36E),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'NOCHE EN EL BOSQUE MALDITO',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Color(0xFFD4EBE0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Botón Principal de Iniciar Partida
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final pulse = sin(_animController.value * 2 * pi * 2) * 0.02;
                        return Transform.scale(
                          scale: 1.0 + pulse,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 250,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2E7D4E),
                              Color(0xFF44B36E),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x662E7D4E),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const GameScreen(),
                                ),
                              );
                            },
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    size: 26,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'JUGAR AHORA',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Tarjeta de Guía de Supervivencia / Controles (Amplia y bien dispersada)
                    Container(
                      width: min(520, screenWidth - 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xB2091512),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0x4044B36E),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'GUÍA RÁPIDA DE SUPERVIVENCIA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Color(0xFF7BE495),
                              ),
                            ),
                          ),
                          const Divider(
                            color: Color(0x22FFFFFF),
                            height: 18,
                          ),
                          _buildControlRow(
                            badge: '[ W, A, S, D  /  Joy Izq ]',
                            text: 'Mover al personaje por el bosque',
                          ),
                          const SizedBox(height: 8),
                          _buildControlRow(
                            badge: '[ Clic y apuntar  /  Joy Der ]',
                            text: 'Lanzar piedras a los monstruos',
                          ),
                          const SizedBox(height: 8),
                          _buildControlRow(
                            badge: '[ Alerta de Pesadilla ]',
                            text: '¡No permitas que el miedo suba al 100%!',
                            isAlert: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow({
    required String badge,
    required String text,
    bool isAlert = false,
  }) {
    return Row(
      children: [
        Text(
          badge,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isAlert ? const Color(0xFFFF6B6B) : const Color(0xFF7BE495),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: isAlert ? const Color(0xFFFFB3B3) : Colors.white70,
              fontWeight: isAlert ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuFirefly {
  final double baseX;
  final double baseY;
  final double speed;
  final double seed;
  final double size;

  const _MenuFirefly({
    required this.baseX,
    required this.baseY,
    required this.speed,
    required this.seed,
    required this.size,
  });
}

class _MenuNightPainter extends CustomPainter {
  final double progress;
  final List<_MenuFirefly> fireflies;

  _MenuNightPainter({required this.progress, required this.fireflies});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi * 8;

    // Luna en la esquina superior derecha
    final moonCenter = Offset(size.width - 65, 70);
    // Halos lunares
    canvas.drawCircle(
      moonCenter,
      48,
      Paint()..color = const Color(0x10BEE3FF),
    );
    canvas.drawCircle(
      moonCenter,
      32,
      Paint()..color = const Color(0x1ADBEEFF),
    );
    canvas.drawCircle(
      moonCenter,
      22,
      Paint()..color = const Color(0xFAF0F6FF),
    );
    // Cráteres lunares sutiles
    canvas.drawCircle(
      Offset(moonCenter.dx - 5, moonCenter.dy - 4),
      3.5,
      Paint()..color = const Color(0x40B0C4DE),
    );
    canvas.drawCircle(
      Offset(moonCenter.dx + 6, moonCenter.dy + 3),
      2.5,
      Paint()..color = const Color(0x40B0C4DE),
    );

    // Suelo y colina izquierda donde se sienta el niño
    final groundY = size.height * 0.76;
    final groundPaint = Paint()..color = const Color(0xFF09140F);
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      groundPaint,
    );
    // Colina suave
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.16, groundY + 15),
        width: 140,
        height: 45,
      ),
      Paint()..color = const Color(0xFF0D1E16),
    );

    // Silueta del niño sentado en la hierba mirando la luna
    final bx = size.width * 0.16;
    final by = groundY + 12;

    // Sombra del niño
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bx, by), width: 34, height: 10),
      Paint()..color = const Color(0x66040806),
    );

    // Mochila apoyada a la izquierda
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx - 22, by - 16, 12, 14),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF5A3018),
    );

    // Piernas sentadas hacia la derecha (hacia la luna)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx - 6, by - 10, 16, 7),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF283E5C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + 6, by - 8, 12, 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF283E5C),
    );
    // Botas
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + 14, by - 8, 9, 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF50321E),
    );

    // Torso inclinado descansando
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx - 10, by - 26, 15, 17),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF2D6942),
    );
    // Pañuelo rojo
    canvas.drawCircle(Offset(bx, by - 24), 2.5, Paint()..color = const Color(0xFFD63C3C));

    // Cabeza inclinada mirando arriba hacia la luna
    canvas.drawCircle(Offset(bx + 1, by - 36), 8.5, Paint()..color = const Color(0xFFE29E6B));
    canvas.drawCircle(Offset(bx - 2, by - 37), 9.0, Paint()..color = const Color(0xFF4C2A18));
    // Ojo mirando hacia la luna
    canvas.drawCircle(Offset(bx + 4.5, by - 37.5), 1.8, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(bx + 5.2, by - 38), 1.0, Paint()..color = const Color(0xFF2B160C));
    canvas.drawCircle(Offset(bx + 5.5, by - 38.3), 0.5, Paint()..color = Colors.white);

    // Luciérnagas flotantes
    for (final ff in fireflies) {
      final fx = (ff.baseX * size.width + sin(t * ff.speed * 0.15 + ff.seed) * 20) % size.width;
      final fy = (ff.baseY * size.height + cos(t * ff.speed * 0.12 + ff.seed) * 16) % size.height;
      final glow = 0.5 + 0.5 * sin(t * 0.4 + ff.seed);

      final haloPaint = Paint()
        ..color = Color.fromRGBO(204, 242, 89, 0.22 * glow);
      canvas.drawCircle(Offset(fx, fy), 5 * glow + 2, haloPaint);

      final corePaint = Paint()
        ..color = Color.fromRGBO(255, 255, 180, 0.85 * glow);
      canvas.drawCircle(Offset(fx, fy), ff.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MenuNightPainter oldDelegate) => true;
}
