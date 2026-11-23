import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/enemy.dart';
import 'components/fear_projectile.dart';
import 'components/forest_background.dart';
import 'components/hitbox_component.dart';
import 'components/night_lighting.dart';
import 'components/player.dart';
import 'components/stone_projectile.dart';
import 'components/tree.dart';

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/enemy.dart';
import 'components/fear_projectile.dart';
import 'components/forest_background.dart';
import 'components/hitbox_component.dart';
import 'components/night_lighting.dart';
import 'components/player.dart';
import 'components/stone_projectile.dart';
import 'components/tree.dart';

class VenezuelanBossData {
  final String id;
  final String name;
  final String subtitle;
  final String lore;
  final int baseHp;
  final double speed;
  final double scale;
  final String shotType;
  final String assetKey;
  final Color color;

  const VenezuelanBossData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.lore,
    required this.baseHp,
    required this.speed,
    required this.scale,
    required this.shotType,
    required this.assetKey,
    required this.color,
  });
}

const List<VenezuelanBossData> venezuelanBosses = [
  VenezuelanBossData(
    id: 'el_silbon',
    name: 'EL SILBÓN',
    subtitle: 'El silbador errante de los llanos',
    lore: 'Si se escucha lejos... ¡ya está a tu lado!',
    baseHp: 22,
    speed: 52,
    scale: 1.6,
    shotType: 'silbon',
    assetKey: 'el_silbon',
    color: Color(0xFFF5D166),
  ),
  VenezuelanBossData(
    id: 'la_llorona',
    name: 'LA LLORONA',
    subtitle: 'El espectro del río y los sauces',
    lore: '¡Aaaaay mis hijos! Su llanto hiela el bosque',
    baseHp: 34,
    speed: 46,
    scale: 1.6,
    shotType: 'llorona',
    assetKey: 'la_llorona',
    color: Color(0xFF73D9FF),
  ),
  VenezuelanBossData(
    id: 'el_cabron',
    name: 'EL CAMBIAFORMAS',
    subtitle: 'La bestia salvaje de los montes',
    lore: 'Corre en feroz embestida y ataca con brutales garras',
    baseHp: 52,
    speed: 64,
    scale: 1.85,
    shotType: 'melee',
    assetKey: 'el_cabron',
    color: Color(0xFFFF594D),
  ),
  VenezuelanBossData(
    id: 'duendes',
    name: 'LOS DUENDES',
    subtitle: 'Espíritus traviesos de los hongos',
    lore: 'Embaucan a los caminantes y lanzan oro maldito',
    baseHp: 60,
    speed: 64,
    scale: 1.45,
    shotType: 'duendes',
    assetKey: 'duendes',
    color: Color(0xFF7BF273),
  ),
  VenezuelanBossData(
    id: 'las_animas',
    name: 'LAS ÁNIMAS',
    subtitle: 'Procesión de almas con cirios encendidos',
    lore: 'Almas en pena con velas. ¡No las mires de frente!',
    baseHp: 76,
    speed: 42,
    scale: 1.65,
    shotType: 'animas',
    assetKey: 'las_animas',
    color: Color(0xFFE0EFF7),
  ),
  VenezuelanBossData(
    id: 'brujas',
    name: 'LAS BRUJAS',
    subtitle: 'Hechiceras de la noche sobre la luna',
    lore: 'Surcan el firmamento nocturno en escobas mágicas',
    baseHp: 92,
    speed: 60,
    scale: 1.6,
    shotType: 'brujas',
    assetKey: 'brujas',
    color: Color(0xFFE07BFA),
  ),
];

class UpgradeOption {
  final String id;
  final String name;
  final String category;
  final String desc;
  final void Function(Player player, SurvivorsGame game) apply;

  const UpgradeOption({
    required this.id,
    required this.name,
    required this.category,
    required this.desc,
    required this.apply,
  });
}

