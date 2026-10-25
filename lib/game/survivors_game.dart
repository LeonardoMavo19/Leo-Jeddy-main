import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/enemy.dart';
import 'components/fear_projectile.dart';
import 'components/forest_background.dart';
import 'components/hitbox_component.dart';
import 'components/player.dart';
import 'components/stone_projectile.dart';
import 'components/tree.dart';

class SurvivorsGame extends FlameGame {
  static const hudOverlay = 'hud';
  static const joystickOverlay = 'joystick';
  static const aimingJoystickOverlay = 'aimingJoystick';
  static const gameOverOverlay = 'gameOver';

  final ValueNotifier<int> fear = ValueNotifier<int>(0);
  final ValueNotifier<int> elapsedSeconds = ValueNotifier<int>(0);
  final Vector2 movementInput = Vector2.zero();
  final Vector2 aimInput = Vector2.zero();
  final Random _random = Random();

  late final Vector2 worldSize;
  late final Player player;

  double _spawnTimer = 0;
  double _clockTimer = 0;
  double _stoneCooldown = 0;
  bool _isGameOver = false;
  static const int maxEnemies = 4;
  static const double enemySpawnInterval = 4.0;

  bool get isGameOver => _isGameOver;

  @override
  Color backgroundColor() => const Color(0xFF294B35);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.center;
    worldSize = size * 3;

    world.add(ForestBackground(size: worldSize));
    for (final (xRatio, yRatio, scale) in ForestBackground.trees) {
      world.add(
        Tree(
          footPosition: Vector2(worldSize.x * xRatio, worldSize.y * yRatio),
          scale: scale,
        ),
      );
    }
    player = Player(movementInput: movementInput, position: worldSize / 2);

    world.add(player);
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, worldSize.x, worldSize.y),
      considerViewport: true,
    );
    camera.follow(player, snap: true);
  }

  @override
  void update(double dt) {
    if (_isGameOver) return;
    super.update(dt);

    _clockTimer += dt;
    if (_clockTimer >= 1) {
      final passedSeconds = _clockTimer.floor();
      elapsedSeconds.value += passedSeconds;
      _clockTimer -= passedSeconds;
    }

    _spawnTimer += dt;
    if (_spawnTimer >= enemySpawnInterval) {
      _spawnTimer -= enemySpawnInterval;
      if (world.children.whereType<Enemy>().length < maxEnemies) {
        world.add(_createEnemy());
      }
    }

    if (aimInput.length2 > 0) {
      _stoneCooldown -= dt;
      if (_stoneCooldown <= 0) {
        _throwStone();
        _stoneCooldown = 0.38;
      }
    } else {
      _stoneCooldown = 0;
    }
  }

  List<HitboxComponent> get depthSortedHitboxes {
    final hitboxes = world.children.whereType<HitboxComponent>().toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return hitboxes;
  }

  void receiveSusto() {
    if (_isGameOver) return;

    fear.value = min(100, fear.value + 20);
    if (fear.value == 100) {
      _finishGame();
    }
  }

  void restart() {
    for (final component in world.children.toList()) {
      if (component is Enemy ||
          component is FearProjectile ||
          component is StoneProjectile) {
        component.removeFromParent();
      }
    }
    fear.value = 0;
    elapsedSeconds.value = 0;
    _spawnTimer = 0;
    _clockTimer = 0;
    _stoneCooldown = 0;
    movementInput.setZero();
    aimInput.setZero();
    _isGameOver = false;
    player.position.setFrom(worldSize / 2);
    overlays.remove(gameOverOverlay);
  }

  void setMovementInput(double x, double y) {
    if (_isGameOver) {
      movementInput.setZero();
      return;
    }

    movementInput.setValues(x, y);
    if (movementInput.length2 > 1) {
      movementInput.normalize();
    }
  }

  void setAimInput(double x, double y) {
    if (_isGameOver) {
      aimInput.setZero();
      return;
    }

    aimInput.setValues(x, y);
    if (aimInput.length2 > 1) {
      aimInput.normalize();
    }
  }

  @override
  void dispose() {
    fear.dispose();
    elapsedSeconds.dispose();
    super.dispose();
  }

  void _finishGame() {
    _isGameOver = true;
    movementInput.setZero();
    aimInput.setZero();
    overlays.add(gameOverOverlay);
  }

  void _throwStone() {
    world.add(
      StoneProjectile(
        position: player.position.clone(),
        direction: aimInput.normalized(),
        onHit: (enemy) => enemy.removeFromParent(),
      ),
    );
  }

  void _fireSusto(Enemy enemy) {
    final direction = player.position - enemy.position;
    if (direction.length2 == 0) return;

    world.add(
      FearProjectile(
        position: enemy.position.clone(),
        direction: direction.normalized(),
        target: player,
        onHit: receiveSusto,
      ),
    );
  }

  Enemy _createEnemy() {
    final edge = _random.nextInt(4);
    final x = switch (edge) {
      0 => 0.0,
      1 => worldSize.x,
      _ => _random.nextDouble() * worldSize.x,
    };
    final y = switch (edge) {
      2 => 0.0,
      3 => worldSize.y,
      _ => _random.nextDouble() * worldSize.y,
    };

    return Enemy(target: player, onShoot: _fireSusto, position: Vector2(x, y));
  }
}
