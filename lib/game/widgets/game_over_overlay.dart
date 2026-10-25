import 'package:flutter/material.dart';

import '../survivors_game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, super.key});

  final SurvivorsGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fin de la partida',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('El miedo te venció.'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: game.restart,
                  icon: const Icon(Icons.replay),
                  label: const Text('Volver a jugar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
