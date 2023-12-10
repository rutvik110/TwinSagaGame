// ignore_for_file: flutter_style_todos

import 'dart:async';
import 'dart:async' as async;
import 'dart:developer';
import 'dart:math';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/rendering.dart';
import 'package:flame/sprite.dart';
import 'package:flame_fire_atlas/flame_fire_atlas.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(GameWidget(game: MyGame()));
}

class MyGame extends FlameGame with HasCollisionDetection, KeyboardEvents, HasKeyboardHandlerComponents {
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  // TODO: implement debugMode
  bool get debugMode => false;

  final player = PlayerComponent();
  final screenhitbox = ScreenHitbox();

  async.Timer timer = async.Timer(Duration.zero, () {});

  Future<void> loadImages() async {
    images = Images(prefix: '');
    await images.loadAll([
      'assets/platform_tiles/FireTiles/Fire_7_16x16.png',
      'assets/platform_tiles/IceTiles/Ice_1_16x16.png',
      'assets/platform_tiles/IceTiles/Ice_23_16x16.png',
    ]);
  }

  late SpriteAnimation fireanimation;
  late SpriteAnimation enemyAnimation;
  late SpriteAnimation fireEnemyDeathAnimation;
  late SpriteAnimation fireBulletAnimation;

  late SpriteAnimation playerFireAnimation;
  late SpriteAnimation playerFireSparklesAnimation;
  late SpriteAnimation playerFireBulletAnimation;

  late SpriteAnimation playerIceAnimation;
  late SpriteAnimation playerIceSparklesAnimation;
  late SpriteAnimation playerIceBulletAnimation;

  late SpriteAnimation icePlatformAnimation;
  late SpriteAnimation iceEnemyAnimation;
  late SpriteAnimation iceEnemyDeathAnimation;
  late SpriteAnimation iceEnemyBulletAnimation;

  late SpriteAnimation fireBulletExplosionAnimation;
  late SpriteAnimation iceBulletExplosionAnimation;

  late SpriteAnimation heartRegularAnimation;
  late SpriteAnimation heartDieAnimation;

