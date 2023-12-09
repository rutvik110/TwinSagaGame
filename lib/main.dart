import 'dart:async';
import 'dart:async' as async;
import 'dart:developer';
import 'dart:math';

import 'package:flame/cache.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
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
    ]);
  }

  @override
  Future<void> onLoad() async {
    await loadImages();

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
              position: player.center - Vector2(12.5, 12.5),
              direction: player.direction,
              isHot: player.isOnHotPlatform,
              fireAngle: player.direction.angleInRadians,
            ),
          );
          timer = async.Timer(const Duration(milliseconds: 300), () {});
        }
      }
    }

    return KeyEventResult.handled;
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

    return super.onLoad();
  }
}

class Bullet extends CircleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  Bullet({
    required this.direction,
    required this.isHot,
    required this.fireAngle,
    Vector2? position,
  }) : super(
          position: position ?? Vector2(0, 0),
        );

  final bool isHot;
  final Direction direction;
  final double fireAngle;

  @override
  Future<void> onLoad() {
    size = Vector2(25, 25);
    paint = Paint()..color = isHot ? Colors.red : Colors.blue;

    add(CircleHitbox());
    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final radius = dt * 500;

    final angle = fireAngle;

    // if (angle != null) {
    x += radius * cos(angle);
    y += radius * sin(angle);
    // } else {
    //   x += radius * (direction == Direction.right ? 1 : -1);
    // }

    if (x < 0 || x > game.size.x || y < 0 || y > game.size.y) {
      removeFromParent();
    }
  }
}

class PlayerComponent extends RectangleComponent with HasGameReference<MyGame>, CollisionCallbacks {
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

  @override
  FutureOr<void> onLoad() {
    size = Vector2(50, 50);

    paint = Paint()..color = const Color(0xFF00FF00);

    groundYPos = game.size.y - height;

    add(RectangleHitbox());

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

      if ((position.y + height) <= (other.y + other.height)) {
        groundYPos = other.y - height;
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

class Enemy extends RectangleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  Enemy({
    required this.isOnHotPlatform,
    required this.platform,
  });

  Direction direction = Direction.right;

  final bool isOnHotPlatform;
  final GamePlatform platform;

  late Timer attackTimer;

  @override
  FutureOr<void> onLoad() {
    size = Vector2(50, 50);

    position = Vector2(
      platform.x + (platform.width - width) / 2,
      platform.y - height * 2,
    );

    paint = Paint()..color = isOnHotPlatform ? Colors.red : Colors.blue;

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
        );

        game.add(bullet);
      },
    );

    attackTimer.start();

    add(RectangleHitbox());

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
}

enum PlayerState { crashed, jumping, running, waiting }

enum RunningState { waiting, runningLeft, runningRight }

final defaultPlatformSize = Vector2(200, 30);

const degree = pi / 180;
