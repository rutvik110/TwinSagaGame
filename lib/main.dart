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
import 'package:flame/widgets.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_fire_atlas/flame_fire_atlas.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

late final FireAtlas fireEffects;
late final FireAtlas iceEffects;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  fireEffects = await FireAtlas.loadAsset('fire_effects.fa');
  iceEffects = await FireAtlas.loadAsset('water_effects.fa');

  runApp(
    GameWidget(
      game: MyGame(),
      overlayBuilderMap: {
        diedOverlayIdentifier: (context, game) {
          return RestartGame(
            game: game! as MyGame,
          );
        },
        startMenu: (context, game) {
          return StartMenu(
            game: game! as MyGame,
          );
        },
        gameWonOverlayIdentifier: (context, game) {
          return GameWon(
            game: game! as MyGame,
          );
        },
        pauseMenuIdentifier: (context, game) {
          return PauseMenu(
            game: game! as MyGame,
          );
        },
        filterOverlay: (context, game) {
          return const FilterOverlay();
        },
      },
    ),
  );
}

class MyGame extends FlameGame with HasCollisionDetection, KeyboardEvents, HasKeyboardHandlerComponents {
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  // TODO: implement debugMode
  bool get debugMode => false;

  PlayerComponent player = PlayerComponent();
  final screenhitbox = ScreenHitbox();

  async.Timer timer = async.Timer(Duration.zero, () {});

  bool startGame = true;

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

  void resetLevel() {
    // remove platforms
    children.removeWhere((element) {
      if (element is GamePlatform || element is Bullet || element is HealthBar || element is PlayerComponent) {
        element.removeFromParent();
        return true;
      }

      return false;
    });
  }

  void loadNewLevel(List<GamePlatform> platforms) {
    resetLevel();
    player = PlayerComponent();
    add(player);
    addAll(platforms);
    add(HealthBar());
  }

