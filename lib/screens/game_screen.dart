import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/survivors_game.dart';
import '../game/widgets/game_over_overlay.dart';
import '../game/widgets/hud_overlay.dart';
import '../game/widgets/minimap_overlay.dart';
import '../game/widgets/virtual_joystick_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final SurvivorsGame _game;

  @override
  void initState() {
    super.initState();
    _game = SurvivorsGame();
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<SurvivorsGame>(
        game: _game,
        overlayBuilderMap: {
          SurvivorsGame.vignetteOverlay: (context, game) => const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.15,
                      colors: [
                        Colors.transparent,
                        Color(0x33040810),
                        Color(0x8C020408),
                      ],
                      stops: [0.55, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
          SurvivorsGame.hudOverlay: (context, game) => HudOverlay(game: game),
          SurvivorsGame.minimapOverlay: (context, game) =>
              MinimapOverlay(game: game),
          SurvivorsGame.joystickOverlay: (context, game) =>
              VirtualJoystickOverlay(game: game),
          SurvivorsGame.aimingJoystickOverlay: (context, game) =>
              VirtualJoystickOverlay(game: game, isAiming: true),
          SurvivorsGame.gameOverOverlay: (context, game) =>
              GameOverOverlay(game: game),
        },
        initialActiveOverlays: const [
          SurvivorsGame.vignetteOverlay,
          SurvivorsGame.hudOverlay,
          SurvivorsGame.minimapOverlay,
          SurvivorsGame.joystickOverlay,
          SurvivorsGame.aimingJoystickOverlay,
        ],
      ),
    );
  }
}
