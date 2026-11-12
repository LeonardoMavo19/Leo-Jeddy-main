import 'package:flutter/material.dart';

import '../survivors_game.dart';

class UpgradeOverlay extends StatelessWidget {
  const UpgradeOverlay({required this.game, super.key});

  final SurvivorsGame game;

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'OFENSIVA':
        return const Color(0xFFF25042);
      case 'CADENCIA':
        return const Color(0xFF4DC2F0);
      case 'MOVILIDAD':
        return const Color(0xFF55D688);
      case 'POTENCIA':
        return const Color(0xFFFF9429);
      case 'SUPERVIVENCIA':
        return const Color(0xFFD670F0);
      case 'ALCANCE':
        return const Color(0xFF58B6FF);
      case 'TACTICA':
        return const Color(0xFFFFCA3A);
      default:
        return const Color(0xFF55D688);
    }
  }

  IconData _getUpgradeIcon(String id) {
    switch (id) {
      case 'multi_stone':
        return Icons.scatter_plot_rounded;
      case 'rapid_fire':
        return Icons.fast_forward_rounded;
      case 'swift_boots':
        return Icons.directions_run_rounded;
      case 'heavy_rocks':
        return Icons.fitness_center_rounded;
      case 'fear_calm':
        return Icons.spa_rounded;
      case 'stone_speed':
        return Icons.speed_rounded;
      case 'ricochet':
        return Icons.alt_route_rounded;
      case 'vital_relief':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Insignia superior
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x3348F29E),
                  border: Border.all(color: const Color(0xFF48F29E), width: 1.5),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF48F29E),
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),

              // Título
              ValueListenableBuilder<int>(
                valueListenable: game.wave,
                builder: (context, waveNumber, _) {
                  final wasBoss = (waveNumber % 5 == 0);
                  return Text(
                    wasBoss
                        ? '¡JEFE DE PESADILLA DERROTADO!'
                        : '¡OLEADA $waveNumber SUPERADA!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: wasBoss
                          ? const Color(0xFFFF5C6A)
                          : const Color(0xFF48F29E),
                      shadows: const [
                        Shadow(
                          color: Colors.black87,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Elige una bendición para fortalecerte y avanzar a la siguiente oleada:',
                style: TextStyle(
                  color: Color(0xFFD4EAE0),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Las 3 tarjetas de mejoras
              ValueListenableBuilder<List<UpgradeOption>>(
                valueListenable: game.currentUpgradeOptions,
                builder: (context, options, _) {
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final option in options)
                        _buildCard(context, option),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, UpgradeOption option) {
    final catColor = _getCategoryColor(option.category);
    final iconData = _getUpgradeIcon(option.id);

    return Container(
      width: 215,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xF2091412),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: catColor.withOpacity(0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge de categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: catColor.withOpacity(0.7)),
            ),
            child: Text(
              option.category,
              style: TextStyle(
                color: catColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Emblema circular con icono
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: catColor.withOpacity(0.15),
              border: Border.all(color: catColor.withOpacity(0.55), width: 1.2),
            ),
            child: Icon(iconData, color: catColor, size: 28),
          ),
          const SizedBox(height: 14),

          // Nombre de habilidad
          Text(
            option.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF5F9F6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Divisor suave
          Container(
            height: 1,
            width: 140,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 10),

          // Descripción
          SizedBox(
            height: 48,
            child: Center(
              child: Text(
                option.desc,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFD4E2DC),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Botón Elegir
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: () => game.selectUpgrade(option),
              style: ElevatedButton.styleFrom(
                backgroundColor: catColor.withOpacity(0.25),
                foregroundColor: Colors.white,
                side: BorderSide(color: catColor.withOpacity(0.85)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'ELEGIR',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