  @override
  Future<void> onLoad() async {
    await loadImages();

    final atlas = await FireAtlas.loadAsset('fire_effects.fa');
    final waterEffects = await FireAtlas.loadAsset('water_effects.fa');
    final health = await FireAtlas.loadAsset('health.fa');
    final healthDie = await FireAtlas.loadAsset('health_die.fa');

    // Some plain sprites
    fireanimation = atlas.getAnimation('fire_2');
    enemyAnimation = atlas.getAnimation('enemy');
    fireEnemyDeathAnimation = atlas.getAnimation('fire_enemy_death_animation');
    fireBulletAnimation = atlas.getAnimation('fire_bullet_animation');
    playerFireAnimation = atlas.getAnimation('player_fire_animation');
    playerFireSparklesAnimation = atlas.getAnimation('player_fire_sparkles_animation');
    playerFireBulletAnimation = atlas.getAnimation('player_fire_bullet_animation');
    fireBulletExplosionAnimation = atlas.getAnimation('fire_bullet_explosion_animation');

    icePlatformAnimation = waterEffects.getAnimation('ice_platform_animation');
    iceEnemyAnimation = waterEffects.getAnimation('ice_enemy');
    iceEnemyDeathAnimation = waterEffects.getAnimation('ice_enemy_death_animation');
    iceEnemyBulletAnimation = waterEffects.getAnimation('ice_enemy_bullet_animation');
    playerIceAnimation = waterEffects.getAnimation('player_ice_animation');
    playerIceSparklesAnimation = waterEffects.getAnimation('player_ice_sparkles_animation');
    playerIceBulletAnimation = waterEffects.getAnimation('player_ice_bullet_animation');
    iceBulletExplosionAnimation = waterEffects.getAnimation('ice_bullet_explosion_animation');

    heartRegularAnimation = health.getAnimation('health_normal_animation');
    heartDieAnimation = healthDie.getAnimation('die');

    addAll([
      player,
      GamePlatform(
        size: Vector2(size.x, defaultPlatformSize.y),
        position: Vector2(0, size.y - 25),
        enableEnemy: false,
      ),
      GamePlatform(
        size: defaultPlatformSize,
        position: Vector2(size.x / 2 - defaultPlatformSize.x / 2, size.y - 200),
        isHot: false,
        enableEnemy: true,
      ),
      GamePlatform(
        size: defaultPlatformSize,
        position: Vector2(size.x / 2 - (defaultPlatformSize.x) * 2, size.y - 400),
        enableEnemy: true,
      ),
      GamePlatform(
        size: defaultPlatformSize,
        position: Vector2(size.x / 2 + (defaultPlatformSize.x), size.y - 400),
        enableEnemy: true,
      ),
      GamePlatform(
        size: defaultPlatformSize,
        position: Vector2(size.x / 2 - defaultPlatformSize.x / 2, size.y - 600),
        isHot: false,
        enableEnemy: true,
      ),
      HealthBar(),
    ]);
    return super.onLoad();
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (keysPressed.contains(LogicalKeyboardKey.space) || event.isKeyPressed(LogicalKeyboardKey.space)) {
      print('Jump');
      player.jump();
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (event is RawKeyUpEvent) {
        player.runningState = RunningState.waiting;
      } else {
        player.runningState = RunningState.runningLeft;
        player.direction = Direction.left;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (event is RawKeyUpEvent) {
        player.runningState = RunningState.waiting;
      } else {
        player.runningState = RunningState.runningRight;
        player.direction = Direction.right;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (event is RawKeyDownEvent) {
        player.direction = Direction.top;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (event is RawKeyDownEvent) {
        player.direction = Direction.bottom;
      }
    }

    if (keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        keysPressed.contains(LogicalKeyboardKey.shiftRight) ||
        event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      if (event is RawKeyDownEvent) {
        if (!timer.isActive) {
          add(
            Bullet(
              position: player.center - Vector2(12.5, 12.5) * player.direction.directionVector,
              direction: player.direction,
              isHot: player.isOnHotPlatform,
              fireAngle: player.direction.angleInRadians,
              bulletAnimation: player.isOnHotPlatform ? playerFireBulletAnimation : playerIceBulletAnimation,
              isPlayerBullet: true,
            ),
          );
          timer = async.Timer(const Duration(milliseconds: 300), () {});
        }
      }
    }

    return KeyEventResult.handled;
  }
}

class HealthBar extends Component with HasGameReference<MyGame>, CollisionCallbacks {
  late final SpriteAnimationComponent heartAnimation;
  late final SpriteAnimationComponent heartDieAnimation;
  @override
  FutureOr<void> onLoad() {
    heartAnimation = SpriteAnimationComponent(
      animation: game.heartRegularAnimation,
    );

    final heartPosition = Vector2(50, 50);

    for (var i = 0; i < 3; i++) {
      add(
        SpriteAnimationComponent(
          animation: game.heartRegularAnimation,
          size: Vector2(40, 40),
          position: Vector2(30.0 * (1 + i), heartPosition.y),
        ),
      );
    }

    return super.onLoad();
  }
}

class PlatformBlock extends SpriteComponent with HasGameReference<MyGame> {
  final Vector2 gridPosition;
  double xOffset;

  PlatformBlock({
    required this.gridPosition,
    required this.xOffset,
    required this.isHot,
  }) : super(size: Vector2.all(25), anchor: Anchor.topLeft);

  final bool isHot;

  @override
  void onLoad() {
    final platformImage = game.images.fromCache(
      isHot ? 'assets/platform_tiles/FireTiles/Fire_7_16x16.png' : 'assets/platform_tiles/IceTiles/Ice_1_16x16.png',
    );
    sprite = Sprite(platformImage);
    position = gridPosition;
    position.x += xOffset;

    add(RectangleHitbox(collisionType: CollisionType.passive));
  }
}

class GamePlatform extends RectangleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  GamePlatform({
    required Vector2 position,
    required Vector2 size,
    required this.enableEnemy,
    this.isHot = true,
  }) : super(
          size: size,
          position: position,
        );
  final bool isHot;
  final bool enableEnemy;

  late final List<SpriteAnimationComponent> snowFlakes;

  @override
  FutureOr<void> onLoad() {
    paint = Paint()
      ..color = isHot ? Colors.red : Colors.blue
      ..style = PaintingStyle.stroke;

    add(RectangleHitbox());

    if (enableEnemy) {
      game.add(
        Enemy(
          isOnHotPlatform: isHot,
          platform: this,
        ),
      );
    }

    final blocks = (size.x / 25).round();
    final tiles = List.generate(
      blocks,
      (index) => PlatformBlock(
        gridPosition: position,
        xOffset: 25.0 * index,
        isHot: isHot,
      ),
    );

    game.addAll(tiles);

    // lay the platform start/end flame
    final torch1 = SpriteAnimationComponent(
      animation: isHot ? game.fireanimation : game.icePlatformAnimation,
      position: Vector2(position.x, position.y - height),
    );
    final torch2 = SpriteAnimationComponent(
      animation: isHot ? game.fireanimation : game.icePlatformAnimation,
      position: Vector2(position.x + width - 16, position.y - height),
    );

    game.addAll([
      torch1,
      torch2,
    ]);

    if (!isHot) {
      snowFlakes = List<SpriteAnimationComponent>.generate(
        15,
        (index) => SpriteAnimationComponent(
          animation: game.icePlatformAnimation,
          position: Vector2(
            position.x + Random().nextDouble() * width,
            position.y - Random().nextDouble() * 200,
          ),
        ),
      );

      game.addAll(snowFlakes);
    }

    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (!isHot) {
      for (final snowFlake in snowFlakes) {
        snowFlake.position.y += dt * 10;

        if (snowFlake.y > (position.y - snowFlake.height / 2)) {
          snowFlake.position = Vector2(
            position.x + Random().nextDouble() * width,
            position.y - Random().nextDouble() * 200,
          );
        }
      }
    }

    super.update(dt);
  }
}

class Bullet extends CircleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  Bullet({
    required this.direction,
    required this.isHot,
    required this.fireAngle,
    required this.bulletAnimation,
    required this.isPlayerBullet,
    Vector2? position,
  }) : super(
          position: position ?? Vector2(0, 0),
        );

  final bool isHot;
  final Direction direction;
  final double fireAngle;
  late final SpriteAnimationComponent bullet;
  final SpriteAnimation bulletAnimation;
  final bool isPlayerBullet;

  @override
  Future<void> onLoad() {
    size = Vector2(25, 25);
    paint = Paint()..color = Colors.transparent;

    add(CircleHitbox());

    bullet = SpriteAnimationComponent(
      // TODO: Update for ICE
      animation: bulletAnimation,
      size: size,
    );

    add(
      bullet,
    );

    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final radius = dt * 300;

    final angle = fireAngle;

    // if (angle != null) {
    x += radius * cos(angle);
    y += radius * sin(angle);

    this.angle = angle - pi / 2;

    if (x < 0 || x > game.size.x || y < 0 || y > game.size.y) {
      removeFromParent();
      bullet.removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if ((other is PlayerComponent && !isPlayerBullet) || (other is Enemy && isPlayerBullet)) {
      removeFromParent();
      bullet.removeFromParent();
      game.add(
        SpriteAnimationComponent(
          animation: isHot ? game.fireBulletExplosionAnimation : game.iceBulletExplosionAnimation,
          removeOnFinish: true,
          position: other.center,
          size: size,
        ),
      );
    }

    super.onCollisionStart(intersectionPoints, other);
  }
}

class PlayerComponent extends CircleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  PlayerComponent() : super(priority: 1);

  final double gravity = 1;

  final double initialJumpVelocity = -15.0;
  final double introDuration = 1500.0;
  final double startXPosition = 50;
  final double currentSpeed = 300;

  double jumpVelocity = 0.0;

  PlayerState current = PlayerState.waiting;
  RunningState runningState = RunningState.waiting;

  late double groundYPos;

  Direction direction = Direction.right;

  bool isOnHotPlatform = true;

  late SpriteAnimationComponent playerSprite;
  late SpriteAnimationComponent playerFireSparklesAnimation;

  async.Timer stopAttacksTimer = async.Timer(const Duration(), () {});

  @override
  Future<void> onLoad() {
    size = Vector2(50, 50);

    paint = Paint()..color = Colors.transparent;

    groundYPos = game.size.y - height;

    add(CircleHitbox());

    playerSprite = SpriteAnimationComponent(
      animation: isOnHotPlatform ? game.playerFireAnimation : game.playerIceAnimation,
      size: size,
    );

    playerFireSparklesAnimation = SpriteAnimationComponent(
      animation: isOnHotPlatform ? game.playerFireSparklesAnimation : game.playerIceSparklesAnimation,
      size: size,
      position: Vector2(position.x, position.y - size.y),
    );

    add(playerSprite);
    add(playerFireSparklesAnimation);

    return super.onLoad();
  }

  void jump() {
    if (current == PlayerState.jumping) {
      return;
    }

    current = PlayerState.jumping;
    jumpVelocity = initialJumpVelocity - 8;
  }

  void reset() {
    y = groundYPos;
    jumpVelocity = 0.0;
    current = PlayerState.waiting;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final newplacement = y + jumpVelocity;
    jumpVelocity += gravity;

    if (newplacement < groundYPos) {
      y = newplacement;
    } else {
      reset();
    }

    if (current == PlayerState.jumping) {
      y += jumpVelocity;
      jumpVelocity += gravity;
      if (y > groundYPos) {
        reset();
      }
    }

    if (runningState == RunningState.runningRight) {
      if (x < game.size.x - width) {
        x += dt * currentSpeed;
      }
    }

    if (runningState == RunningState.runningLeft) {
      if (x > 0) {
        x -= dt * currentSpeed;
      }
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is GamePlatform) {
      isOnHotPlatform = other.isHot;

      playerFireSparklesAnimation.animation =
          isOnHotPlatform ? game.playerFireSparklesAnimation : game.playerIceSparklesAnimation;
      playerSprite.animation = isOnHotPlatform ? game.playerFireAnimation : game.playerIceAnimation;

      if ((position.y + height) <= (other.y + other.height)) {
        groundYPos = other.y - height;
      }
    }

    if (other is Bullet && !other.isPlayerBullet) {
      if (stopAttacksTimer.isActive) return;

      final healthBar = game.children.singleWhere((element) => element is HealthBar);

      if (healthBar.children.isNotEmpty) {
        final heart = healthBar.children.last as SpriteAnimationComponent;

        final dieOutAnimation = SpriteAnimationComponent(
          animation: game.heartDieAnimation,
          size: heart.size,
          position: heart.position,
          removeOnFinish: true,
        );

        healthBar.remove(heart);
        healthBar.add(dieOutAnimation);

        stopAttacksTimer = async.Timer(const Duration(milliseconds: 3100), () {});

        playerSprite.add(
          FlashEffect(
            EffectController(
              duration: 3,
              curve: Curves.bounceInOut,
            ),
          ),
        );

        playerFireSparklesAnimation.add(
          FlashEffect(
            EffectController(
              duration: 3,
              curve: Curves.bounceInOut,
            ),
          ),
        );
      }
    }

    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    if (other is GamePlatform) {
      groundYPos = game.size.y - height;
    }

    super.onCollisionEnd(other);
  }
}

class FlashEffect extends ComponentEffect<HasPaint> {
  FlashEffect(super.controller);

