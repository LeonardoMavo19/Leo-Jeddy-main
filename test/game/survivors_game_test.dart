import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survivors_arena/game/survivors_game.dart';
import 'package:survivors_arena/game/components/tree.dart';
import 'package:survivors_arena/game/widgets/virtual_joystick_overlay.dart';
import 'package:survivors_arena/game/components/stone_projectile.dart';

void main() {
  testWidgets('hitboxes usan el pie como origen y orden de profundidad', (
    tester,
  ) async {
    final game = SurvivorsGame();
    await tester.pumpWidget(GameWidget<SurvivorsGame>(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    final tree = Tree(footPosition: game.player.position + Vector2(120, 60));
    game.world.add(tree);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.player.hitboxBottom, game.player.position.y);
    expect(tree.hitboxBottom, tree.position.y);
    expect(
      game.depthSortedHitboxes.indexOf(game.player),
      lessThan(game.depthSortedHitboxes.indexOf(tree)),
    );

    game.setMovementInput(0, 1);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(game.player.position.y, greaterThan(tree.position.y));
    expect(game.player.priority, greaterThan(tree.priority));
    expect(
      game.depthSortedHitboxes.indexOf(tree),
      lessThan(game.depthSortedHitboxes.indexOf(game.player)),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('el tronco bloquea, pero se puede pasar bajo la copa', (
    tester,
  ) async {
    final game = SurvivorsGame();
    await tester.pumpWidget(GameWidget<SurvivorsGame>(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    final tree = Tree(footPosition: game.player.position + Vector2(46, 0));
    game.world.add(tree);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    game.setMovementInput(1, 0);
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(game.player.hitboxRight, lessThanOrEqualTo(tree.trunkLeft + 1));

    game.setMovementInput(0, 1);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.player.hitboxBottom, greaterThan(tree.hitboxBottom));

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('la cámara sigue al jugador mientras recorre el bosque', (
    tester,
  ) async {
    final game = SurvivorsGame();
    await tester.pumpWidget(GameWidget<SurvivorsGame>(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    expect(
      game.camera.viewfinder.position.x,
      closeTo(game.player.position.x, 1),
    );

    final initialCameraX = game.camera.viewfinder.position.x;
    game.setMovementInput(1, 0);
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(game.player.position.x, greaterThan(initialCameraX));
    expect(
      game.camera.viewfinder.position.x,
      closeTo(game.player.position.x, 1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('los joysticks envían sus direcciones y se detienen al soltar', (
    tester,
  ) async {
    final game = SurvivorsGame();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            VirtualJoystickOverlay(game: game),
            VirtualJoystickOverlay(game: game, isAiming: true),
          ],
        ),
      ),
    );

    final joystick = find.byKey(const ValueKey('virtual-joystick'));
    final center = tester.getCenter(joystick);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(35, 0));
    await tester.pump();

    expect(game.movementInput.x, greaterThan(0));
    expect(game.movementInput.y, closeTo(0, 0.01));

    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(game.movementInput.y, lessThan(0));

    await gesture.up();
    await tester.pump();

    expect(game.movementInput.x, 0);
    expect(game.movementInput.y, 0);

    final aimingJoystick = find.byKey(const ValueKey('aiming-joystick'));
    final aimingCenter = tester.getCenter(aimingJoystick);
    final aimingGesture = await tester.startGesture(aimingCenter);
    await aimingGesture.moveBy(const Offset(-35, -25));
    await tester.pump();

    expect(game.aimInput.x, lessThan(0));
    expect(game.aimInput.y, lessThan(0));

    await aimingGesture.up();
    await tester.pump();

    expect(game.aimInput.x, 0);
    expect(game.aimInput.y, 0);
    game.dispose();
  });

  testWidgets('mantener el joystick derecho lanza piedras', (tester) async {
    final game = SurvivorsGame();
    await tester.pumpWidget(
      GameWidget<SurvivorsGame>(
        game: game,
        overlayBuilderMap: {
          SurvivorsGame.aimingJoystickOverlay: (context, game) =>
              VirtualJoystickOverlay(game: game, isAiming: true),
        },
        initialActiveOverlays: const [SurvivorsGame.aimingJoystickOverlay],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    final joystick = find.byKey(const ValueKey('aiming-joystick'));
    final gesture = await tester.startGesture(tester.getCenter(joystick));
    await gesture.moveBy(const Offset(0, -45));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(game.world.children.whereType<StoneProjectile>(), isNotEmpty);

    await gesture.up();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  test('cinco sustos llenan la barra y terminan la partida', () {
    final game = SurvivorsGame()
      ..overlays.addEntry(
        SurvivorsGame.gameOverOverlay,
        (_, _) => const SizedBox.shrink(),
      );

    for (var hit = 0; hit < 5; hit++) {
      game.receiveSusto();
    }

    expect(game.fear.value, 100);
    expect(game.isGameOver, isTrue);

    game.receiveSusto();
    expect(game.fear.value, 100);

    game.dispose();
  });
}