  @override
  Future<void> onLoad() async {
    await loadImages();

    final health = await FireAtlas.loadAsset('health.fa');
    final healthDie = await FireAtlas.loadAsset('health_die.fa');

    // Some plain sprites
    fireanimation = fireEffects.getAnimation('fire_2');
    enemyAnimation = fireEffects.getAnimation('enemy');
    fireEnemyDeathAnimation = fireEffects.getAnimation('fire_enemy_death_animation');
    fireBulletAnimation = fireEffects.getAnimation('fire_bullet_animation');
    playerFireAnimation = fireEffects.getAnimation('player_fire_animation');
    playerFireSparklesAnimation = fireEffects.getAnimation('player_fire_sparkles_animation');
    playerFireBulletAnimation = fireEffects.getAnimation('player_fire_bullet_animation');
    fireBulletExplosionAnimation = fireEffects.getAnimation('fire_bullet_explosion_animation');

    icePlatformAnimation = iceEffects.getAnimation('ice_platform_animation');
    iceEnemyAnimation = iceEffects.getAnimation('ice_enemy');
    iceEnemyDeathAnimation = iceEffects.getAnimation('ice_enemy_death_animation');
    iceEnemyBulletAnimation = iceEffects.getAnimation('ice_enemy_bullet_animation');
    playerIceAnimation = iceEffects.getAnimation('player_ice_animation');
    playerIceSparklesAnimation = iceEffects.getAnimation('player_ice_sparkles_animation');
    playerIceBulletAnimation = iceEffects.getAnimation('player_ice_bullet_animation');
    iceBulletExplosionAnimation = iceEffects.getAnimation('ice_bullet_explosion_animation');

    heartRegularAnimation = health.getAnimation('health_normal_animation');
    heartDieAnimation = healthDie.getAnimation('die');

    loadNewLevel(levelOne(this));
    overlays.add(filterOverlay);
    // overlays.add(startMenu);

    return super.onLoad();
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (!startGame) {
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      overlays.add(pauseMenuIdentifier);

      player.runningState = RunningState.waiting;
      player.current = PlayerState.waiting;

      return KeyEventResult.handled;
    }

    if (keysPressed.contains(LogicalKeyboardKey.space) || event.isKeyPressed(LogicalKeyboardKey.space)) {
      FlameAudio.play(
        'player_jump.wav',
        volume: 2,
      );
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
          FlameAudio.play(
            player.isOnHotPlatform ? 'player_fire_bullet.wav' : 'player_ice_bullet.wav',
          );
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
  late final List<SpriteAnimationComponent> hearts;

  @override
  FutureOr<void> onLoad() {
    heartAnimation = SpriteAnimationComponent(
      animation: game.heartRegularAnimation,
    );

    final heartPosition = Vector2(50, 50);

    hearts = List.generate(
      3,
      (i) => SpriteAnimationComponent(
        animation: game.heartRegularAnimation,
        size: Vector2(40, 40),
        position: Vector2(30.0 * (1 + i), heartPosition.y),
      ),
    );

    addAll(hearts);

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
  late final Enemy enemy;
  late final List<SpriteAnimationComponent> torches;
  late final List<PlatformBlock> tiles;

  @override
  void onRemove() {
    if (!isHot) {
      game.removeAll(snowFlakes);
    }
    if (enableEnemy) {
      enemy.removeFromParent();
    }
    game.removeAll(torches);
    game.removeAll(tiles);
    super.onRemove();
  }

  @override
  FutureOr<void> onLoad() {
    paint = Paint()
      ..color = isHot ? Colors.red : Colors.blue
      ..style = PaintingStyle.stroke;

    add(RectangleHitbox());

    if (enableEnemy) {
      enemy = Enemy(
        isOnHotPlatform: isHot,
        platform: this,
      );
      game.add(
        enemy,
      );
    }

    final blocks = (size.x / 25).round();
    tiles = List.generate(
      blocks,
      (index) => PlatformBlock(
        gridPosition: position,
        xOffset: 25.0 * index,
        isHot: isHot,
      ),
    );

    game.addAll(tiles);

    torches = [];

    // lay the platform start/end flame
    final torch1 = SpriteAnimationComponent(
      animation: isHot ? game.fireanimation : game.icePlatformAnimation,
      position: Vector2(position.x, position.y - height),
    );
    final torch2 = SpriteAnimationComponent(
      animation: isHot ? game.fireanimation : game.icePlatformAnimation,
      position: Vector2(position.x + width - 16, position.y - height),
    );

    torches.addAll([
      torch1,
      torch2,
    ]);

    game.addAll([
      torch1,
      torch2,
    ]);

    if (!isHot) {
      snowFlakes = List<SpriteAnimationComponent>.generate(
        10,
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

    final angle = fireAngle;
    this.angle = angle - pi / 2;

    if (!game.startGame) {
      return;
    }

    final radius = dt * 300;

    x += radius * cos(angle);
    y += radius * sin(angle);

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
      final endGame = healthBar.children.length == 1;

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

        FlameAudio.play('player_final_death.wav');

        stopAttacksTimer = async.Timer(const Duration(milliseconds: 3100), () {
          if (endGame) {
            game.overlays.add(diedOverlayIdentifier);
            game.paused = true;
          }
        });

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
        if (!game.startGame) {
          return;
        }

        FlameAudio.play(
          isOnHotPlatform ? 'fire_enemy_bullet.wav' : 'ice_enemy_bullet.wav',
        );

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
      final enemies = game.children.whereType<Enemy>().toList();
      final gameWon = enemies.length == 1;

      if (other.isHot != isOnHotPlatform && other.isPlayerBullet) {
        FlameAudio.play(
          isOnHotPlatform ? 'fire_enemy_death.wav' : 'ice_enemy_death_2.wav',
          volume: isOnHotPlatform ? 2 : 1,
        );
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

        if (gameWon) {
          async.Timer(const Duration(seconds: 1), () {
            game.overlays.add(gameWonOverlayIdentifier);
          });
        }
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

// Inside your game:
const diedOverlayIdentifier = 'PauseMenu';

// Inside your game:
const startMenu = 'StartMenu';

class RestartGame extends StatefulWidget {
  const RestartGame({
    required this.game,
    super.key,
  });

  final MyGame game;

  @override
  State<RestartGame> createState() => _RestartGameState();
}

class _RestartGameState extends State<RestartGame> {
  @override
  void initState() {
    super.initState();
    widget.game.startGame = false;
  }

  @override
  void dispose() {
    widget.game.startGame = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                //grey scale

                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                blendMode: BlendMode.saturation,
                child: Container(
                  color: Colors.grey,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 500,
                decoration: BoxDecoration(
                  color: Colors.brown,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: 5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: FittedBox(
                                child: SpriteWidget(
                                  sprite: iceEffects.getSprite('ice_player_sprite'),
                                  srcSize: Vector2(100, 100),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: FittedBox(
                                child: SpriteWidget(
                                  sprite: fireEffects.getSprite('player_fire_sprite'),
                                  srcSize: Vector2(100, 100),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // add images of final levels and allow users to load them.
                      // unlock

                      const SizedBox(
                        height: 20,
                      ),

                      Wrap(
                        runSpacing: 20,
                        children: [
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(diedOverlayIdentifier);
                              widget.game.loadNewLevel(levelOne(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(diedOverlayIdentifier);
                              widget.game.loadNewLevel(levelTwo(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(diedOverlayIdentifier);
                              widget.game.loadNewLevel(levelThree(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const filterOverlay = 'filterOverlay';

class FilterOverlay extends StatelessWidget {
  const FilterOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        blendMode: BlendMode.saturation,
        child: Container(),
      ),
    );
  }
}

class StartMenu extends StatefulWidget {
  const StartMenu({
    required this.game,
    super.key,
  });

  final MyGame game;

  @override
  State<StartMenu> createState() => _StartMenuState();
}

class _StartMenuState extends State<StartMenu> {
  @override
  void initState() {
    super.initState();
    widget.game.startGame = false;
  }

  @override
  void dispose() {
    widget.game.startGame = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                //grey scale

                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                blendMode: BlendMode.saturation,
                child: Container(
                  color: Colors.grey,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 500,
                decoration: BoxDecoration(
                  color: Colors.brown,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: 5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: FittedBox(
                                child: SpriteWidget(
                                  sprite: iceEffects.getSprite('ice_player_sprite'),
                                  srcSize: Vector2(100, 100),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: FittedBox(
                                child: SpriteWidget(
                                  sprite: fireEffects.getSprite('player_fire_sprite'),
                                  srcSize: Vector2(100, 100),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // add images of final levels and allow users to load them.
                      // unlock

                      const SizedBox(
                        height: 20,
                      ),

                      Wrap(
                        runSpacing: 20,
                        children: [
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(startMenu);
                              widget.game.loadNewLevel(levelOne(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(startMenu);
                              widget.game.loadNewLevel(levelTwo(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(startMenu);
                              widget.game.loadNewLevel(levelThree(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const gameWonOverlayIdentifier = 'gamewonoverlayidentifier';

class GameWon extends StatefulWidget {
  const GameWon({
    required this.game,
    super.key,
  });

  final MyGame game;

  @override
  State<GameWon> createState() => _GameWonState();
}

class _GameWonState extends State<GameWon> {
  @override
  void initState() {
    super.initState();
    widget.game.startGame = false;
  }

  @override
  void dispose() {
    widget.game.startGame = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                //grey scale

                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                blendMode: BlendMode.saturation,
                child: Container(
                  color: Colors.grey,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 500,
                decoration: BoxDecoration(
                  color: Colors.brown,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: 5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: FittedBox(
                                child: SpriteWidget(
                                  sprite: iceEffects.getSprite('ice_player_sprite'),
                                  srcSize: Vector2(100, 100),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: FittedBox(
                                child: SpriteWidget(
                                  sprite: fireEffects.getSprite('player_fire_sprite'),
                                  srcSize: Vector2(100, 100),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // add images of final levels and allow users to load them.
                      // unlock

                      const SizedBox(
                        height: 20,
                      ),

                      Wrap(
                        runSpacing: 20,
                        children: [
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(gameWonOverlayIdentifier);
                              widget.game.loadNewLevel(levelOne(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(gameWonOverlayIdentifier);
                              widget.game.loadNewLevel(levelTwo(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(gameWonOverlayIdentifier);
                              widget.game.loadNewLevel(levelThree(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const pauseMenuIdentifier = 'pauseMenuoverlayidentifier';

class PauseMenu extends StatefulWidget {
  const PauseMenu({
    required this.game,
    super.key,
  });

  final MyGame game;

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<PauseMenu> {
  @override
  void initState() {
    super.initState();
    widget.game.startGame = false;
  }

  @override
  void dispose() {
    widget.game.startGame = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                //grey scale

                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                blendMode: BlendMode.saturation,
                child: Container(
                  color: Colors.grey,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 500,
                decoration: BoxDecoration(
                  color: Colors.brown,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: 5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          widget.game.overlays.remove(pauseMenuIdentifier);
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(
                              'assets/start_icon.png',
                              height: 64,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: FittedBox(
                                child: SpriteWidget(
                                  sprite: iceEffects.getSprite('ice_player_sprite'),
                                  srcSize: Vector2(100, 100),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            widthFactor: 0.5,
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: FittedBox(
                                child: SpriteWidget(
                                  sprite: fireEffects.getSprite('player_fire_sprite'),
                                  srcSize: Vector2(100, 100),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // add images of final levels and allow users to load them.
                      // unlock

                      const SizedBox(
                        height: 20,
                      ),

                      Wrap(
                        runSpacing: 20,
                        children: [
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(pauseMenuIdentifier);
                              widget.game.loadNewLevel(levelOne(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(pauseMenuIdentifier);
                              widget.game.loadNewLevel(levelTwo(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          LevelPreview(
                            image: '',
                            onCall: () {
                              widget.game.overlays.remove(pauseMenuIdentifier);
                              widget.game.loadNewLevel(levelThree(widget.game));
                              widget.game.paused = false;
                            },
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LevelPreview extends StatelessWidget {
  const LevelPreview({
    required this.image,
    required this.onCall,
    super.key,
  });

  final String image;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onCall,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.red,
          border: Border.all(
            width: 5,
          ),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            width: 5,
          ),
        ),
        child: SizedBox(
          width: 200,
          height: 100,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const SizedBox(
                width: 200,
                height: 100,
              ),
              Positioned.fill(
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 15,
                      sigmaY: 15,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/start_icon.png',
                        height: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<GamePlatform> levelOne(MyGame game) {
  final size = game.size;
  return List.from([
    GamePlatform(
      size: Vector2(size.x, defaultPlatformSize.y),
      position: Vector2(0, size.y - 25),
      enableEnemy: false,
    ),
    GamePlatform(
      size: defaultPlatformSize,
      position: Vector2(size.x / 2 - defaultPlatformSize.x, size.y - 350),
      enableEnemy: true,
    ),
    GamePlatform(
      size: defaultPlatformSize,
      position: Vector2(size.x / 2 + (defaultPlatformSize.x) / 2, size.y - 150),
      enableEnemy: true,
      isHot: false,
    ),
  ]);
}

List<GamePlatform> levelTwo(MyGame game) {
  final size = game.size;
  return List.from([
    GamePlatform(
      size: Vector2(size.x, defaultPlatformSize.y),
      position: Vector2(0, size.y - 25),
      enableEnemy: false,
      isHot: false,
    ),
    GamePlatform(
      size: defaultPlatformSize,
      position: Vector2(size.x / 2 - (defaultPlatformSize.x) * 2, size.y - 600),
      enableEnemy: true,
      isHot: false,
    ),
    GamePlatform(
      size: defaultPlatformSize,
      position: Vector2(size.x / 2 - defaultPlatformSize.x / 2, size.y - 400),
      enableEnemy: true,
    ),
    GamePlatform(
      size: defaultPlatformSize,
      position: Vector2(size.x / 2 + (defaultPlatformSize.x), size.y - 200),
      enableEnemy: true,
    ),
  ]);
}

List<GamePlatform> levelThree(MyGame game) {
  final size = game.size;
  return List.from([
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
  ]);
}
