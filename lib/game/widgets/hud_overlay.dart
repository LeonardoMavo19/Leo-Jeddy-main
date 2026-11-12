import 'package:flutter/material.dart';

import '../components/enemy.dart';
import '../survivors_game.dart';

class HudOverlay extends StatelessWidget {
  const HudOverlay({required this.game, super.key});

  final SurvivorsGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Panel superior central (Tiempo / Barra de Jefe y Miedo)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<Enemy?>(
                      valueListenable: game.currentBoss,
                      builder: (context, boss, _) {
                        if (boss != null) {
                          return _BossHealthBar(boss: boss);
                        }
                        return ValueListenableBuilder<int>(
                          valueListenable: game.elapsedSeconds,
                          builder: (context, seconds, _) => _HudPill(
                            icon: Icons.timer_outlined,
                            label: 'Tiempo ${_formatTime(seconds)}',
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: game.fear,
                      builder: (context, value, _) => _FearMeter(value: value),
                    ),
                  ],
                ),
              ),
            ),

            // Pastilla de progreso de Oleada (esquina superior izquierda debajo del minimapa)
            Positioned(
              left: 16,
              top: 108,
              child: ValueListenableBuilder<int>(
                valueListenable: game.wave,
                builder: (context, waveNumber, _) {
                  final isBoss = (waveNumber % 5 == 0);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC091210),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isBoss
                            ? const Color(0x99FF4A5A)
                            : const Color(0x8048F29E),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isBoss ? 'JEFE $waveNumber' : 'Oleada $waveNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isBoss
                                ? const Color(0xFFFF5C6A)
                                : const Color(0xFF48F29E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        ValueListenableBuilder<int>(
                          valueListenable: game.enemiesRemaining,
                          builder: (context, remaining, _) {
                            return ValueListenableBuilder<int>(
                              valueListenable: game.enemiesTotal,
                              builder: (context, total, _) {
                                return Text(
                                  'Restan: $remaining / $total',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFD0DFD8),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Banner cinematográfico central de inicio de oleada
            ValueListenableBuilder<bool>(
              valueListenable: game.showWaveBanner,
              builder: (context, show, _) {
                if (!show) return const SizedBox.shrink();
                return Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE6081412),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF48F29E),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ValueListenableBuilder<String>(
                      valueListenable: game.waveBannerText,
                      builder: (context, text, _) {
                        return Text(
                          text,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF48F29E),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }
}

class _BossHealthBar extends StatelessWidget {
  const _BossHealthBar({required this.boss});

  final Enemy boss;

  @override
  Widget build(BuildContext context) {
    final hpPct = (boss.hp / boss.maxHp).clamp(0.0, 1.0);
    final bCol = boss.color;

    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF210080D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bCol.withOpacity(0.85), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Retrato del Boss
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bCol, width: 1.2),
              color: Colors.black45,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: boss.bossId.isNotEmpty
                  ? Image.asset(
                      'assets/bosses/${boss.bossId}_face.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.warning_amber_rounded,
                        color: bCol,
                        size: 22,
                      ),
                    )
                  : Icon(Icons.warning_amber_rounded, color: bCol, size: 22),
            ),
          ),
          const SizedBox(width: 10),

          // Nombre, Subtítulo y Barra
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      boss.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: bCol,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${boss.hp}/${boss.maxHp}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: bCol.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                Text(
                  boss.subtitle,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFFD4E2DC),
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hpPct,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(bCol),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FearMeter extends StatelessWidget {
  const _FearMeter({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final fearColor = value >= 75
        ? const Color(0xFFFF6B6B)
        : const Color(0xFFCF70FF);

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xCC101820),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt, size: 18, color: fearColor),
              const SizedBox(width: 7),
              Text('Miedo', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text(
                '$value%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(fearColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC101820),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF7BE495)),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