class SurvivorsGame extends FlameGame {
  static const hudOverlay = 'hud';
  static const vignetteOverlay = 'vignette';
  static const minimapOverlay = 'minimap';
  static const joystickOverlay = 'joystick';
  static const aimingJoystickOverlay = 'aimingJoystick';
  static const gameOverOverlay = 'gameOver';
  static const upgradeOverlay = 'upgrade';

  static const double worldScale = 1.7;

  final ValueNotifier<int> fear = ValueNotifier<int>(0);
  final ValueNotifier<int> elapsedSeconds = ValueNotifier<int>(0);
  final ValueNotifier<int> wave = ValueNotifier<int>(1);
  final ValueNotifier<int> enemiesRemaining = ValueNotifier<int>(6);
  final ValueNotifier<int> enemiesTotal = ValueNotifier<int>(6);
  final ValueNotifier<Enemy?> currentBoss = ValueNotifier<Enemy?>(null);
  final ValueNotifier<List<UpgradeOption>> currentUpgradeOptions =
      ValueNotifier<List<UpgradeOption>>([]);
  final ValueNotifier<String> waveBannerText = ValueNotifier<String>('');
  final ValueNotifier<bool> showWaveBanner = ValueNotifier<bool>(false);

  final Vector2 movementInput = Vector2.zero();
  final Vector2 aimInput = Vector2.zero();
  final Random _random = Random();

  late final Vector2 worldSize;
  late final Player player;

  double _spawnTimer = 0;
  double _clockTimer = 0;
  double _stoneCooldown = 0;
  double _bannerTimer = 0;
  bool _isGameOver = false;
  bool _isUpgradeState = false;

  int _enemiesSpawned = 0;
  int _enemiesDefeated = 0;
  int _maxEnemies = 4;
  double _spawnInterval = 3.0;

  bool get isGameOver => _isGameOver;
  bool get isUpgradeState => _isUpgradeState;

  static final List<UpgradeOption> upgradeCatalog = [
    UpgradeOption(
      id: 'multi_stone',
      name: 'Lluvia de Piedras',
      category: 'OFENSIVA',
      desc: 'Lanzas +1 piedra adicional por disparo en abanico.',
      apply: (p, g) => p.projectileCount++,
    ),
    UpgradeOption(
      id: 'rapid_fire',
      name: 'Brazos Veloces',
      category: 'CADENCIA',
      desc: 'Disparas piedras un 28% más rápido.',
      apply: (p, g) => p.fireCooldown = max(0.12, p.fireCooldown * 0.72),
    ),
    UpgradeOption(
      id: 'swift_boots',
      name: 'Zapatos Ligeros',
      category: 'MOVILIDAD',
      desc: 'Velocidad de movimiento del niño +22%.',
      apply: (p, g) => p.speedMultiplier *= 1.22,
    ),
    UpgradeOption(
      id: 'heavy_rocks',
      name: 'Roca Volcánica',
      category: 'POTENCIA',
      desc: 'Piedras más grandes que perforan +1 enemigo.',
      apply: (p, g) {
        p.stoneRadius += 2.5;
        p.stonePierce += 1;
      },
    ),
    UpgradeOption(
      id: 'fear_calm',
      name: 'Mente Serena',
      category: 'SUPERVIVENCIA',
      desc: 'Disminuye el Miedo acumulado un 40%.',
      apply: (p, g) {
        g.fear.value = max(0, g.fear.value - 40);
        p.fearResistance *= 0.8;
      },
    ),
    UpgradeOption(
      id: 'stone_speed',
      name: 'Honda Reforzada',
      category: 'ALCANCE',
      desc: 'Velocidad de proyectil +35% y mayor alcance.',
      apply: (p, g) => p.stoneSpeed *= 1.35,
    ),
    UpgradeOption(
      id: 'ricochet',
      name: 'Piedra Rebotadora',
      category: 'TACTICA',
      desc: 'Tus piedras rebotan hacia otro monstruo cercano.',
      apply: (p, g) => p.stoneBounce += 1,
    ),
    UpgradeOption(
      id: 'vital_relief',
      name: 'Coraje Heroico',
      category: 'SUPERVIVENCIA',
      desc: 'Limpia TODO el miedo a 0% de inmediato.',
      apply: (p, g) => g.fear.value = 0,
    ),
  ];

