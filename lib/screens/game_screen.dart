import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/survivors_game.dart';
import '../game/widgets/game_over_overlay.dart';
import '../game/widgets/hud_overlay.dart';
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
          SurvivorsGame.hudOverlay: (context, game) => HudOverlay(game: game),
          SurvivorsGame.joystickOverlay: (context, game) =>
              VirtualJoystickOverlay(game: game),
          SurvivorsGame.aimingJoystickOverlay: (context, game) =>
              VirtualJoystickOverlay(game: game, isAiming: true),
          SurvivorsGame.gameOverOverlay: (context, game) =>
              GameOverOverlay(game: game),
        },
        initialActiveOverlays: const [
          SurvivorsGame.hudOverlay,
          SurvivorsGame.joystickOverlay,
          SurvivorsGame.aimingJoystickOverlay,
        ],
      ),
    );
  }
}