  ColorFilter? _original;

  @override
  void apply(double progress) {
    final randomOpacity = Random().nextDouble();
    target.opacity = randomOpacity;
    final currentColor = Colors.white.withOpacity(
      // Currently there is a bug when opacity is 0 in the color filter.
      // "Expected a value of type 'SkDeletable', but got one of type 'Null'"
      // https://github.com/flutter/flutter/issues/89433
      max(randomOpacity * 0.5, 1 / 255),
    );

    target.tint(currentColor);
  }

  @override
  Future<void> onMount() async {
    super.onMount();

    _original = target.getPaint().colorFilter;
  }

  @override
  void onFinish() {
    target.opacity = 1;
    target.getPaint().colorFilter = _original;
    removeFromParent();
    super.onFinish();
  }
}

class Enemy extends CircleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  Enemy({
    required this.isOnHotPlatform,
    required this.platform,
  });

  Direction direction = Direction.right;

  final bool isOnHotPlatform;
  final GamePlatform platform;

  late Timer attackTimer;

  @override
  Future<void> onLoad() {
    size = Vector2(50, 50);

    position = Vector2(
      platform.x + (platform.width - width) / 2,
      platform.y - height * 2,
    );

    paint = Paint()..color = Colors.transparent;

    attackTimer = Timer(
      1.0 + 1.1 * Random().nextDouble(),
      repeat: true,
      onTick: () {
        final playerCenter = game.player.center;
        final bulletdirection = playerCenter - center;

        var angle = atan2(bulletdirection.y, bulletdirection.x);

        if (angle < 0) {
          angle += 2 * pi;
        }

        final bullet = Bullet(
          direction: direction,
          isHot: isOnHotPlatform,
          position: position,
          fireAngle: angle,
          bulletAnimation: isOnHotPlatform ? game.fireBulletAnimation : game.iceEnemyBulletAnimation,
          isPlayerBullet: false,
        );

        game.add(bullet);
      },
    );

    attackTimer.start();

    add(CircleHitbox());

    final enemy = SpriteAnimationComponent(
      // TODO: Update for ICE
      animation: isOnHotPlatform ? game.enemyAnimation : game.iceEnemyAnimation,
      size: size,
    );

    add(enemy);

    return super.onLoad();
  }

  @override
  void update(double dt) {
    attackTimer.update(dt);
    super.update(dt);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Bullet) {
      if (other.isHot != isOnHotPlatform) {
        removeFromParent();

        game.add(
          SpriteAnimationComponent(
            // TODO: Update for ICE
            animation: isOnHotPlatform ? game.fireEnemyDeathAnimation : game.iceEnemyDeathAnimation,
            position: position,
            size: size,
            removeOnFinish: true,
          ),
        );
      }
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}

enum Direction {
  left,
  right,
  top,
  bottom;

  double get angleInRadians {
    switch (this) {
      case Direction.right:
        return 0;
      case Direction.bottom:
        return pi / 2;
      case Direction.left:
        return pi;
      case Direction.top:
        return 3 * pi / 2;
    }
  }

  double get directionVector {
    switch (this) {
      case Direction.right:
        return -1;
      case Direction.bottom:
        return 1;
      case Direction.left:
        return 1;
      case Direction.top:
        return -1;
    }
  }
}

enum PlayerState { crashed, jumping, running, waiting }

enum RunningState { waiting, runningLeft, runningRight }

final defaultPlatformSize = Vector2(200, 30);

const degree = pi / 180;