  @override
  Color backgroundColor() => const Color(0xFF070E0C);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.center;
    worldSize = size * worldScale;

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
    world.add(NightLighting(worldSize: worldSize));
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, worldSize.x, worldSize.y),
      considerViewport: true,
    );
    camera.follow(player, snap: true);

    startWave(1);
  }

  void startWave(int waveNumber) {
    wave.value = waveNumber;
    _enemiesDefeated = 0;
    _enemiesSpawned = 0;
    currentBoss.value = null;

    final isBossWave = (waveNumber % 5 == 0);
    if (isBossWave) {
      final bossTier = waveNumber ~/ 5;
      final bossIndex = (bossTier - 1) % venezuelanBosses.length;
      final bossData = venezuelanBosses[bossIndex];
      enemiesTotal.value = 1 + min(6, 2 + bossTier);
      _spawnInterval = 2.0;
      _maxEnemies = 5;
      waveBannerText.value = '¡${bossData.name}!\n${bossData.subtitle}';
    } else {
      enemiesTotal.value = 4 + (waveNumber * 2);
      _spawnInterval = max(1.2, 3.2 - waveNumber * 0.14);
      _maxEnemies = min(8, 3 + (waveNumber * 0.7).floor());
      waveBannerText.value = 'OLEADA $waveNumber';
    }

    enemiesRemaining.value = enemiesTotal.value;
    showWaveBanner.value = true;
    _bannerTimer = 3.0;
    _spawnTimer = 0.5;
  }

  void _triggerWaveUpgrade() {
    _isUpgradeState = true;
    movementInput.setZero();
    aimInput.setZero();

    // Elegir 3 mejoras aleatorias distintas
    final pool = List<UpgradeOption>.from(upgradeCatalog)..shuffle(_random);
    currentUpgradeOptions.value = pool.take(3).toList();
    overlays.add(upgradeOverlay);
  }

  void selectUpgrade(UpgradeOption option) {
    option.apply(player, this);
    overlays.remove(upgradeOverlay);
    _isUpgradeState = false;
    startWave(wave.value + 1);
  }

  @override
  void update(double dt) {
    if (_isGameOver || _isUpgradeState) return;
    super.update(dt);

    if (_bannerTimer > 0) {
      _bannerTimer -= dt;
      if (_bannerTimer <= 0) {
        showWaveBanner.value = false;
      }
    }

    _clockTimer += dt;
    if (_clockTimer >= 1) {
      final passedSeconds = _clockTimer.floor();
      elapsedSeconds.value += passedSeconds;
      _clockTimer -= passedSeconds;
    }

    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval && _enemiesSpawned < enemiesTotal.value) {
      _spawnTimer -= _spawnInterval;
      if (world.children.whereType<Enemy>().length < _maxEnemies) {
        world.add(_createEnemy());
      }
    }

    _stoneCooldown = max(0.0, _stoneCooldown - dt);
    if (aimInput.length2 > 0 && _stoneCooldown <= 0) {
      _throwStone();
      _stoneCooldown = player.fireCooldown;
    }
  }

  List<HitboxComponent> get depthSortedHitboxes {
    final hitboxes = world.children.whereType<HitboxComponent>().toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return hitboxes;
  }

  void receiveSusto() {
    if (_isGameOver) return;

    final damage = max(1, (20 * player.fearResistance).floor());
    fear.value = min(100, fear.value + damage);
    if (fear.value >= 100) {
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
    _isUpgradeState = false;
    player.resetUpgrades();
    player.position.setFrom(worldSize / 2);
    overlays.remove(gameOverOverlay);
    overlays.remove(upgradeOverlay);
    startWave(1);
  }

  void setMovementInput(double x, double y) {
    if (_isGameOver || _isUpgradeState) {
      movementInput.setZero();
      return;
    }

    movementInput.setValues(x, y);
    if (movementInput.length2 > 1) {
      movementInput.normalize();
    }
  }

  void setAimInput(double x, double y) {
    if (_isGameOver || _isUpgradeState) {
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
    wave.dispose();
    enemiesRemaining.dispose();
    enemiesTotal.dispose();
    currentBoss.dispose();
    currentUpgradeOptions.dispose();
    waveBannerText.dispose();
    showWaveBanner.dispose();
    super.dispose();
  }

  void _finishGame() {
    _isGameOver = true;
    movementInput.setZero();
    aimInput.setZero();
    overlays.add(gameOverOverlay);
  }

  void _throwStone() {
    final count = player.projectileCount;
    final speed = player.stoneSpeed;
    final baseAngle = atan2(aimInput.y, aimInput.x);
    const spread = 0.22;
    final startAngle = baseAngle - (count - 1) * spread / 2;

    for (int i = 0; i < count; i++) {
      final angle = count == 1 ? baseAngle : startAngle + i * spread;
      final dir = Vector2(cos(angle), sin(angle));
      world.add(
        StoneProjectile(
          position: player.position.clone(),
          direction: dir,
          radius: player.stoneRadius,
          projectileSpeed: speed,
          pierce: player.stonePierce,
          bounce: player.stoneBounce,
          onHit: _onEnemyHit,
        ),
      );
    }
  }

  void _onEnemyHit(Enemy enemy) {
    final isDead = enemy.takeDamage(1);
    if (isDead) {
      if (enemy.isBoss) {
        fear.value = max(0, fear.value - 35);
        currentBoss.value = null;
      }
      enemy.removeFromParent();
      _enemiesDefeated++;
      enemiesRemaining.value = max(0, enemiesTotal.value - _enemiesDefeated);

      if (_enemiesDefeated >= enemiesTotal.value &&
          world.children.whereType<Enemy>().isEmpty) {
        _triggerWaveUpgrade();
      }
    }
  }

  void _fireSusto(Enemy enemy) {
    final diff = player.position - enemy.position;
    if (diff.length2 == 0) return;

    final baseAngle = atan2(diff.y, diff.x);
    final count = enemy.isBoss ? 3 : 1;
    const spread = 0.28;
    final startAngle = baseAngle - (count - 1) * spread / 2;

    for (int i = 0; i < count; i++) {
      final angle = count == 1 ? baseAngle : startAngle + i * spread;
      final dir = Vector2(cos(angle), sin(angle));
      world.add(
        FearProjectile(
          position: enemy.position.clone(),
          direction: dir,
          target: player,
          onHit: receiveSusto,
        ),
      );
    }
  }

  Enemy _createEnemy() {
    final isBossWave = (wave.value % 5 == 0);
    if (isBossWave && _enemiesSpawned == 0) {
      _enemiesSpawned++;
      final bossTier = wave.value ~/ 5;
      final bossIndex = (bossTier - 1) % venezuelanBosses.length;
      final loop = (bossTier - 1) ~/ venezuelanBosses.length;
      final data = venezuelanBosses[bossIndex];
      final bHp = data.baseHp + loop * 30;

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

      final boss = Enemy(
        target: player,
        onShoot: _fireSusto,
        position: Vector2(x, y),
        isBoss: true,
        bossId: data.id,
        name: data.name,
        subtitle: data.subtitle,
        lore: data.lore,
        color: data.color,
        shotType: data.shotType,
        hp: bHp,
        maxHp: bHp,
      );
      currentBoss.value = boss;
      return boss;
    }

    _enemiesSpawned++;
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
